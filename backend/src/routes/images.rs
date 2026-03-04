use axum::{
    Json, Router,
    extract::{Multipart, Path, State},
    http::StatusCode,
    routing::{get, post},
};
use sqlx::Row;
use uuid::Uuid;

use crate::{
    AppState,
    auth::middleware::AuthUser,
    dto::ImageResponse,
    error::{AppError, AppResult},
    middleware::rate_limit::check_user_limit,
};

const MAX_BYTES: usize = 5 * 1024 * 1024; // 5 MB
const ALLOWED_MIME: &[&str] = &["image/jpeg", "image/png", "image/webp"];

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/upload", post(upload_image))
        .route("/dish/:dish_id", get(list_dish_images))
        .route("/:id/url", get(get_presigned_url))
}

pub fn admin_router() -> Router<AppState> {
    Router::new()
        .route("/images/:id/remove", post(admin_remove_image))
}

// ─────────────────────────────────────────────
// POST /images/upload
// ─────────────────────────────────────────────

async fn upload_image(
    State(state): State<AppState>,
    user: AuthUser,
    mut multipart: Multipart,
) -> AppResult<(StatusCode, Json<ImageResponse>)> {
    check_user_limit(&state.rl_uploads, user.id)?;

    let mut file_bytes: Option<Vec<u8>> = None;
    let mut mime_type: Option<String> = None;
    let mut entity_type: Option<String> = None;
    let mut entity_id: Option<Uuid> = None;
    let mut is_public = false;

    while let Some(field) = multipart.next_field().await.map_err(|e| {
        AppError::BadRequest(format!("Multipart error: {e}"))
    })? {
        let name = field.name().unwrap_or("").to_string();
        match name.as_str() {
            "file" => {
                let ct = field
                    .content_type()
                    .unwrap_or("application/octet-stream")
                    .to_string();
                if !ALLOWED_MIME.contains(&ct.as_str()) {
                    return Err(AppError::BadRequest(
                        "Only JPEG, PNG, and WebP images are accepted.".to_string(),
                    ));
                }
                let bytes = field.bytes().await.map_err(|e| {
                    AppError::Internal(anyhow::anyhow!("Failed to read file bytes: {e}"))
                })?;
                if bytes.len() > MAX_BYTES {
                    return Err(AppError::BadRequest(
                        "Image must be 5 MB or smaller.".to_string(),
                    ));
                }
                mime_type = Some(ct);
                file_bytes = Some(bytes.to_vec());
            }
            "entity_type" => {
                let v = field.text().await.unwrap_or_default();
                if v != "dish" && v != "restaurant" {
                    return Err(AppError::BadRequest(
                        "entity_type must be 'dish' or 'restaurant'".to_string(),
                    ));
                }
                entity_type = Some(v);
            }
            "entity_id" => {
                let v = field.text().await.unwrap_or_default();
                entity_id = Some(v.parse::<Uuid>().map_err(|_| {
                    AppError::BadRequest("Invalid entity_id UUID".to_string())
                })?);
            }
            "is_public" => {
                let v = field.text().await.unwrap_or_default();
                is_public = v == "true";
            }
            _ => {}
        }
    }

    let file_bytes = file_bytes
        .ok_or_else(|| AppError::BadRequest("Missing 'file' field".to_string()))?;
    let mime_type = mime_type.unwrap_or_else(|| "image/jpeg".to_string());
    let entity_type = entity_type
        .ok_or_else(|| AppError::BadRequest("Missing 'entity_type' field".to_string()))?;
    let entity_id = entity_id
        .ok_or_else(|| AppError::BadRequest("Missing 'entity_id' field".to_string()))?;

    let ext = match mime_type.as_str() {
        "image/png" => "png",
        "image/webp" => "webp",
        _ => "jpg",
    };
    let image_id = Uuid::new_v4();
    let r2_key = format!("{}/{}/{}.{}", entity_type, entity_id, image_id, ext);

    // Upload to R2
    state
        .s3
        .put_object()
        .bucket(&state.config.r2_bucket)
        .key(&r2_key)
        .body(file_bytes.into())
        .content_type(&mime_type)
        .send()
        .await
        .map_err(|e| AppError::Internal(anyhow::anyhow!("R2 upload failed: {e}")))?;

    // Insert DB record
    let now = chrono::Utc::now();
    sqlx::query(
        r#"
        INSERT INTO images (id, entity_type, entity_id, uploaded_by, r2_key, is_public, created_at)
        VALUES ($1, $2::entity_type, $3, $4, $5, $6, $7)
        "#,
    )
    .bind(image_id)
    .bind(&entity_type)
    .bind(entity_id)
    .bind(user.id)
    .bind(&r2_key)
    .bind(is_public)
    .bind(now)
    .execute(&state.db)
    .await?;

    let cdn_url = if is_public && !state.config.r2_public_url.is_empty() {
        Some(format!(
            "{}/{}",
            state.config.r2_public_url.trim_end_matches('/'),
            r2_key
        ))
    } else {
        None
    };

    Ok((
        StatusCode::CREATED,
        Json(ImageResponse {
            id: image_id,
            entity_type,
            entity_id,
            uploaded_by: user.id,
            r2_key,
            is_public,
            cdn_url,
            created_at: now,
        }),
    ))
}

// ─────────────────────────────────────────────
// GET /images/dish/:dish_id
// ─────────────────────────────────────────────

async fn list_dish_images(
    State(state): State<AppState>,
    _user: AuthUser,
    Path(dish_id): Path<Uuid>,
) -> AppResult<Json<Vec<ImageResponse>>> {
    let rows = sqlx::query(
        r#"
        SELECT id, entity_type::text, entity_id, uploaded_by, r2_key, is_public, created_at
        FROM images
        WHERE entity_type = 'dish'::entity_type
          AND entity_id = $1
          AND deleted_at IS NULL
        ORDER BY created_at DESC
        LIMIT 20
        "#,
    )
    .bind(dish_id)
    .fetch_all(&state.db)
    .await?;

    let images = rows
        .into_iter()
        .map(|r| -> Result<ImageResponse, sqlx::Error> {
            let is_public: bool = r.try_get("is_public")?;
            let r2_key: String = r.try_get("r2_key")?;
            let cdn_url = if is_public && !state.config.r2_public_url.is_empty() {
                Some(format!(
                    "{}/{}",
                    state.config.r2_public_url.trim_end_matches('/'),
                    r2_key
                ))
            } else {
                None
            };
            Ok(ImageResponse {
                id: r.try_get("id")?,
                entity_type: r.try_get("entity_type")?,
                entity_id: r.try_get("entity_id")?,
                uploaded_by: r.try_get("uploaded_by")?,
                r2_key,
                is_public,
                cdn_url,
                created_at: r.try_get("created_at")?,
            })
        })
        .collect::<Result<Vec<_>, _>>()?;

    Ok(Json(images))
}

// ─────────────────────────────────────────────
// GET /images/:id/url
// ─────────────────────────────────────────────

async fn get_presigned_url(
    State(state): State<AppState>,
    _user: AuthUser,
    Path(image_id): Path<Uuid>,
) -> AppResult<Json<serde_json::Value>> {
    let row = sqlx::query(
        "SELECT r2_key, is_public FROM images WHERE id = $1 AND deleted_at IS NULL",
    )
    .bind(image_id)
    .fetch_optional(&state.db)
    .await?
    .ok_or_else(|| AppError::NotFound("Image not found".to_string()))?;

    let r2_key: String = row.try_get("r2_key")?;
    let is_public: bool = row.try_get("is_public")?;

    if is_public && !state.config.r2_public_url.is_empty() {
        let cdn_url = format!(
            "{}/{}",
            state.config.r2_public_url.trim_end_matches('/'),
            r2_key
        );
        return Ok(Json(serde_json::json!({ "url": cdn_url, "expires_in": null })));
    }

    let presigner =
        aws_sdk_s3::presigning::PresigningConfig::expires_in(std::time::Duration::from_secs(3600))
            .map_err(|e| AppError::Internal(anyhow::anyhow!("Presigning config error: {e}")))?;

    let presigned = state
        .s3
        .get_object()
        .bucket(&state.config.r2_bucket)
        .key(&r2_key)
        .presigned(presigner)
        .await
        .map_err(|e| AppError::Internal(anyhow::anyhow!("Pre-sign failed: {e}")))?;

    Ok(Json(serde_json::json!({
        "url": presigned.uri().to_string(),
        "expires_in": 3600
    })))
}

// ─────────────────────────────────────────────
// POST /admin/images/:id/remove
// ─────────────────────────────────────────────

async fn admin_remove_image(
    State(state): State<AppState>,
    user: AuthUser,
    Path(image_id): Path<Uuid>,
) -> AppResult<Json<serde_json::Value>> {
    user.require_admin()?;

    let row = sqlx::query(
        "SELECT r2_key FROM images WHERE id = $1 AND deleted_at IS NULL",
    )
    .bind(image_id)
    .fetch_optional(&state.db)
    .await?
    .ok_or_else(|| AppError::NotFound("Image not found or already removed".to_string()))?;

    let r2_key: String = row.try_get("r2_key")?;

    sqlx::query("UPDATE images SET deleted_at = NOW() WHERE id = $1")
        .bind(image_id)
        .execute(&state.db)
        .await?;

    // Best-effort R2 deletion
    let _ = state
        .s3
        .delete_object()
        .bucket(&state.config.r2_bucket)
        .key(&r2_key)
        .send()
        .await;

    Ok(Json(serde_json::json!({ "ok": true })))
}
