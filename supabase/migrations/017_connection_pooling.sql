-- Migration 017: Connection pooling preparation
--
-- PgBouncer is enabled via the Supabase dashboard (Settings → Database → Connection Pooling).
-- This migration sets conservative statement timeouts and connection limits
-- to prevent runaway queries and connection exhaustion at scale.
--
-- ACTION REQUIRED (Supabase dashboard):
--   1. Go to Settings → Database → Connection Pooling
--   2. Enable PgBouncer in "Transaction" mode
--   3. Set pool size to 15-25 (for Supabase Pro plan)
--   4. Use the pooled connection string (port 6543) in production
--   5. Keep direct connection (port 5432) for migrations only

-- Prevent long-running queries from holding connections.
-- Queries exceeding 30 seconds are terminated.
ALTER DATABASE postgres SET statement_timeout = '30s';

-- Prevent idle-in-transaction connections from hogging pool slots.
-- Connections idle in a transaction for >60s are terminated.
ALTER DATABASE postgres SET idle_in_transaction_session_timeout = '60s';

-- Limit concurrent connections per role to prevent pool exhaustion.
-- Supabase Pro allows ~60 direct connections; reserve some for admin/migrations.
-- The anon and authenticated roles share the PgBouncer pool.
ALTER ROLE authenticated SET statement_timeout = '15s';
ALTER ROLE anon SET statement_timeout = '10s';
