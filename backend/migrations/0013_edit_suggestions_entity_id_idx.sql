-- Speeds up per-entity suggestion lookups (list by entity_id + status filter).
CREATE INDEX IF NOT EXISTS idx_edit_suggestions_entity_id_status
    ON edit_suggestions(entity_id, status);
