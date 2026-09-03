-- Google Play RTDNs arrive over Pub/Sub, which does not guarantee ordering.
-- A delayed EXPIRED could land after a newer RENEWED and strip Pro from a
-- paying user. Record the eventTimeMillis of the last notification applied
-- for each user so older notifications can be dropped.
--
-- Nullable: existing users have no recorded notification, and a NULL must be
-- treated as "nothing applied yet" (accept the notification).
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_notification_at TIMESTAMPTZ;
