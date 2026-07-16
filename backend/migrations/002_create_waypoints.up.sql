CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE waypoints (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pedagang_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    pelanggan_id UUID REFERENCES users(id) ON DELETE SET NULL,
    label VARCHAR(100) NOT NULL,
    address TEXT,
    location GEOGRAPHY(POINT, 4326) NOT NULL,
    notes TEXT,
    priority INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    preferred_time_start TIME,
    preferred_time_end TIME,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_waypoints_pedagang ON waypoints(pedagang_id);
CREATE INDEX idx_waypoints_pelanggan ON waypoints(pelanggan_id);
CREATE INDEX idx_waypoints_active ON waypoints(pedagang_id, is_active);
CREATE INDEX idx_waypoints_location ON waypoints USING GIST(location);
