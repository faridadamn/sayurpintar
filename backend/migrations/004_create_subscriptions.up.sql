CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    package_id UUID NOT NULL REFERENCES subscription_packages(id) ON DELETE CASCADE,
    pedagang_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    pelanggan_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    payment_method VARCHAR(20) DEFAULT 'cash' CHECK (payment_method IN ('cash', 'qris', 'transfer')),
    payment_frequency VARCHAR(20) DEFAULT 'per_delivery' CHECK (payment_frequency IN ('per_delivery', 'weekly', 'monthly')),
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'paused', 'cancelled', 'expired')),
    start_date DATE NOT NULL,
    end_date DATE,
    pause_reason TEXT,
    paused_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    cancel_reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(pelanggan_id, package_id)
);

CREATE INDEX idx_subscriptions_pedagang ON subscriptions(pedagang_id);
CREATE INDEX idx_subscriptions_pelanggan ON subscriptions(pelanggan_id);
CREATE INDEX idx_subscriptions_status ON subscriptions(status);
CREATE INDEX idx_subscriptions_package ON subscriptions(package_id);
