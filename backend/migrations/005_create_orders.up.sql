CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    subscription_id UUID REFERENCES subscriptions(id) ON DELETE SET NULL,
    pedagang_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    pelanggan_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    items JSONB NOT NULL DEFAULT '[]',
    total_price DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (total_price >= 0),
    status VARCHAR(20) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'preparing', 'delivering', 'delivered', 'cancelled', 'skipped')),
    delivery_date DATE NOT NULL,
    delivery_notes TEXT,
    delivered_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    cancel_reason TEXT,
    rating INT CHECK (rating BETWEEN 1 AND 5),
    rating_comment TEXT,
    rated_at TIMESTAMPTZ,
    payment_method VARCHAR(20) DEFAULT 'cash',
    payment_status VARCHAR(20) DEFAULT 'pending'
        CHECK (payment_status IN ('pending', 'paid', 'partial', 'deferred')),
    paid_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_orders_pedagang_date ON orders(pedagang_id, delivery_date);
CREATE INDEX idx_orders_pelanggan_date ON orders(pelanggan_id, delivery_date);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_subscription ON orders(subscription_id);
CREATE INDEX idx_orders_delivery_date ON orders(delivery_date);
