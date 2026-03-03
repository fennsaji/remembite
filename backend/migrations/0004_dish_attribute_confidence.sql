ALTER TABLE dish_attribute_priors
  ADD COLUMN IF NOT EXISTS confidence_score DOUBLE PRECISION;
