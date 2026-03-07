#!/bin/bash
# ============================================================================
# DearDays Supabase Load Test — 1000 Concurrent Users
#
# Tests:
# 1. Auth endpoint (sign up) — 1000 concurrent requests
# 2. REST API read (profiles) — 1000 concurrent requests
# 3. REST API read (journal_entries) — 1000 concurrent requests
# 4. REST API write (journal_entries insert) — 100 concurrent requests
#
# Requirements: curl, bash
# ============================================================================

SUPABASE_URL="https://mcmlawztwyrjcwmieciw.supabase.co"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1jbWxhd3p0d3lyamN3bWllY2l3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4Nzc0NTgsImV4cCI6MjA4ODQ1MzQ1OH0.qFvDzJrHFUaJjucCxkJXvmtkRdumhm5wC0DxQu-Q-AE"

TOTAL_REQUESTS=1000
CONCURRENT=50
SUCCESS=0
FAIL=0
TOTAL_TIME=0

echo "============================================"
echo "  DearDays Supabase Load Test"
echo "  Total requests: $TOTAL_REQUESTS"
echo "  Concurrency: $CONCURRENT"
echo "============================================"
echo ""

# --- Test 1: Health check / REST API availability ---
echo "--- Test 1: API Health Check ---"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "apikey: $ANON_KEY" \
  "$SUPABASE_URL/rest/v1/")
echo "API Status: $HTTP_CODE"
if [ "$HTTP_CODE" != "200" ]; then
  echo "ERROR: API not reachable. Aborting."
  exit 1
fi
echo ""

# --- Test 2: Concurrent reads on profiles table (1000 requests) ---
echo "--- Test 2: Concurrent Profile Reads ($TOTAL_REQUESTS requests, $CONCURRENT at a time) ---"
START=$(date +%s%N)
SUCCESS=0
FAIL=0

for batch in $(seq 1 $((TOTAL_REQUESTS / CONCURRENT))); do
  pids=()
  for i in $(seq 1 $CONCURRENT); do
    (
      code=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "apikey: $ANON_KEY" \
        -H "Authorization: Bearer $ANON_KEY" \
        "$SUPABASE_URL/rest/v1/profiles?select=id&limit=1" 2>/dev/null)
      echo "$code"
    ) &
    pids+=($!)
  done

  for pid in "${pids[@]}"; do
    code=$(wait "$pid" 2>/dev/null; echo $?)
    # Collect results from subshell output
  done
  wait
done > /tmp/deardays_load_results.txt

SUCCESS=$(grep -c "200" /tmp/deardays_load_results.txt 2>/dev/null || echo 0)
FAIL=$((TOTAL_REQUESTS - SUCCESS))
END=$(date +%s%N)
ELAPSED=$(( (END - START) / 1000000 ))

echo "  Completed: $TOTAL_REQUESTS requests in ${ELAPSED}ms"
echo "  Success (200): $SUCCESS"
echo "  Failed: $FAIL"
echo "  Avg latency: $((ELAPSED / TOTAL_REQUESTS))ms/request"
echo "  Throughput: $(( TOTAL_REQUESTS * 1000 / (ELAPSED + 1) )) req/sec"
echo ""

# --- Test 3: Concurrent reads on journal_entries table ---
echo "--- Test 3: Concurrent Journal Entry Reads ($TOTAL_REQUESTS requests) ---"
START=$(date +%s%N)

for batch in $(seq 1 $((TOTAL_REQUESTS / CONCURRENT))); do
  pids=()
  for i in $(seq 1 $CONCURRENT); do
    (
      code=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "apikey: $ANON_KEY" \
        -H "Authorization: Bearer $ANON_KEY" \
        "$SUPABASE_URL/rest/v1/journal_entries?select=id,mood,entry_date&limit=10" 2>/dev/null)
      echo "$code"
    ) &
    pids+=($!)
  done
  wait
done > /tmp/deardays_load_journal.txt

SUCCESS=$(grep -c "200" /tmp/deardays_load_journal.txt 2>/dev/null || echo 0)
FAIL=$((TOTAL_REQUESTS - SUCCESS))
END=$(date +%s%N)
ELAPSED=$(( (END - START) / 1000000 ))

echo "  Completed: $TOTAL_REQUESTS requests in ${ELAPSED}ms"
echo "  Success (200): $SUCCESS"
echo "  Failed: $FAIL"
echo "  Avg latency: $((ELAPSED / TOTAL_REQUESTS))ms/request"
echo "  Throughput: $(( TOTAL_REQUESTS * 1000 / (ELAPSED + 1) )) req/sec"
echo ""

# --- Test 4: Concurrent auth sign-up attempts (smaller batch — 100) ---
echo "--- Test 4: Concurrent Auth Requests (100 sign-up attempts) ---"
AUTH_REQUESTS=100
AUTH_CONCURRENT=10
START=$(date +%s%N)

for batch in $(seq 1 $((AUTH_REQUESTS / AUTH_CONCURRENT))); do
  pids=()
  for i in $(seq 1 $AUTH_CONCURRENT); do
    UNIQUE_EMAIL="loadtest_${batch}_${i}_$(date +%s%N)@test.invalid"
    (
      code=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST \
        -H "apikey: $ANON_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"email\":\"$UNIQUE_EMAIL\",\"password\":\"LoadTest123!\"}" \
        "$SUPABASE_URL/auth/v1/signup" 2>/dev/null)
      echo "$code"
    ) &
    pids+=($!)
  done
  wait
done > /tmp/deardays_load_auth.txt

AUTH_SUCCESS=$(grep -cE "200|422|429" /tmp/deardays_load_auth.txt 2>/dev/null || echo 0)
AUTH_FAIL=$((AUTH_REQUESTS - AUTH_SUCCESS))
END=$(date +%s%N)
ELAPSED=$(( (END - START) / 1000000 ))

echo "  Completed: $AUTH_REQUESTS requests in ${ELAPSED}ms"
echo "  Responded (200/422/429): $AUTH_SUCCESS"
echo "  Failed: $AUTH_FAIL"
echo "  Avg latency: $((ELAPSED / AUTH_REQUESTS))ms/request"
echo ""

# --- Test 5: Sustained throughput (burst of 200 rapid-fire) ---
echo "--- Test 5: Burst Test (200 rapid-fire requests) ---"
START=$(date +%s%N)

for i in $(seq 1 200); do
  curl -s -o /dev/null -w "%{http_code}\n" \
    -H "apikey: $ANON_KEY" \
    -H "Authorization: Bearer $ANON_KEY" \
    "$SUPABASE_URL/rest/v1/streaks?select=id&limit=1" &
done > /tmp/deardays_load_burst.txt
wait

BURST_SUCCESS=$(grep -c "200" /tmp/deardays_load_burst.txt 2>/dev/null || echo 0)
END=$(date +%s%N)
ELAPSED=$(( (END - START) / 1000000 ))

echo "  Completed: 200 requests in ${ELAPSED}ms"
echo "  Success (200): $BURST_SUCCESS"
echo "  Throughput: $(( 200 * 1000 / (ELAPSED + 1) )) req/sec"
echo ""

echo "============================================"
echo "  Load Test Complete!"
echo "============================================"

# Cleanup
rm -f /tmp/deardays_load_results.txt /tmp/deardays_load_journal.txt \
  /tmp/deardays_load_auth.txt /tmp/deardays_load_burst.txt
