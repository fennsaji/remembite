CREATE TABLE dish_intents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    dish_id UUID NOT NULL REFERENCES dishes(id) ON DELETE CASCADE,
    intent VARCHAR(32) NOT NULL DEFAULT 'want_to_try',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, dish_id)
);

CREATE INDEX idx_dish_intents_user ON dish_intents(user_id);
CREATE INDEX idx_dish_intents_dish ON dish_intents(dish_id);
