/**
 * DearDays — Auth Token Helper
 *
 * Signs in with the test account and prints the access token
 * for use with k6 load tests.
 *
 * Run:
 *   node auth_helper.js
 *
 * Then copy the token and run k6:
 *   k6 run -e ACCESS_TOKEN=<token> load_test.js
 */

const SUPABASE_URL = 'https://mcmlawztwyrjcwmieciw.supabase.co';
const ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1jbWxhd3p0d3lyamN3bWllY2l3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4Nzc0NTgsImV4cCI6MjA4ODQ1MzQ1OH0.qFvDzJrHFUaJjucCxkJXvmtkRdumhm5wC0DxQu-Q-AE';

// Test account credentials
const EMAIL = 'mlalit03@gmail.com';
const PASSWORD = '123456';

async function getToken() {
  try {
    const res = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
      method: 'POST',
      headers: {
        'apikey': ANON_KEY,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ email: EMAIL, password: PASSWORD }),
    });

    if (!res.ok) {
      const err = await res.text();
      console.error(`Auth failed (${res.status}): ${err}`);
      process.exit(1);
    }

    const data = await res.json();
    console.log('');
    console.log('═══════════════════════════════════════════════════');
    console.log('  DearDays Load Test — Auth Token');
    console.log('═══════════════════════════════════════════════════');
    console.log('');
    console.log(`  User:    ${data.user?.email}`);
    console.log(`  User ID: ${data.user?.id}`);
    console.log(`  Expires: ${new Date(data.expires_at * 1000).toISOString()}`);
    console.log('');
    console.log('  Run k6 with:');
    console.log('');
    console.log(`  k6 run -e ACCESS_TOKEN=${data.access_token} -e USER_ID=${data.user?.id} load_test.js`);
    console.log('');
    console.log('  Or for full 1000-user load:');
    console.log('');
    console.log(`  k6 run -e ACCESS_TOKEN=${data.access_token} -e USER_ID=${data.user?.id} --vus 1000 --duration 5m load_test.js`);
    console.log('');
    console.log('═══════════════════════════════════════════════════');
  } catch (e) {
    console.error('Failed to authenticate:', e.message);
    process.exit(1);
  }
}

getToken();
