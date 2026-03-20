/**
 * DearDays — k6 Load Test Suite
 *
 * Simulates realistic user behavior against the Supabase backend.
 * Tests the most performance-critical endpoints at scale.
 *
 * Prerequisites:
 *   1. Install k6: https://k6.io/docs/get-started/installation/
 *   2. Set environment variables (or pass via -e flag):
 *      - SUPABASE_URL: Your Supabase project URL
 *      - SUPABASE_ANON_KEY: Your Supabase anon key
 *      - TEST_USER_EMAIL: A test user's email
 *      - TEST_USER_PASSWORD: A test user's password
 *
 * Usage:
 *   k6 run load_tests/k6_supabase_load_test.js \
 *     -e SUPABASE_URL=https://xxx.supabase.co \
 *     -e SUPABASE_ANON_KEY=xxx \
 *     -e TEST_USER_EMAIL=test@example.com \
 *     -e TEST_USER_PASSWORD=xxx
 *
 * Stages:
 *   1. Ramp up to 50 virtual users over 2 minutes
 *   2. Hold at 50 VUs for 5 minutes (steady state)
 *   3. Spike to 200 VUs for 2 minutes (stress test)
 *   4. Ramp down over 1 minute
 */

import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const timelineLatency = new Trend('timeline_latency', true);
const entryCreateLatency = new Trend('entry_create_latency', true);
const onThisDayLatency = new Trend('on_this_day_latency', true);
const aiPolishLatency = new Trend('ai_polish_latency', true);

// Configuration
const SUPABASE_URL = __ENV.SUPABASE_URL || 'http://localhost:54321';
const SUPABASE_ANON_KEY = __ENV.SUPABASE_ANON_KEY || '';
const TEST_USER_EMAIL = __ENV.TEST_USER_EMAIL || 'loadtest@example.com';
const TEST_USER_PASSWORD = __ENV.TEST_USER_PASSWORD || 'loadtest123';

export const options = {
  stages: [
    { duration: '2m', target: 50 },   // Ramp up
    { duration: '5m', target: 50 },   // Steady state
    { duration: '2m', target: 200 },  // Spike
    { duration: '1m', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<2000'],  // 95% of requests under 2s
    errors: ['rate<0.05'],              // Error rate under 5%
    timeline_latency: ['p(95)<1000'],   // Timeline loads under 1s
    entry_create_latency: ['p(95)<3000'], // Entry creation under 3s
  },
};

const headers = {
  'Content-Type': 'application/json',
  'apikey': SUPABASE_ANON_KEY,
  'Authorization': '', // Set after login
};

// Login once per VU
export function setup() {
  const loginRes = http.post(
    `${SUPABASE_URL}/auth/v1/token?grant_type=password`,
    JSON.stringify({
      email: TEST_USER_EMAIL,
      password: TEST_USER_PASSWORD,
    }),
    { headers: { 'Content-Type': 'application/json', 'apikey': SUPABASE_ANON_KEY } }
  );

  check(loginRes, { 'login succeeded': (r) => r.status === 200 });

  if (loginRes.status !== 200) {
    console.error(`Login failed: ${loginRes.body}`);
    return { token: '' };
  }

  const body = JSON.parse(loginRes.body);
  return { token: body.access_token, userId: body.user.id };
}

export default function (data) {
  if (!data.token) return;

  const authHeaders = {
    ...headers,
    'Authorization': `Bearer ${data.token}`,
  };

  // Simulate real user behavior with weighted scenarios
  const scenario = Math.random();

  if (scenario < 0.4) {
    // 40% — Browse timeline (most common action)
    group('Timeline Browse', () => {
      const start = Date.now();
      const res = http.get(
        `${SUPABASE_URL}/rest/v1/journal_entries?user_id=eq.${data.userId}&order=entry_date.desc&limit=20`,
        { headers: authHeaders }
      );
      timelineLatency.add(Date.now() - start);
      const success = check(res, { 'timeline loaded': (r) => r.status === 200 });
      errorRate.add(!success);
    });
  } else if (scenario < 0.6) {
    // 20% — Load single entry detail
    group('Entry Detail', () => {
      // First get an entry ID
      const listRes = http.get(
        `${SUPABASE_URL}/rest/v1/journal_entries?user_id=eq.${data.userId}&limit=1&select=id`,
        { headers: authHeaders }
      );
      if (listRes.status === 200) {
        const entries = JSON.parse(listRes.body);
        if (entries.length > 0) {
          const res = http.get(
            `${SUPABASE_URL}/rest/v1/journal_entries?id=eq.${entries[0].id}&select=*,entry_media(*)`,
            { headers: authHeaders }
          );
          const success = check(res, { 'entry detail loaded': (r) => r.status === 200 });
          errorRate.add(!success);
        }
      }
    });
  } else if (scenario < 0.75) {
    // 15% — On This Day query (expensive RPC)
    group('On This Day', () => {
      const now = new Date();
      const monthDay = `${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
      const start = Date.now();
      const res = http.post(
        `${SUPABASE_URL}/rest/v1/rpc/get_on_this_day_entries`,
        JSON.stringify({ p_user_id: data.userId, p_month_day: monthDay }),
        { headers: authHeaders }
      );
      onThisDayLatency.add(Date.now() - start);
      const success = check(res, { 'on this day loaded': (r) => r.status === 200 });
      errorRate.add(!success);
    });
  } else if (scenario < 0.85) {
    // 10% — Create new entry
    group('Create Entry', () => {
      const start = Date.now();
      const res = http.post(
        `${SUPABASE_URL}/rest/v1/journal_entries`,
        JSON.stringify({
          user_id: data.userId,
          content: `Load test entry at ${new Date().toISOString()}`,
          mood: ['great', 'good', 'okay', 'low', 'tough'][Math.floor(Math.random() * 5)],
          entry_date: new Date().toISOString(),
          word_count: 10,
        }),
        { headers: { ...authHeaders, 'Prefer': 'return=minimal' } }
      );
      entryCreateLatency.add(Date.now() - start);
      const success = check(res, { 'entry created': (r) => r.status === 201 });
      errorRate.add(!success);
    });
  } else if (scenario < 0.95) {
    // 10% — Mood stats
    group('Mood Stats', () => {
      const res = http.get(
        `${SUPABASE_URL}/rest/v1/journal_entries?user_id=eq.${data.userId}&select=mood&mood=not.is.null`,
        { headers: authHeaders }
      );
      const success = check(res, { 'mood stats loaded': (r) => r.status === 200 });
      errorRate.add(!success);
    });
  } else {
    // 5% — Profile + streak (app open)
    group('App Open', () => {
      const responses = http.batch([
        ['GET', `${SUPABASE_URL}/rest/v1/profiles?id=eq.${data.userId}`, null, { headers: authHeaders }],
        ['GET', `${SUPABASE_URL}/rest/v1/streaks?user_id=eq.${data.userId}`, null, { headers: authHeaders }],
      ]);
      const success = check(responses[0], { 'profile loaded': (r) => r.status === 200 });
      errorRate.add(!success);
    });
  }

  // Think time: simulate realistic user pauses (1-5 seconds)
  sleep(Math.random() * 4 + 1);
}

export function teardown(data) {
  // Clean up load test entries
  if (data.token) {
    http.del(
      `${SUPABASE_URL}/rest/v1/journal_entries?user_id=eq.${data.userId}&content=like.Load test entry*`,
      null,
      {
        headers: {
          ...headers,
          'Authorization': `Bearer ${data.token}`,
        },
      }
    );
  }
}
