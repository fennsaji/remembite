-- PRD 1.3 "Private notes input" — the field existed in the Flutter UI but
-- had nowhere on the server to land. Notes are private to the user's own
-- reaction on a dish (never exposed publicly, matches the "Private Notes"
-- section label and CLAUDE.md's "Private notes" free-tier row).
ALTER TABLE dish_reactions ADD COLUMN IF NOT EXISTS notes TEXT;
