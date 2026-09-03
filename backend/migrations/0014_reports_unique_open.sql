-- One open report per reporter per entity.
--
-- create_report previously inserted unconditionally, so a single user could
-- file the same complaint repeatedly and inflate the moderation queue. The
-- handler now relies on this partial unique index for its ON CONFLICT clause.

-- Collapse any duplicates that already exist, keeping the earliest report.
DELETE FROM reports r
USING reports keep
WHERE r.status = 'open'
  AND keep.status = 'open'
  AND r.reported_by = keep.reported_by
  AND r.entity_type = keep.entity_type
  AND r.entity_id = keep.entity_id
  AND (r.created_at, r.id) > (keep.created_at, keep.id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_reports_one_open_per_reporter
    ON reports (reported_by, entity_type, entity_id)
    WHERE status = 'open';
