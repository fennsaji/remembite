-- Allow reporting images by adding 'image' to the entity_type enum.
-- Images uploaded against dishes/restaurants still use 'dish'/'restaurant'.
ALTER TYPE entity_type ADD VALUE IF NOT EXISTS 'image';
