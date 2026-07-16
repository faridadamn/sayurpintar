CREATE TABLE visits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    route_id UUID NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
    waypoint_id UUID NOT NULL REFERENCES waypoints(id) ON DELETE CASCADE,
    pelanggan_id UUID REFERENCES users(id) ON DELETE SET NULL,
    order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
    visit_order INT NOT NULL,
    planned_arrival TIME,
    actual_arrival TIMESTAMPTZ,
    actual_departure TIMESTAMPTZ,
    items_sold JSONB,
    amount DECIMAL(12,2),
    payment_method VARCHAR(20) DEFAULT 'cash',
    payment_status VARCHAR(20) DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid', 'partial', 'deferred')),
    notes TEXT,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'arrived', 'completed', 'skipped')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_visits_route ON visits(route_id);
CREATE INDEX idx_visits_pelanggan ON visits(pelanggan_id);
CREATE INDEX idx_visits_status ON visits(route_id, status);
