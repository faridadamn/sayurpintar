-- SayurPintar database privilege groups.
-- Run this as a database owner on each environment.
-- Login roles must be created separately and granted membership in one group.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_roles WHERE rolname = 'sayurpintar_migrator'
  ) THEN
    CREATE ROLE sayurpintar_migrator NOLOGIN;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_roles WHERE rolname = 'sayurpintar_runtime'
  ) THEN
    CREATE ROLE sayurpintar_runtime NOLOGIN;
  END IF;
END
$$;

GRANT CONNECT ON DATABASE neondb
  TO sayurpintar_migrator, sayurpintar_runtime;

GRANT USAGE, CREATE ON SCHEMA public TO sayurpintar_migrator;
GRANT USAGE ON SCHEMA public TO sayurpintar_runtime;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public
  TO sayurpintar_migrator;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public
  TO sayurpintar_migrator;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public
  TO sayurpintar_runtime;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public
  TO sayurpintar_runtime;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL PRIVILEGES ON TABLES TO sayurpintar_migrator;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL PRIVILEGES ON SEQUENCES TO sayurpintar_migrator;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO sayurpintar_runtime;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO sayurpintar_runtime;

-- Example only; create login roles through Neon secret management, not in source:
-- GRANT sayurpintar_migrator TO <migration_login_role>;
-- GRANT sayurpintar_runtime TO <application_login_role>;
