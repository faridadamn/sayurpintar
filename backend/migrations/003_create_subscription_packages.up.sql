CREATE TABLE subscription_packages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pedagang_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    items JSONB NOT NULL DEFAULT '[]',
    price DECIMAL(12,2) NOT NULL CHECK (price >= 0),
    frequency VARCHAR(20) NOT NULL CHECK (frequency IN ('daily', 'weekly', 'biweekly')),
    delivery_days INT[] NOT NULL DEFAULT '{}',
    max_subscribers INT DEFAULT 0 CHECK (max_subscribers >= 0),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_sub_packages_pedagang ON subscription_packages(pedagang_id);
CREATE INDEX idx_sub_packages_active ON subscription_packages(pedagang_id, is_active);
