# generate-reflections — Deployment

## Deploy
```bash
supabase functions deploy generate-reflections --no-verify-jwt
```

## Schedule (Supabase Dashboard → Database → Cron Jobs)

Add these three cron jobs via the Supabase Dashboard or SQL:

```sql
-- Weekly: every Sunday at 23:00 UTC
SELECT cron.schedule(
  'weekly-reflections',
  '0 23 * * 0',
  $$
  SELECT net.http_post(
    url := current_setting('app.functions_url') || '/generate-reflections',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.service_role_key')
    ),
    body := '{"period":"weekly"}'::jsonb
  );
  $$
);

-- Monthly: 1st of each month at 23:30 UTC
SELECT cron.schedule(
  'monthly-reflections',
  '30 23 1 * *',
  $$
  SELECT net.http_post(
    url := current_setting('app.functions_url') || '/generate-reflections',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.service_role_key')
    ),
    body := '{"period":"monthly"}'::jsonb
  );
  $$
);

-- Yearly: January 1st at 23:45 UTC
SELECT cron.schedule(
  'yearly-reflections',
  '45 23 1 1 *',
  $$
  SELECT net.http_post(
    url := current_setting('app.functions_url') || '/generate-reflections',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.service_role_key')
    ),
    body := '{"period":"yearly"}'::jsonb
  );
  $$
);
```

## Manual trigger (testing)
```bash
curl -X POST https://<project>.supabase.co/functions/v1/generate-reflections \
  -H "Authorization: Bearer <service_role_key>" \
  -H "Content-Type: application/json" \
  -d '{"period":"weekly"}'
```

## Required env vars
- `GEMINI_API_KEY` — already set for other AI functions
- `SUPABASE_URL` — auto-injected by Supabase runtime
- `SUPABASE_SERVICE_ROLE_KEY` — auto-injected by Supabase runtime
