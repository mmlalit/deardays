import requests, json, uuid, time

SUPABASE_URL = "https://mcmlawztwyrjcwmieciw.supabase.co"
ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1jbWxhd3p0d3lyamN3bWllY2l3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4Nzc0NTgsImV4cCI6MjA4ODQ1MzQ1OH0.qFvDzJrHFUaJjucCxkJXvmtkRdumhm5wC0DxQu-Q-AE"
USER_ID = "e14ee4f6-b38d-4507-a625-9e77c1c162e2"
EMAIL = "mlalit03@gmail.com"
PASSWORD = "123456"
REST = f"{SUPABASE_URL}/rest/v1"
FN_URL = f"{SUPABASE_URL}/functions/v1"
STORAGE = f"{SUPABASE_URL}/storage/v1"

# Step 1: Authenticate
print("Step 1: Authenticating...")
r = requests.post(
    f"{SUPABASE_URL}/auth/v1/token?grant_type=password",
    headers={"apikey": ANON_KEY, "Content-Type": "application/json"},
    json={"email": EMAIL, "password": PASSWORD},
)
if r.status_code != 200:
    print(f"  AUTH FAILED: {r.status_code} {r.text[:200]}")
    exit(1)
TOKEN = r.json()["access_token"]
print(f"  OK: Authenticated")

H = {"apikey": ANON_KEY, "Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"}

# Step 2: List storage objects to get uploaded image paths
print("\nStep 2: Listing uploaded images in storage...")
r = requests.post(
    f"{STORAGE}/object/list/entry-media",
    headers=H,
    json={"prefix": f"{USER_ID}/photos/", "limit": 100, "offset": 0},
)
storage_paths = []
if r.status_code == 200:
    objects = r.json()
    for obj in objects:
        name = obj.get("name", "")
        if name:
            full_path = f"{USER_ID}/photos/{name}"
            storage_paths.append(full_path)
    print(f"  Found {len(storage_paths)} images")
    for p in storage_paths:
        print(f"    {p}")
else:
    print(f"  FAIL listing storage: {r.status_code} {r.text[:200]}")

# Step 3: Truncate existing data (safety re-run)
print("\nStep 3: Clearing existing data for user...")
for table in ["entry_media", "journal_entries"]:
    r = requests.delete(
        f"{REST}/{table}?user_id=eq.{USER_ID}",
        headers=H,
    )
    print(f"  {table}: {r.status_code}")

# Step 4: Insert 10 journal entries
entries_data = [
    {
        "date": "2026-03-05", "mood": "great", "time": "08:15",
        "content": "Started the morning with a perfect cup of coffee. The aroma filled the whole apartment and I sat by the window watching the city wake up. Decided to go for a long walk in the park before work - the trees are starting to bud and there was something so peaceful about the stillness of early morning. Feeling very grateful today.",
        "raw": "Had my morning coffee, went for a walk in the park. Trees are budding. Feeling great and grateful.",
        "img": 0, "location": "Home, Mumbai"
    },
    {
        "date": "2026-03-07", "mood": "good", "time": "19:30",
        "content": "Big family dinner tonight. Mom made her special dal makhani and we all sat around the table for the first time in months. My sister brought her new boyfriend - he seems genuinely nice. We laughed about old family stories until 11pm. These are the moments I want to remember forever.",
        "raw": "Family dinner tonight. Mom made dal makhani. Sister brought her boyfriend. Lots of laughter.",
        "img": 1, "location": "Family Home, Pune"
    },
    {
        "date": "2026-03-09", "mood": "okay", "time": "14:00",
        "content": "Spent the afternoon in the park just reading and thinking. Work has been hectic lately and I needed this reset. The weather was overcast but somehow that made it more peaceful. I read 60 pages of my book and just let my mind wander. Sometimes doing nothing is exactly what you need.",
        "raw": "Spent afternoon in park, reading. Work stress, needed a break. Overcast weather, peaceful.",
        "img": 2, "location": "Cubbon Park, Bangalore"
    },
    {
        "date": "2026-03-10", "mood": "low", "time": "22:00",
        "content": "Tough day at work. The project deadline got moved up by two weeks and the whole team is stressed. I stayed late trying to reorganise the plan but I am still not sure it is doable. Got home exhausted, did not even eat properly. I need to remind myself that this will pass and that I have handled hard weeks before.",
        "raw": "Difficult day. Project deadline moved up. Team stressed. Stayed late. Got home exhausted.",
        "img": 3, "location": "Office, Bangalore"
    },
    {
        "date": "2026-03-12", "mood": "great", "time": "18:45",
        "content": "Caught the most incredible sunset from the rooftop today. The sky turned from deep orange to vivid pink and I just stood there for 20 minutes completely mesmerised. Called my best friend and we talked for an hour about life and dreams. He is thinking about starting his own business. I feel so lucky to have people like him in my life.",
        "raw": "Amazing sunset from rooftop. Called my best friend. He is thinking about starting a business. Feeling lucky.",
        "img": 4, "location": "Rooftop, Bangalore"
    },
    {
        "date": "2026-03-13", "mood": "good", "time": "21:15",
        "content": "Finished the novel I have been reading for three weeks. The ending was bittersweet - the kind that stays with you. Wrote three pages in my notebook about what it meant to me. Reading reminds me why I want to write more. Made a resolution to read at least one book a month this year.",
        "raw": "Finished my novel tonight. Bittersweet ending. Wrote about it in notebook. Want to read more.",
        "img": 5, "location": "Home, Bangalore"
    },
    {
        "date": "2026-03-14", "mood": "great", "time": "20:00",
        "content": "Met up with college friends for the first time since the new year. We went to our old haunt in Indiranagar and the conversation never stopped. We talked about where we thought we would be at this age versus where we actually are. Everyone is on such different but interesting paths. Left feeling energised and reminded of who I used to be.",
        "raw": "Met college friends in Indiranagar. Long conversations. Everyone on different paths. Feeling energised.",
        "img": 6, "location": "Indiranagar, Bangalore"
    },
    {
        "date": "2026-03-15", "mood": "good", "time": "07:30",
        "content": "Finally got back to the gym after two weeks off. Everything hurt but in the best possible way. Completed my full routine - squats, bench, rows. The gym was quiet at 7am and I had the whole floor to myself. Put on my playlist and just focused on each set. Physical discomfort that you choose is so different from the kind that happens to you.",
        "raw": "Back at gym after 2 weeks. Full workout completed. Quiet morning. Chose to be here.",
        "img": 7, "location": "Gym, Bangalore"
    },
    {
        "date": "2026-03-17", "mood": "good", "time": "23:00",
        "content": "Walked through the city after a late dinner and ended up near MG Road at night. The lights reflecting on the wet pavement from earlier rain, the sounds of traffic thinning out, street food vendors packing up. There is something uniquely alive about a city at night. Felt like I was seeing Bangalore with fresh eyes.",
        "raw": "Late night walk through MG Road. City at night. Wet pavement reflections. Street food vendors.",
        "img": 8, "location": "MG Road, Bangalore"
    },
    {
        "date": "2026-03-19", "mood": "great", "time": "11:00",
        "content": "The work crisis is finally behind us. We delivered the project and the client was genuinely impressed. My manager gave the whole team a public shoutout in the all-hands. Treated myself to a long lunch and just sat with the satisfaction of having done something hard and coming through. Two weeks ago I was not sure we could do it. We did.",
        "raw": "Project delivered! Client impressed. Manager gave shoutout. Treated myself to a long lunch. Proud of the team.",
        "img": 3, "location": "Office, Bangalore"
    },
]

print(f"\nStep 4: Inserting {len(entries_data)} journal entries...")
entry_ids = []
for i, e in enumerate(entries_data):
    entry_id = str(uuid.uuid4())
    has_photo = e["img"] < len(storage_paths)
    payload = {
        "id": entry_id,
        "user_id": USER_ID,
        "content": e["content"],
        "raw_content": e["raw"],
        "mood": e["mood"],
        "entry_date": e["date"],
        "entry_time": e["time"],
        "location_name": e["location"],
        "has_photo": has_photo,
        "has_voice": False,
        "is_ai_polished": False,
        "word_count": len(e["content"].split()),
    }
    r = requests.post(f"{REST}/journal_entries", headers=H, json=payload)
    if r.status_code == 201:
        entry_ids.append((entry_id, e))
        print(f"  OK: Entry {i+1} - {e['date']} ({e['mood']})")
    else:
        print(f"  FAIL entry {i+1}: {r.status_code} {r.text[:120]}")

print(f"\nStep 4b: Attaching images to entries...")
for idx, (entry_id, e) in enumerate(entry_ids):
    img_idx = e["img"]
    if img_idx < len(storage_paths):
        sp = storage_paths[img_idx]
        media_payload = {
            "id": str(uuid.uuid4()),
            "entry_id": entry_id,
            "user_id": USER_ID,
            "media_type": "photo",
            "storage_path": sp,
            "sort_order": 0,
        }
        r = requests.post(f"{REST}/entry_media", headers=H, json=media_payload)
        status = "OK" if r.status_code == 201 else f"FAIL {r.status_code} {r.text[:60]}"
        print(f"  {status}: Image for entry {idx+1} ({e['date']})")
    else:
        print(f"  SKIP: No image for entry {idx+1} (img_idx={img_idx}, have {len(storage_paths)} images)")

print(f"\nStep 5: Calling ai-polish for each entry...")
polished = 0
for entry_id, e in entry_ids:
    try:
        r = requests.post(
            f"{FN_URL}/ai-polish",
            headers=H,
            json={"text": e["content"], "style": "memoir"},
            timeout=30,
        )
        if r.status_code == 200:
            polished += 1
            resp = r.json()
            polished_text = resp.get("text", resp.get("polished", resp.get("content", "")))
            chars = len(polished_text)
            # Mark entry as polished in DB
            if polished_text:
                requests.patch(
                    f"{REST}/journal_entries?id=eq.{entry_id}",
                    headers=H,
                    json={"polished_content": polished_text, "is_ai_polished": True},
                )
            print(f"  OK: Polished {e['date']} - {chars} chars")
        else:
            print(f"  FAIL polish {e['date']}: {r.status_code} {r.text[:120]}")
    except Exception as ex:
        print(f"  ERROR polish {e['date']}: {ex}")
    time.sleep(0.8)

print(f"\nStep 6: Calling ai-tag for each entry...")
tagged = 0
for entry_id, e in entry_ids:
    try:
        r = requests.post(
            f"{FN_URL}/ai-tag",
            headers=H,
            json={"entryId": entry_id, "content": e["content"]},
            timeout=20,
        )
        if r.status_code == 200:
            tagged += 1
            print(f"  OK: Tagged {e['date']}")
        else:
            print(f"  FAIL tag {e['date']}: {r.status_code} {r.text[:80]}")
    except Exception as ex:
        print(f"  ERROR tag {e['date']}: {ex}")
    time.sleep(0.4)

print(f"\nStep 7: Weekly story generation...")
for week_offset in [-1, 0]:
    try:
        r = requests.post(
            f"{FN_URL}/ai-weekly-page",
            headers=H,
            json={"userId": USER_ID, "weekOffset": week_offset},
            timeout=60,
        )
        label = "Current week" if week_offset == 0 else "Previous week"
        print(f"  {label}: {r.status_code} {r.text[:200]}")
    except Exception as ex:
        print(f"  ERROR weekly story: {ex}")
    time.sleep(2)

print(f"\n=== SUMMARY ===")
print(f"  Entries inserted : {len(entry_ids)}/10")
print(f"  Images attached  : {sum(1 for _, e in entry_ids if e['img'] < len(storage_paths))}/{len(entry_ids)}")
print(f"  Entries polished : {polished}/{len(entry_ids)}")
print(f"  Entries tagged   : {tagged}/{len(entry_ids)}")
print(f"\nDone! Launch app to verify.")
