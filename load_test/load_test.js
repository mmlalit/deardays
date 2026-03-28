/**
 * DearDays — k6 Load Test Script
 *
 * Simulates 1000 concurrent users hitting the real Supabase backend.
 * Tests the 6 most common API operations:
 *   1. Read timeline (GET journal_entries)
 *   2. Read profile (GET profiles)
 *   3. Write entry (POST journal_entries)
 *   4. Read chapters (GET chapters)
 *   5. Read books (GET books)
 *   6. Search entries (GET with ilike filter)
 *
 * Prerequisites:
 *   1. Install k6: winget install k6  (or https://k6.io/docs/get-started/installation/)
 *   2. Get a valid access token (see auth_helper.js or use the one below)
 *
 * Run:
 *   k6 run load_test.js                          # default: 100 VUs, 3 min
 *   k6 run --vus 1000 --duration 5m load_test.js # full load
 *   k6 run load_test.js --out json=results.json  # export results
 *
 * Ramp up gradually (recommended):
 *   k6 run load_test.js
 *   (uses the stages defined below)
 */

import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

// ─────────────────────────────────────────────────────────────────────────────
// Configuration
// ─────────────────────────────────────────────────────────────────────────────

const SUPABASE_URL = __ENV.SUPABASE_URL || 'https://mcmlawztwyrjcwmieciw.supabase.co';
const ANON_KEY = __ENV.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1jbWxhd3p0d3lyamN3bWllY2l3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4Nzc0NTgsImV4cCI6MjA4ODQ1MzQ1OH0.qFvDzJrHFUaJjucCxkJXvmtkRdumhm5wC0DxQu-Q-AE';

// Set this to a valid access token from a signed-in user session.
// Get it by running: node auth_helper.js
const ACCESS_TOKEN = __ENV.ACCESS_TOKEN || '';
const USER_ID = __ENV.USER_ID || '';

if (!ACCESS_TOKEN) {
  console.warn('⚠ ACCESS_TOKEN not set. Run: node auth_helper.js to get one, then:');
  console.warn('  k6 run -e ACCESS_TOKEN=<token> -e USER_ID=<id> load_test.js');
}

// Extract user_id from JWT if not provided via env
function getUserId() {
  if (USER_ID) return USER_ID;
  try {
    const parts = ACCESS_TOKEN.split('.');
    if (parts.length >= 2) {
      const payload = JSON.parse(decodeURIComponent(escape(atob(parts[1].replace(/-/g, '+').replace(/_/g, '/')))));
      return payload.sub || '';
    }
  } catch (_) {}
  return '';
}
const RESOLVED_USER_ID = getUserId();

// ─────────────────────────────────────────────────────────────────────────────
// Load profile — ramp up to 1000 users over 5 minutes
// ─────────────────────────────────────────────────────────────────────────────

export const options = {
  stages: [
    { duration: '30s', target: 50 },    // warm up
    { duration: '1m',  target: 200 },   // ramp
    { duration: '2m',  target: 1000 },  // peak load
    { duration: '1m',  target: 500 },   // sustain
    { duration: '30s', target: 0 },     // cool down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500', 'p(99)<2000'],  // 95th < 500ms, 99th < 2s
    http_req_failed:   ['rate<0.05'],                  // < 5% error rate
    'read_timeline_duration': ['p(95)<300'],
    'write_entry_duration':   ['p(95)<1000'],
  },
};

// ─────────────────────────────────────────────────────────────────────────────
// Custom metrics
// ─────────────────────────────────────────────────────────────────────────────

const readTimelineDuration = new Trend('read_timeline_duration');
const readProfileDuration  = new Trend('read_profile_duration');
const writeEntryDuration   = new Trend('write_entry_duration');
const readChaptersDuration = new Trend('read_chapters_duration');
const searchDuration       = new Trend('search_duration');
const errorCount           = new Counter('error_count');
const successRate          = new Rate('success_rate');

// ─────────────────────────────────────────────────────────────────────────────
// Shared headers
// ─────────────────────────────────────────────────────────────────────────────

const headers = {
  'apikey': ANON_KEY,
  'Authorization': `Bearer ${ACCESS_TOKEN}`,
  'Content-Type': 'application/json',
  'Prefer': 'return=minimal',
};

const readHeaders = {
  'apikey': ANON_KEY,
  'Authorization': `Bearer ${ACCESS_TOKEN}`,
};

// ─────────────────────────────────────────────────────────────────────────────
// Main test scenario — each VU runs this in a loop
// ─────────────────────────────────────────────────────────────────────────────

export default function () {

  // ── 1. Read timeline (most frequent — 40% of traffic) ───────────────────
  group('Read Timeline', () => {
    // Uses idx_entries_user_date index: (user_id, entry_date DESC)
    const res = http.get(
      `${SUPABASE_URL}/rest/v1/journal_entries?select=id,content,mood,entry_date,has_photo,has_voice,word_count&user_id=eq.${RESOLVED_USER_ID}&order=entry_date.desc&limit=20`,
      { headers: readHeaders, tags: { name: 'GET_timeline' } }
    );
    readTimelineDuration.add(res.timings.duration);
    const ok = check(res, {
      'timeline: status 200': (r) => r.status === 200,
      'timeline: has body':   (r) => r.body && r.body.length > 2,
    });
    if (!ok) errorCount.add(1);
    successRate.add(ok);
  });

  sleep(0.5);

  // ── 2. Read profile ─────────────────────────────────────────────────────
  group('Read Profile', () => {
    const res = http.get(
      `${SUPABASE_URL}/rest/v1/profiles?select=id,display_name,writing_style,is_subscribed,reminder_time&limit=1`,
      { headers: readHeaders, tags: { name: 'GET_profile' } }
    );
    readProfileDuration.add(res.timings.duration);
    const ok = check(res, {
      'profile: status 200': (r) => r.status === 200,
    });
    if (!ok) errorCount.add(1);
    successRate.add(ok);
  });

  sleep(0.3);

  // ── 3. Write a journal entry (10% of traffic) ──────────────────────────
  group('Write Entry', () => {
    const now = new Date().toISOString();
    const payload = JSON.stringify({
      user_id: RESOLVED_USER_ID,
      content: `[LOAD_TEST] k6 entry at ${now} VU=${__VU} iter=${__ITER}`,
      raw_content: `[LOAD_TEST] k6 raw at ${now}`,
      mood: ['great', 'good', 'okay', 'low', 'tough'][Math.floor(Math.random() * 5)],
      entry_date: now.split('T')[0],
      has_photo: false,
      has_voice: false,
      is_milestone: false,
      is_ai_polished: false,
      is_client_encrypted: false,
      word_count: 8,
    });

    const res = http.post(
      `${SUPABASE_URL}/rest/v1/journal_entries`,
      payload,
      { headers, tags: { name: 'POST_entry' } }
    );
    writeEntryDuration.add(res.timings.duration);
    const ok = check(res, {
      'write: status 2xx': (r) => r.status >= 200 && r.status < 300,
    });
    if (!ok) errorCount.add(1);
    successRate.add(ok);
  });

  sleep(0.5);

  // ── 4. Read chapters ────────────────────────────────────────────────────
  group('Read Chapters', () => {
    const res = http.get(
      `${SUPABASE_URL}/rest/v1/chapters?select=id,title,color,created_at&order=created_at.asc`,
      { headers: readHeaders, tags: { name: 'GET_chapters' } }
    );
    readChaptersDuration.add(res.timings.duration);
    const ok = check(res, {
      'chapters: status 200': (r) => r.status === 200,
    });
    if (!ok) errorCount.add(1);
    successRate.add(ok);
  });

  sleep(0.3);

  // ── 5. Read books ──────────────────────────────────────────────────────
  group('Read Books', () => {
    const res = http.get(
      `${SUPABASE_URL}/rest/v1/books?select=id,title,created_at&order=created_at.desc&limit=10`,
      { headers: readHeaders, tags: { name: 'GET_books' } }
    );
    const ok = check(res, {
      'books: status 200': (r) => r.status === 200,
    });
    if (!ok) errorCount.add(1);
    successRate.add(ok);
  });

  sleep(0.3);

  // ── 6. Search entries (keyword) ────────────────────────────────────────
  group('Search Entries', () => {
    const keywords = ['family', 'travel', 'happy', 'morning', 'dinner', 'work'];
    const kw = keywords[Math.floor(Math.random() * keywords.length)];
    const res = http.get(
      `${SUPABASE_URL}/rest/v1/journal_entries?select=id,content,mood,entry_date&user_id=eq.${RESOLVED_USER_ID}&content=ilike.*${kw}*&order=entry_date.desc&limit=10`,
      { headers: readHeaders, tags: { name: 'GET_search' } }
    );
    searchDuration.add(res.timings.duration);
    const ok = check(res, {
      'search: status 200': (r) => r.status === 200,
    });
    if (!ok) errorCount.add(1);
    successRate.add(ok);
  });

  // Simulate real user think time (1-3 seconds between actions)
  sleep(Math.random() * 2 + 1);
}

// ─────────────────────────────────────────────────────────────────────────────
// Cleanup — runs once after all VUs finish
// ─────────────────────────────────────────────────────────────────────────────

export function teardown() {
  console.log('Cleaning up [LOAD_TEST] entries...');
  const res = http.del(
    `${SUPABASE_URL}/rest/v1/journal_entries?content=ilike.*LOAD_TEST*`,
    null,
    { headers }
  );
  console.log(`Cleanup status: ${res.status}`);
}
