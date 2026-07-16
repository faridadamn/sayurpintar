CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pedagang_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    pelanggan_id UUID REFERENCES users(id) ON DELETE SET NULL,
    order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
    debt_id UUID,
    type VARCHAR(20) NOT NULL CHECK (type IN ('sale', 'purchase', 'expense', 'payment', 'refund')),
    amount DECIMAL(12,2) NOT NULL,
    payment_method VARCHAR(20) DEFAULT 'cash' CHECK (payment_method IN ('cash', 'qris', 'transfer', 'ewallet')),
    payment_gateway VARCHAR(50),
    gateway_transaction_id VARCHAR(200),
    gateway_status VARCHAR(50),
    status VARCHAR(20) DEFAULT 'completed' CHECK (status IN ('completed', 'pending', 'failed', 'refunded')),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_transactions_pedagang ON transactions(pedagang_id, created_at);
CREATE INDEX idx_transactions_order ON transactions(order_id);
CREATE INDEX idx_transactions_debt ON transactions(debt_id);
