/**
 * seed-test-data — one-shot test data seeder
 *
 * Creates 20 realistic journal entries (with typos/grammar mistakes) across
 * Family + Travel chapters over 2 weeks, polishes them via AI, generates
 * story paragraphs, creates thematic + chronological books, queues weekly
 * page generation for both weeks, runs the page generator, and returns
 * a full report showing every layer: raw → polished → story → page.
 *
 * DELETE THIS FUNCTION AFTER TESTING.
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
async function generate(prompt: string, systemPrompt: string, maxTokens: number): Promise<string> {
  const apiKey = Deno.env.get("OPENAI_API_KEY") ?? "";
  const res = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: { "Content-Type": "application/json", "Authorization": `Bearer ${apiKey}` },
    body: JSON.stringify({
      model: "gpt-4o-mini",
      messages: [{ role: "system", content: systemPrompt }, { role: "user", content: prompt }],
      temperature: 0.3,
      max_tokens: maxTokens,
    }),
  });
  if (!res.ok) throw new Error(`OpenAI error ${res.status}: ${await res.text()}`);
  const data = await res.json();
  return data.choices?.[0]?.message?.content ?? "";
}

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
);

const USER_ID    = "e14ee4f6-b38d-4507-a625-9e77c1c162e2";
const CH_FAMILY  = "57d26d66-89b9-472a-a46a-966b9ced62a0";
const CH_TRAVEL  = "fc6fd605-a48d-44d1-b749-d8ad70385d38";
const WEEK1      = "2026-03-02"; // Monday
const WEEK2      = "2026-03-09"; // Monday

// ---------------------------------------------------------------------------
// 20 raw entries with realistic typos + grammar mistakes
// 5 Family × 2 weeks, 5 Travel × 2 weeks
// ---------------------------------------------------------------------------

const RAW_ENTRIES = [
  // ── Family – Week 1 ──────────────────────────────────────────────────────
  {
    chapter_id: CH_FAMILY, entry_date: "2026-03-02",
    content: "today went to see mum and dad after work. dad was in the garden fixing the old fence agian he always doing somthing with that fence. mum made her lamb stew the one she only cooks in winter. we sat arround the kitchen table for ages just talking about nothing and evrything. i realised i havent done this in months feels good to be home",
  },
  {
    chapter_id: CH_FAMILY, entry_date: "2026-03-04",
    content: "my sister sara called me out of nowere she was crying bcause her boyfriend broke up with her. i droped everything and went to her appartment. we ordered pizza and wached old movies all nite. she kept saying she should of seen it comming. i just listend mostly. its wierd how you can sit with someone for hours and the most importent thing is just being there",
  },
  {
    chapter_id: CH_FAMILY, entry_date: "2026-03-05",
    content: "dad rang me this morning just to chat which he almost never does. he told me about a bird that builded a nest in the garden. he was so exited about it like a little kid. we talked for maybe 20 mins which is long for dad. he asked how works going and i told him about the new project. he said proud of you son. made my whole day that",
  },
  {
    chapter_id: CH_FAMILY, entry_date: "2026-03-07",
    content: "family dinner at mums tonight. grandma came too she is 84 now but stil sharp as ever. she told storys about the old neighborhood that we all heard hundred times but nobody mind. my cousin jake brang his new girlfriend for first time she seemed nervus but everyone was nice. after dinner we played cards grandma won like she always does she never lets us win",
  },
  {
    chapter_id: CH_FAMILY, entry_date: "2026-03-08",
    content: "helped dad move some furnitur in the garage. we found a box of old photos from when me and sara were kids. dad got quite looking at them. there was one of us at the beach mum looked so young. we stood there for ages just going through the box not saying much. its funny how a photograph can bring it all back so clear",
  },
  // ── Family – Week 2 ──────────────────────────────────────────────────────
  {
    chapter_id: CH_FAMILY, entry_date: "2026-03-09",
    content: "mum rang to say grandma wasnt feeling well nothing serius just a cold but she was worried. i took the afternoon of work and went over. grandma was actully in good spirits watching her sopa operas and complaning about the plot. mum was fusing over her making soups and teas. it was nice to just sit around and look after someone for a change",
  },
  {
    chapter_id: CH_FAMILY, entry_date: "2026-03-11",
    content: "sara came over for dinner i cooked pasta badly but she pretended it was good. she seems better after the breakup. she got a new haircut and was more like herself again. we talked about childhood memories and ended up laughing til we cryed about the time we got lost at the fair when we were kids. mum was absoloutly furius that day but its funny now",
  },
  {
    chapter_id: CH_FAMILY, entry_date: "2026-03-12",
    content: "video call with uncle ravi in canada. havent spoke to him properly in like two years. he looks older but the same somehow. he was asking about everyone sending love to grandma. his kids are teenagers now which is mad they were tiny last time i seen them in person. he said we should plan a visit next year. we say that every year but mabe this time we mean it",
  },
  {
    chapter_id: CH_FAMILY, entry_date: "2026-03-14",
    content: "took grandma to her doctors appointment. she was pretending she didnt need help but held my arm the whole time. the docter said she was fine just needs rest. on the way back she told me about when she first came to this country with nothing but one suitcase. ive heard bits of it before but never the full story. i wish id been listening more carefully all these years",
  },
  {
    chapter_id: CH_FAMILY, entry_date: "2026-03-15",
    content: "whole family came for sundy lunch unexpectedly mum loves these suprises. the house was loud and full and dad was at the barbeque even tho it was still cold outside. sara brought wine jake brought his girlfriend again shes more relaxed now. after eating we all sat in the garden wrapped in blankets talking. moments like these remind me what actually matters in life",
  },

  // ── Travel – Week 1 ──────────────────────────────────────────────────────
  {
    chapter_id: CH_TRAVEL, entry_date: "2026-03-02",
    content: "booked my trip to lisbon today leaving in may so exited. ive been wanting to go for years. spent the evning reading about the neighbourhoods and resturaunts making a list on my phone. my collegue who went last year says the pasteis de nata in belem are life changing. already planning which ones to try first. travel planning is half the fun honestly",
  },
  {
    chapter_id: CH_TRAVEL, entry_date: "2026-03-03",
    content: "found an amazing small hotel in alfama district in lisbon booked it immediatly before i could change my mind. it has a rooftop terrace with views of the river. the reviews say the owner is lovely and makes home made breakfast. looking at the photos made me so restless sitting in my flat wishing i was already there. four weeks feels like forever away",
  },
  {
    chapter_id: CH_TRAVEL, entry_date: "2026-03-05",
    content: "met james for cofee he just got back from japan and wouldnt stop talking about it. he went to kyoto during chery blossom season and the photos he showed me were incredibl. made me add japan to my list even tho its already to long. he said the food was absolutly unreal he spent half his budjet on ramen alone. i love hearing peoples travel storys it rekindles that feeling",
  },
  {
    chapter_id: CH_TRAVEL, entry_date: "2026-03-06",
    content: "watched a documentry about the camino de santiago tonight the pilgrimage walk across spain. something about it realy got to me. hundreds of different people from all over the world walking the same path for different reasons. some for religion some for grief some just to think. i dont know why but i want to do it. not this year but someday. its the kind of journey that changes a person",
  },
  {
    chapter_id: CH_TRAVEL, entry_date: "2026-03-08",
    content: "reading a book about slow travel the idea of spending a month in one place instead of rushing between citys. it makes alot of sense to me. i think about my trips and the moments i remeber most are never the tourist sites. its always the random cafe where i spent three hours reading or the conversation with a stranger on a train. maybe i should plan trips differntly from now on",
  },
  // ── Travel – Week 2 ──────────────────────────────────────────────────────
  {
    chapter_id: CH_TRAVEL, entry_date: "2026-03-10",
    content: "picked up my lisbon guidebok from the bookshop. i know evreything is on the phone now but there is something about a real book for this. started making notes in the margins circling places i want to see. the fado music section made me want to go to a live show. apparently the best ones are in small private houses not the tourist resturaunts. i will try to find one",
  },
  {
    chapter_id: CH_TRAVEL, entry_date: "2026-03-11",
    content: "my old frend leila who lives in porto messaged asking if i was free before lisbon to visit. hadnt thought of it but why not. changed my flights to stop in porto for two nites on the way. leila showed me the area on google maps the tiles on all the old buildings look incredible. unexpected plans are the best plans i think. trip is getting beter every day",
  },
  {
    chapter_id: CH_TRAVEL, entry_date: "2026-03-13",
    content: "went to a travel talk at the local libary about trekking in nepal. the speaker had done everest base camp three times she was fasinating. her storis about the sherpas and the monastries along the way and the way the altitude changes how you think. i asked her after about going alone as a woman and she said it was the best decison she ever made. i want that feeling",
  },
  {
    chapter_id: CH_TRAVEL, entry_date: "2026-03-14",
    content: "sorted out my travel insurence and packed a practis bag to see what fits. i always overpack so trying a new system this time everything folded flat in packing cubes. managed to fit 10 days worth in a carry on which is a personal record. lisbon is warm in may so mostly ligth stuff. i feel like a diferent person when im preparing to go somwhere new. more alive somehow",
  },
  {
    chapter_id: CH_TRAVEL, entry_date: "2026-03-15",
    content: "three weeks to lisbon. could not concentrate at work today kept daydreaming about waking up in that alfama hotel eating breakfast on the rooftop watching the river. james sent me a list of his favurite spots and said i would fall in love with the city. i beleve him. sometimes anticipation is its own kind of travel the mind goes ahead and explores before the body ever arrives",
  },
];

// ---------------------------------------------------------------------------
// AI helpers
// ---------------------------------------------------------------------------

async function polishEntry(raw: string): Promise<string> {
  const system = `You are a thoughtful editor. Fix spelling, grammar and punctuation in the user's journal entry while keeping their natural voice, word choices and emotional tone completely intact. Return ONLY the corrected text with no commentary.`;
  return generate(raw, system, 600);
}

async function generateStoryParagraph(polished: string): Promise<string> {
  const system =
    `You are an editor helping someone write their personal memoir. ` +
    `Retell this journal entry as a short story paragraph (3–5 sentences) in the writer's own voice.\n\n` +
    `RULES:\n` +
    `- Always write in FIRST PERSON ("I", "me", "my", "we"). Never "he", "she", or "they" for the writer.\n` +
    `- NEVER infer or mention the writer's gender. Never use words like "girls", "boys", "men", "women" to describe the writer or their group.\n` +
    `- Use simple, everyday language — Grade 6 reading level. No poetic or literary phrases.\n` +
    `- Do NOT add facts, emotions, or details not stated by the writer.\n` +
    `- Do NOT add metaphors (e.g. "guardian of memories", "tapestry of connection", "portal to the past").\n` +
    `- Do NOT add philosophical conclusions or endings (e.g. "reminding me that home is more than a place", "a reminder that...", "a testament to...", "anchored me").\n` +
    `- Do NOT use these words: wanderlust, rekindled, irresistible, serendipitous, resonated, "igniting a spark", "long been dormant", "strip away the superficial", "tapestry", "guardian", "portal".\n` +
    `- The last sentence MUST be based on something the writer actually said — do NOT invent a thematic conclusion.\n` +
    `- Only rephrase what the writer actually said, using natural connectors ("then", "after that", "so").\n` +
    `- Write in past tense.\n` +
    `- Return ONLY the paragraph. No title, no commentary.`;
  return generate(polished, system, 300);
}

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------

Deno.serve(async (_req: Request) => {
  const report: Record<string, unknown> = { steps: [] };
  const steps = report.steps as unknown[];

  try {
    // ── 1. Clear previous test data ─────────────────────────────────────────
    await supabase.from("generation_queue")
      .delete().eq("user_id", USER_ID)
      .in("week_start", [WEEK1, WEEK2]);
    await supabase.from("pages")
      .delete().eq("user_id", USER_ID)
      .in("week_start", [WEEK1, WEEK2]);
    await supabase.from("story_context")
      .delete().eq("user_id", USER_ID)
      .in("chapter_id", [CH_FAMILY, CH_TRAVEL]);
    await supabase.from("books")
      .delete().eq("user_id", USER_ID)
      .in("title", ["My Memoir", "Family & Travel Thematic"]);
    await supabase.from("journal_entries")
      .delete().eq("user_id", USER_ID)
      .gte("entry_date", WEEK1).lte("entry_date", "2026-03-15");

    steps.push({ step: "cleanup", ok: true });

    // ── 2. Insert raw entries ────────────────────────────────────────────────
    const rawRows = RAW_ENTRIES.map(e => ({
      user_id: USER_ID,
      chapter_id: e.chapter_id,
      entry_date: e.entry_date,
      content: e.content,
      mood: "good",
    }));
    const { data: inserted, error: insertErr } = await supabase
      .from("journal_entries")
      .insert(rawRows)
      .select("id, chapter_id, entry_date, content");
    if (insertErr) throw new Error(`insert entries: ${insertErr.message}`);
    steps.push({ step: "insert_raw", count: inserted!.length });

    // ── 3. Polish + story paragraph in parallel batches of 5 ────────────────
    const enriched: Array<{
      id: string; chapter_id: string; entry_date: string;
      raw: string; polished: string; story: string;
    }> = [];

    // Parallel — paid key has no rate limit concern
    const results = await Promise.all(inserted!.map(async (e) => {
      const polished = await polishEntry(e.content);
      const story    = await generateStoryParagraph(polished);
      await supabase.from("journal_entries").update({
        raw_content: polished,
        polished_content: story,
      }).eq("id", e.id);
      return { id: e.id, chapter_id: e.chapter_id, entry_date: e.entry_date,
               raw: e.content, polished, story };
    }));
    enriched.push(...results);
    steps.push({ step: "ai_enrich", count: enriched.length });

    // ── 4. Create books ──────────────────────────────────────────────────────
    const { data: thematicBook, error: e1 } = await supabase
      .from("books")
      .insert({ user_id: USER_ID, title: "Family & Travel Thematic",
                writing_style: "memoir", creation_approach: "thematic",
                start_date: WEEK1 })
      .select("id").single();
    if (e1) throw new Error(`create thematic book: ${e1.message}`);

    const { data: chronoBook, error: e2 } = await supabase
      .from("books")
      .insert({ user_id: USER_ID, title: "My Memoir",
                writing_style: "memoir", creation_approach: "chronological",
                start_date: WEEK1 })
      .select("id").single();
    if (e2) throw new Error(`create chrono book: ${e2.message}`);

    steps.push({ step: "create_books",
                 thematic_book_id: thematicBook!.id,
                 chrono_book_id:   chronoBook!.id });

    // ── 5. Link chapters to thematic book ────────────────────────────────────
    await supabase.from("chapters")
      .update({ book_id: thematicBook!.id })
      .in("id", [CH_FAMILY, CH_TRAVEL]);

    // Create a single auto-chapter for the chronological book
    // Use a high chapter_number to avoid conflict with existing chapters
    const { data: maxChNum } = await supabase
      .from("chapters")
      .select("chapter_number")
      .eq("user_id", USER_ID)
      .order("chapter_number", { ascending: false })
      .limit(1)
      .maybeSingle();
    const nextChNum = ((maxChNum?.chapter_number as number) ?? 0) + 1;

    const { data: chronoChapter, error: e3 } = await supabase
      .from("chapters")
      .insert({ user_id: USER_ID, title: "My Story",
                book_id: chronoBook!.id, chapter_number: nextChNum,
                start_date: WEEK1 })
      .select("id").single();
    if (e3) throw new Error(`create chrono chapter: ${e3.message}`);

    // Tag ALL 20 entries as also belonging to the chrono chapter
    // (for the chronological book, chapter_id on entries isn't used — the
    //  weekly job sweeps all entries by user — but we need the chapter to exist)
    steps.push({ step: "link_chapters", chrono_chapter_id: chronoChapter!.id });

    // ── 6. Enqueue all 4 combinations (family wk1, family wk2, travel wk1, travel wk2)
    //       + 2 chrono combinations (wk1, wk2) ──────────────────────────────

    const familyWk1Ids = enriched.filter(e => e.chapter_id === CH_FAMILY && e.entry_date <= "2026-03-08").map(e => e.id);
    const familyWk2Ids = enriched.filter(e => e.chapter_id === CH_FAMILY && e.entry_date >= "2026-03-09").map(e => e.id);
    const travelWk1Ids = enriched.filter(e => e.chapter_id === CH_TRAVEL && e.entry_date <= "2026-03-08").map(e => e.id);
    const travelWk2Ids = enriched.filter(e => e.chapter_id === CH_TRAVEL && e.entry_date >= "2026-03-09").map(e => e.id);
    const allWk1Ids    = enriched.filter(e => e.entry_date <= "2026-03-08").map(e => e.id);
    const allWk2Ids    = enriched.filter(e => e.entry_date >= "2026-03-09").map(e => e.id);

    const wk1Rows = [
      { user_id: USER_ID, chapter_id: CH_FAMILY,         book_id: thematicBook!.id, week_start: WEEK1, memory_ids: familyWk1Ids },
      { user_id: USER_ID, chapter_id: CH_TRAVEL,         book_id: thematicBook!.id, week_start: WEEK1, memory_ids: travelWk1Ids },
      { user_id: USER_ID, chapter_id: chronoChapter!.id, book_id: chronoBook!.id,   week_start: WEEK1, memory_ids: allWk1Ids },
    ];
    const wk2Rows = [
      { user_id: USER_ID, chapter_id: CH_FAMILY,         book_id: thematicBook!.id, week_start: WEEK2, memory_ids: familyWk2Ids },
      { user_id: USER_ID, chapter_id: CH_TRAVEL,         book_id: thematicBook!.id, week_start: WEEK2, memory_ids: travelWk2Ids },
      { user_id: USER_ID, chapter_id: chronoChapter!.id, book_id: chronoBook!.id,   week_start: WEEK2, memory_ids: allWk2Ids },
    ];

    const fnUrl = `${Deno.env.get("SUPABASE_URL")}/functions/v1/ai-weekly-page`;
    const fnHeaders = {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}`,
    };

    // Enqueue + process Week 1 first so story_context is written before Week 2 reads it
    const { error: qErr1 } = await supabase.from("generation_queue").insert(wk1Rows);
    if (qErr1) throw new Error(`queue wk1: ${qErr1.message}`);
    steps.push({ step: "enqueue_wk1", rows: wk1Rows.length });

    const res1 = await fetch(fnUrl, { method: "POST", headers: fnHeaders, body: JSON.stringify({ limit: 5 }) });
    const result1 = await res1.json();
    steps.push({ step: "page_generation_wk1", result: result1 });

    // Now enqueue + process Week 2 (story_context from Week 1 is now available)
    const { error: qErr2 } = await supabase.from("generation_queue").insert(wk2Rows);
    if (qErr2) throw new Error(`queue wk2: ${qErr2.message}`);
    steps.push({ step: "enqueue_wk2", rows: wk2Rows.length });

    const res2 = await fetch(fnUrl, { method: "POST", headers: fnHeaders, body: JSON.stringify({ limit: 5 }) });
    const fnResult = await res2.json();
    steps.push({ step: "page_generation_wk2", result: fnResult });

    steps.push({ step: "enqueue", rows: wk1Rows.length + wk2Rows.length });

    // ── 8. Fetch all generated pages ─────────────────────────────────────────
    const { data: pages } = await supabase
      .from("pages")
      .select("id, chapter_id, book_id, week_start, page_number, word_count, content")
      .eq("user_id", USER_ID)
      .in("week_start", [WEEK1, WEEK2])
      .order("week_start").order("chapter_id").order("page_number");

    // ── 9. Build full report ──────────────────────────────────────────────────
    const familyEntries = enriched
      .filter(e => e.chapter_id === CH_FAMILY)
      .sort((a, b) => a.entry_date.localeCompare(b.entry_date))
      .map(e => ({ date: e.entry_date, raw_conversation: e.raw, polished: e.polished, story_paragraph: e.story }));
    const travelEntries = enriched
      .filter(e => e.chapter_id === CH_TRAVEL)
      .sort((a, b) => a.entry_date.localeCompare(b.entry_date))
      .map(e => ({ date: e.entry_date, raw_conversation: e.raw, polished: e.polished, story_paragraph: e.story }));

    return new Response(JSON.stringify({
      ok: true,
      steps,
      entries: {
        family: familyEntries,
        travel: travelEntries,
      },
      pages: {
        family_thematic: pages?.filter(p => p.chapter_id === CH_FAMILY),
        travel_thematic: pages?.filter(p => p.chapter_id === CH_TRAVEL),
        chronological:   pages?.filter(p => p.chapter_id === chronoChapter!.id),
      },
    }, null, 2), {
      headers: { "Content-Type": "application/json" },
    });

  } catch (err) {
    return new Response(JSON.stringify({
      ok: false,
      error: err instanceof Error ? err.message : String(err),
      steps,
    }, null, 2), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
