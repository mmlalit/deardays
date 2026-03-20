# ai-weekly-page — Deployment

## Deploy
```bash
supabase functions deploy ai-weekly-page --no-verify-jwt
```

## How it works

1. **06:00 UTC Saturday** — `enqueue_weekly_page_generation()` (pg_cron) populates `generation_queue` with one row per (user, chapter) that has ≥ 3 memories this week.
2. **06:05–06:35 UTC Saturday** — four `net.http_post` cron jobs invoke this function every 10 minutes, each draining up to 20 pending queue items (5 concurrent AI calls at a time).

The cron schedules are created by migration `034_book_approach.sql`. No manual setup needed.

## Manual trigger (testing)
```bash
# Process up to 5 items
curl -X POST https://<project>.supabase.co/functions/v1/ai-weekly-page \
  -H "Authorization: Bearer <service_role_key>" \
  -H "Content-Type: application/json" \
  -d '{"limit":5}'
```

## Re-processing failed items
Failed queue rows have `status = 'failed'`. Reset them to retry:
```sql
UPDATE generation_queue SET status = 'pending' WHERE status = 'failed';
```
Then manually trigger the function.

## Required env vars (auto-injected by Supabase runtime)
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `AI_PROVIDER` / `AI_MODEL` / `OPENAI_API_KEY` — same as other AI functions
- `app.functions_url` — Supabase project functions base URL (set as DB setting)
- `app.service_role_key` — service role key (set as DB setting)
