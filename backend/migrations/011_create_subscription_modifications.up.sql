CREATE TABLE subscription_modifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
    delivery_date DATE NOT NULL,
    items JSONB,
    skip_delivery BOOLEAN DEFAULT FALSE,
    reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(subscription_id, delivery_date)
);

CREATE INDEX idx_sub_mods_subscription ON subscription_modifications(subscription_id);
CREATE INDEX idx_sub_mods_delivery_date ON subscription_modifications(delivery_date);
