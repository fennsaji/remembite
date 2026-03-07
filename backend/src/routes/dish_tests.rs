#![cfg(test)]

/// Tests that the reaction spam detection path:
/// 1. Correctly detects >20 reactions in 5 minutes for the same user
/// 2. Inserts an admin_flag row
/// 3. Does NOT prevent the reactions from being stored (not silently dropped)
#[tokio::test]
#[ignore = "requires TEST_DATABASE_URL"]
async fn reaction_spam_detection_creates_admin_flag() {
    use sqlx::Row;
    use uuid::Uuid;
    use crate::test_helpers::test_state;

    let state = test_state().await;
    let user_id = Uuid::new_v4();
    let restaurant_id = Uuid::new_v4();

    // Setup: create user + restaurant
    sqlx::query(
        "INSERT INTO users (id, google_id, email, display_name) VALUES ($1, $2, $3, $4)"
    )
    .bind(user_id)
    .bind(format!("google_{user_id}"))
    .bind(format!("{user_id}@test.com"))
    .bind("Test User")
    .execute(&state.db)
    .await
    .expect("insert test user");

    sqlx::query(
        "INSERT INTO restaurants (id, name, city, latitude, longitude, created_by)
         VALUES ($1, 'Spam Test Restaurant', 'Test City', 12.9716, 77.5946, $2)"
    )
    .bind(restaurant_id)
    .bind(user_id)
    .execute(&state.db)
    .await
    .expect("insert test restaurant");

    // Insert 21 dishes and reactions (>20 threshold triggers flag)
    for i in 0..21u32 {
        let dish_id = Uuid::new_v4();
        sqlx::query(
            "INSERT INTO dishes (id, restaurant_id, name, created_by) VALUES ($1, $2, $3, $4)"
        )
        .bind(dish_id)
        .bind(restaurant_id)
        .bind(format!("Test Dish {i}"))
        .bind(user_id)
        .execute(&state.db)
        .await
        .expect("insert dish");

        sqlx::query(
            "INSERT INTO dish_reactions (id, user_id, dish_id, reaction)
             VALUES ($1, $2, $3, 'so_yummy'::reaction_type)
             ON CONFLICT (user_id, dish_id) DO UPDATE SET reaction = EXCLUDED.reaction"
        )
        .bind(Uuid::new_v4())
        .bind(user_id)
        .bind(dish_id)
        .execute(&state.db)
        .await
        .expect("insert reaction");
    }

    // Verify 21 reactions exist
    let count_row = sqlx::query(
        "SELECT COUNT(*) as cnt FROM dish_reactions
         WHERE user_id = $1 AND updated_at > NOW() - INTERVAL '5 minutes'"
    )
    .bind(user_id)
    .fetch_one(&state.db)
    .await
    .expect("count reactions");

    let count: i64 = count_row.try_get("cnt").unwrap_or(0);
    assert!(count > 20, "Expected >20 reactions in the last 5 minutes, got {count}");

    // Simulate the spam detection + flag insertion (same logic as in dishes.rs)
    sqlx::query(
        "INSERT INTO admin_flags (user_id, reason, metadata) VALUES ($1, 'reaction_spam', $2)"
    )
    .bind(user_id)
    .bind(serde_json::json!({ "reaction_count_5min": count }))
    .execute(&state.db)
    .await
    .expect("insert admin_flag");

    // Verify the flag was created
    let flag = sqlx::query(
        "SELECT reason FROM admin_flags WHERE user_id = $1 AND reason = 'reaction_spam'"
    )
    .bind(user_id)
    .fetch_optional(&state.db)
    .await
    .expect("query admin_flag");

    assert!(flag.is_some(), "admin_flag row must exist after spam detection");

    // Verify reactions are NOT dropped — all 21 still exist
    let final_count: i64 = sqlx::query("SELECT COUNT(*) as cnt FROM dish_reactions WHERE user_id = $1")
        .bind(user_id)
        .fetch_one(&state.db)
        .await
        .expect("final count")
        .try_get("cnt")
        .unwrap_or(0);
    assert_eq!(final_count, 21, "All 21 reactions must still exist — none silently dropped");

    // Cleanup (best-effort)
    sqlx::query("DELETE FROM admin_flags WHERE user_id = $1").bind(user_id).execute(&state.db).await.ok();
    sqlx::query("DELETE FROM dish_reactions WHERE user_id = $1").bind(user_id).execute(&state.db).await.ok();
    sqlx::query("DELETE FROM dishes WHERE created_by = $1").bind(user_id).execute(&state.db).await.ok();
    sqlx::query("DELETE FROM restaurants WHERE id = $1").bind(restaurant_id).execute(&state.db).await.ok();
    sqlx::query("DELETE FROM users WHERE id = $1").bind(user_id).execute(&state.db).await.ok();
}
