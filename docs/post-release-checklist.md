# Post-Release Monitoring Checklist

## Immediate (first 2 hours)
- [ ] Sentry: No new error types
- [ ] Sentry: Crash-free rate > 99.5%
- [ ] PostHog: DAU not dropping vs yesterday
- [ ] PostHog: `entry_created` rate stable
- [ ] PostHog: `ai_polish_used` rate stable
- [ ] Manual: Create entry on Android, verify save, check timeline
- [ ] Manual: Create entry on iOS, verify save, check timeline

## Day 1
- [ ] Sentry: Error rate within normal range
- [ ] PostHog: All funnel steps stable
- [ ] PostHog: No unusual sync_failed spikes
- [ ] Check Supabase dashboard for query latency

## Day 7
- [ ] Review Sentry issues created this week
- [ ] Check storage costs trending normally
- [ ] Verify no orphaned files accumulating
