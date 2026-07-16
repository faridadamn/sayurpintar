CREATE TABLE routes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pedagang_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    date DATE NOT NULL,
    start_location GEOGRAPHY(POINT, 4326),
    waypoint_ids UUID[] NOT NULL,
    optimized_order UUID[],
    total_distance_km DECIMAL(8,2),
    estimated_duration_min INT,
    estimated_fuel_cost DECIMAL(10,2),
    actual_distance_km DECIMAL(8,2),
    actual_duration_min INT,
    status VARCHAR(20) DEFAULT 'planned' CHECK (status IN ('planned', 'in_progress', 'completed', 'cancelled')),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(pedagang_id, date)
);

CREATE INDEX idx_routes_pedagang_date ON routes(pedagang_id, date);
CREATE INDEX idx_routes_status ON routes(status);
