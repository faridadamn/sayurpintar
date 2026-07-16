-- Suppliers for group buying
CREATE TABLE suppliers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(200) NOT NULL,
    address TEXT NOT NULL,
    phone VARCHAR(20) NOT NULL,
    location GEOGRAPHY(POINT, 4326),
    rating NUMERIC(3,2) DEFAULT 0.00 CHECK (rating >= 0 AND rating <= 5),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_suppliers_active ON suppliers(is_active);
CREATE INDEX idx_suppliers_location ON suppliers USING GIST(location);

-- Group orders (GrosirKu)
CREATE TABLE group_orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organizer_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    supplier_id UUID REFERENCES suppliers(id) ON DELETE SET NULL,
    product_id VARCHAR(100) NOT NULL,
    product_name VARCHAR(200) NOT NULL,
    target_qty NUMERIC(12,2) NOT NULL CHECK (target_qty > 0),
    current_qty NUMERIC(12,2) DEFAULT 0 CHECK (current_qty >= 0),
    group_price NUMERIC(14,2) NOT NULL CHECK (group_price > 0),
    regular_price NUMERIC(14,2) NOT NULL CHECK (regular_price > 0),
    unit VARCHAR(20) NOT NULL,
    deadline TIMESTAMPTZ NOT NULL,
    delivery_date VARCHAR(10) NOT NULL, -- YYYY-MM-DD
    delivery_point TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'full', 'ordered', 'delivered', 'cancelled')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_group_orders_status ON group_orders(status);
CREATE INDEX idx_group_orders_organizer ON group_orders(organizer_id);
CREATE INDEX idx_group_orders_supplier ON group_orders(supplier_id);
CREATE INDEX idx_group_orders_deadline ON group_orders(deadline) WHERE status = 'open';
CREATE INDEX idx_group_orders_product ON group_orders(product_id, status);

-- Group participants
CREATE TABLE group_participants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_order_id UUID REFERENCES group_orders(id) ON DELETE CASCADE NOT NULL,
    pedagang_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    qty NUMERIC(12,2) NOT NULL CHECK (qty > 0),
    total_price NUMERIC(14,2) NOT NULL CHECK (total_price >= 0),
    status VARCHAR(20) NOT NULL DEFAULT 'joined' CHECK (status IN ('joined', 'paid', 'received', 'cancelled')),
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(group_order_id, pedagang_id)
);

CREATE INDEX idx_group_participants_group ON group_participants(group_order_id);
CREATE INDEX idx_group_participants_pedagang ON group_participants(pedagang_id);
