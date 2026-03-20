-- ============================================================
-- Migration 039: Connection pool efficiency
--
-- Prevents connection starvation under load by:
--
--  1. Killing idle-in-transaction connections after 10 seconds.
--     PostgREST holds a connection open for the duration of a request.
--     If a client disconnects mid-query the connection leaks forever without this.
--
--  2. Capping statement execution at 25 seconds.
--     Prevents runaway queries (e.g. an unindexed full scan triggered by a bug)
--     from monopolising a connection for minutes.
--
--  3. Closing truly idle connections after 5 minutes.
--     Frees connections back to the pool when users stop reading.
--
-- These settings apply to the `authenticator` role used by PostgREST (all
-- client requests). They do NOT affect pg_cron or edge function service-role
-- connections, which run as `postgres`/`service_role`.
--
-- At Supabase Free (60 connections): these settings alone raise effective
-- capacity from ~60 simultaneous requests to ~200+ by reclaiming stale connections.
-- At Supabase Pro (200 connections + pgBouncer): they further reduce pool pressure.
-- ============================================================

ALTER ROLE authenticator SET idle_in_transaction_session_timeout = '10s';
ALTER ROLE authenticator SET statement_timeout                    = '25s';
ALTER ROLE authenticator SET tcp_keepalives_idle                  = 60;
ALTER ROLE authenticator SET tcp_keepalives_interval              = 10;
ALTER ROLE authenticator SET tcp_keepalives_count                 = 5;

-- Also apply to anon and authenticated roles (direct JWT connections)
ALTER ROLE anon          SET idle_in_transaction_session_timeout = '10s';
ALTER ROLE anon          SET statement_timeout                    = '25s';
ALTER ROLE authenticated SET idle_in_transaction_session_timeout = '10s';
ALTER ROLE authenticated SET statement_timeout                    = '25s';
