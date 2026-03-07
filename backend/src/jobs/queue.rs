use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::sync::mpsc;
use uuid::Uuid;

use crate::error::AppResult;

/// All job types that can be enqueued.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum Job {
    ClassifyDish {
        dish_id: Uuid,
        dish_name: String,
        cuisine: String,
    },
    ParseMenuOcr {
        raw_text: String,
        restaurant_id: Uuid,
        user_id: Uuid,
    },
    RecomputeTasteVectors,
}

/// Abstraction over job queue implementations.
/// Default: InProcessQueue (Tokio channels).
/// Swap to RedisQueue when load demands it — no business logic changes.
#[async_trait]
pub trait JobQueue: Send + Sync {
    async fn enqueue(&self, job: Job) -> AppResult<()>;
}

/// In-process job queue backed by a Tokio MPSC channel.
/// Zero infrastructure overhead — suitable for MVP scale.
pub struct InProcessQueue {
    sender: mpsc::Sender<Job>,
}

impl InProcessQueue {
    /// Creates a new queue. Returns (queue, receiver).
    /// The receiver is passed to the worker loop.
    pub fn new(capacity: usize) -> (Arc<Self>, mpsc::Receiver<Job>) {
        let (sender, receiver) = mpsc::channel(capacity);
        (Arc::new(Self { sender }), receiver)
    }
}

#[async_trait]
impl JobQueue for InProcessQueue {
    async fn enqueue(&self, job: Job) -> AppResult<()> {
        self.sender
            .send(job)
            .await
            .map_err(|e| crate::error::AppError::Internal(anyhow::anyhow!("Job queue send error: {e}")))
    }
}
