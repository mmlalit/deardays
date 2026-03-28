# DearDays Load Testing

Simulates 1000 concurrent users against the real Supabase backend.

## Setup

```bash
# Install k6
winget install k6

# Install Node.js (for auth helper)
# Already installed if you have Flutter
```

## Quick Start

```bash
cd load_test

# Step 1: Get an access token
node auth_helper.js

# Step 2: Run load test (copy token from step 1)
k6 run -e ACCESS_TOKEN=<token> load_test.js
```

## Run Profiles

```bash
# Light (50 users, 1 min) — quick sanity check
k6 run -e ACCESS_TOKEN=<token> --vus 50 --duration 1m load_test.js

# Medium (200 users, 3 min) — pre-launch validation
k6 run -e ACCESS_TOKEN=<token> --vus 200 --duration 3m load_test.js

# Full (1000 users, 5 min) — production readiness
k6 run -e ACCESS_TOKEN=<token> load_test.js

# Export results to JSON
k6 run -e ACCESS_TOKEN=<token> load_test.js --out json=results.json
```

## What It Tests

| Operation | Weight | Threshold (p95) |
|-----------|--------|-----------------|
| Read timeline (20 entries) | Every iteration | < 300ms |
| Read profile | Every iteration | — |
| Write entry | Every iteration | < 1000ms |
| Read chapters | Every iteration | — |
| Read books | Every iteration | — |
| Search (keyword) | Every iteration | — |

## Thresholds

- **p95 latency**: < 500ms (all requests)
- **p99 latency**: < 2000ms
- **Error rate**: < 5%
- **Timeline reads**: p95 < 300ms
- **Entry writes**: p95 < 1000ms

## Cleanup

```bash
# If teardown didn't run (Ctrl+C during test)
node cleanup.js
```

## Supabase Limits to Watch

| Resource | Free Tier | Pro Tier |
|----------|-----------|----------|
| DB connections | 60 | 120 |
| API requests | 500K/month | Unlimited |
| Storage | 1GB | 100GB |
| Edge function invocations | 500K/month | 2M/month |

Monitor during test: Supabase Dashboard → Database → Connections
