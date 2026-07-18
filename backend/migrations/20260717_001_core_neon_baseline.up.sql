CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE IF NOT EXISTS users (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    phone varchar(20) NOT NULL UNIQUE,
    name varchar(100) NOT NULL,
    role varchar(20) NOT NULL CHECK (role IN ('pedagang', 'pelanggan', 'admin')),
    avatar_url text,
    address varchar(500),
    location geography(Point, 4326),
    area varchar(50),
    is_verified boolean NOT NULL DEFAULT false,
    otp_code varchar(10),
    otp_expires_at timestamptz,
    last_login_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_area ON users(area);
CREATE INDEX IF NOT EXISTS idx_users_location ON users USING gist(location);

CREATE TABLE IF NOT EXISTS orders (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_id uuid,
    pedagang_id uuid NOT NULL REFERENCES users(id),
    pelanggan_id uuid NOT NULL REFERENCES users(id),
    items jsonb NOT NULL DEFAULT '[]'::jsonb,
    total_price numeric(14,2) NOT NULL CHECK (total_price >= 0),
    status varchar(20) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'preparing', 'delivering', 'delivered', 'cancelled', 'skipped')),
    delivery_date date NOT NULL,
    delivery_notes text,
    delivered_at timestamptz,
    cancelled_at timestamptz,
    cancel_reason text,
    rating integer CHECK (rating BETWEEN 1 AND 5),
    rating_comment text,
    rated_at timestamptz,
    payment_method varchar(20) NOT NULL DEFAULT 'cash',
    payment_status varchar(20) NOT NULL DEFAULT 'pending'
        CHECK (payment_status IN ('pending', 'paid', 'partial', 'deferred')),
    paid_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_orders_pedagang_date ON orders(pedagang_id, delivery_date);
CREATE INDEX IF NOT EXISTS idx_orders_pelanggan_created ON orders(pelanggan_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);

CREATE TABLE IF NOT EXISTS transactions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    pedagang_id uuid NOT NULL REFERENCES users(id),
    pelanggan_id uuid REFERENCES users(id),
    order_id uuid REFERENCES orders(id),
    debt_id uuid,
    type varchar(20) NOT NULL
        CHECK (type IN ('sale', 'purchase', 'expense', 'payment', 'refund')),
    amount numeric(14,2) NOT NULL CHECK (amount > 0),
    payment_method varchar(20) NOT NULL
        CHECK (payment_method IN ('cash', 'qris', 'transfer', 'ewallet')),
    payment_gateway varchar(50),
    gateway_transaction_id varchar(150),
    gateway_status varchar(50),
    status varchar(20) NOT NULL DEFAULT 'completed'
        CHECK (status IN ('completed', 'pending', 'failed', 'refunded')),
    notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_transactions_pedagang_created
    ON transactions(pedagang_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_order ON transactions(order_id);
