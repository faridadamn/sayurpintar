CREATE TABLE debts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pedagang_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    pelanggan_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
    amount DECIMAL(12,2) NOT NULL,
    amount_paid DECIMAL(12,2) DEFAULT 0,
    remaining DECIMAL(12,2) GENERATED ALWAYS AS (amount - amount_paid) STORED,
    status VARCHAR(20) DEFAULT 'outstanding' CHECK (status IN ('outstanding', 'partial', 'settled', 'written_off')),
    reminder_count INT DEFAULT 0,
    last_reminder_at TIMESTAMPTZ,
    due_date DATE,
    settled_at TIMESTAMPTZ,
    write_off_reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_debts_pedagang ON debts(pedagang_id, status);
CREATE INDEX idx_debts_pelanggan ON debts(pelanggan_id, status);
CREATE INDEX idx_debts_due ON debts(due_date, status);

-- Add FK from transactions.debt_id → debts.id (deferred because debts table created after transactions)
ALTER TABLE transactions ADD CONSTRAINT fk_transactions_debt FOREIGN KEY (debt_id) REFERENCES debts(id) ON DELETE SET NULL;
