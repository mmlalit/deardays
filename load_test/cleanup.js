/**
 * DearDays — Load Test Cleanup
 *
 * Deletes all journal entries created by load tests (tagged [LOAD_TEST]).
 * Run after a load test if the teardown didn't complete.
 *
 * Run:
 *   node cleanup.js
 */

const SUPABASE_URL = 'https://mcmlawztwyrjcwmieciw.supabase.co';
const ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1jbWxhd3p0d3lyamN3bWllY2l3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4Nzc0NTgsImV4cCI6MjA4ODQ1MzQ1OH0.qFvDzJrHFUaJjucCxkJXvmtkRdumhm5wC0DxQu-Q-AE';
const EMAIL = 'mlalit03@gmail.com';
const PASSWORD = '123456';

async function cleanup() {
  // 1. Sign in
  console.log('Signing in...');
  const authRes = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: { 'apikey': ANON_KEY, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: EMAIL, password: PASSWORD }),
  });

  if (!authRes.ok) {
    console.error(`Auth failed: ${await authRes.text()}`);
    process.exit(1);
  }

  const { access_token } = await authRes.json();
  const headers = {
    'apikey': ANON_KEY,
    'Authorization': `Bearer ${access_token}`,
    'Prefer': 'return=representation',
  };

  // 2. Count load test entries
  console.log('Counting [LOAD_TEST] entries...');
  const countRes = await fetch(
    `${SUPABASE_URL}/rest/v1/journal_entries?select=id&content=ilike.*LOAD_TEST*`,
    { headers }
  );
  const entries = await countRes.json();
  console.log(`Found ${entries.length} load test entries.`);

  if (entries.length === 0) {
    console.log('Nothing to clean up.');
    return;
  }

  // 3. Delete in batches of 100
  const batchSize = 100;
  let deleted = 0;

  for (let i = 0; i < entries.length; i += batchSize) {
    const batch = entries.slice(i, i + batchSize);
    const ids = batch.map(e => e.id);

    for (const id of ids) {
      await fetch(
        `${SUPABASE_URL}/rest/v1/journal_entries?id=eq.${id}`,
        { method: 'DELETE', headers }
      );
      deleted++;
    }

    console.log(`  Deleted ${deleted} / ${entries.length}`);
  }

  console.log(`\nCleanup complete. Deleted ${deleted} entries.`);
}

cleanup().catch(console.error);
