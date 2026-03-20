/**
 * sentiment.ts — Zero-cost, zero-network sentiment analysis + NLP extraction.
 *
 * Replaces the AI call for three fields in ai-tag:
 *   - sentiment_score  (-1.0 → +1.0)  using AFINN-165 word list
 *   - people           (string[])      using relationship words + capitalised names heuristic
 *   - extracted_locations (string[])   using known place patterns
 *
 * Everything else (emotion, tags, activities, topics, embedding) still uses AI.
 *
 * Usage:
 *   import { scoreSentiment, extractPeople, extractLocations } from "../_shared/sentiment.ts";
 */

// ---------------------------------------------------------------------------
// AFINN-165 word list  (3 382 English words, scored –5 to +5)
// Subset trimmed to the ~500 most common in personal journal writing.
// Full list: https://github.com/fnielsen/afinn
// ---------------------------------------------------------------------------
const AFINN: Record<string, number> = {
  // Strong positive
  love: 3, loved: 3, loving: 3, wonderful: 4, amazing: 4, fantastic: 4,
  excellent: 3, outstanding: 4, brilliant: 3, superb: 3, delightful: 3,
  joyful: 3, joyous: 3, ecstatic: 4, thrilled: 3, elated: 3, overjoyed: 4,
  grateful: 3, thankful: 2, blessed: 3, lucky: 2, fortunate: 2,
  proud: 2, accomplished: 2, inspired: 2, motivated: 2, energetic: 2,
  happy: 3, happily: 3, happiness: 3, cheerful: 2, optimistic: 2,
  excited: 3, exciting: 3, enthusiasm: 3, enthusiastic: 3,
  beautiful: 3, perfect: 3, incredible: 3, magnificent: 3,
  fun: 2, enjoy: 2, enjoyed: 2, enjoying: 2, enjoyable: 2,
  good: 2, great: 3, nice: 2, lovely: 3, charming: 2, pleasant: 2,
  laugh: 2, laughed: 2, laughing: 2, smile: 2, smiling: 2, smiled: 2,
  celebrate: 2, celebration: 2, victory: 2, success: 2, succeed: 2,
  comfort: 1, comfortable: 2, cosy: 2, warm: 1, peaceful: 2, calm: 1,
  refresh: 1, refreshed: 2, relief: 2, relieved: 2, relax: 1, relaxed: 2,
  hope: 1, hopeful: 2, positive: 2, better: 1, best: 3, improve: 1,
  safe: 1, secure: 1, trust: 1, honest: 1, kind: 2, generous: 2,
  care: 1, caring: 2, support: 1, supported: 2, together: 1,
  close: 1, connected: 1, bond: 1, family: 1, friend: 1, friends: 1,

  // Mild positive
  ok: 1, okay: 1, fine: 1, alright: 1, decent: 1, fair: 1,
  interesting: 1, curious: 1, surprised: 1, unexpected: 1,
  progress: 1, forward: 1, easy: 1, simple: 1,

  // Mild negative
  tired: -1, weary: -2, bored: -1, boring: -2, dull: -1, blah: -1,
  worried: -2, worry: -2, anxious: -2, anxiety: -2, nervous: -2,
  awkward: -1, uncomfortable: -2, uneasy: -1, unsure: -1,
  miss: -1, missed: -1, missing: -1, lonely: -2, alone: -1,
  difficult: -1, hard: -1, struggle: -2, struggling: -2, tough: -1,
  confused: -1, lost: -1, overwhelmed: -2, stress: -2, stressed: -2,
  disappointed: -2, disappointing: -2, frustrating: -2, frustrated: -2,
  upset: -2, unhappy: -2, sad: -2, sadly: -2, sadness: -2,
  problem: -1, trouble: -1, wrong: -1, bad: -2, worst: -3,
  fear: -2, feared: -2, fearful: -2, scared: -2, afraid: -2,
  pain: -2, painful: -2, hurt: -2, suffer: -2, suffering: -2,
  fail: -2, failed: -2, failure: -2, mistake: -1, error: -1,
  sick: -2, ill: -2, unwell: -2, broken: -2,

  // Strong negative
  terrible: -3, horrible: -3, awful: -3, dreadful: -3,
  hate: -3, hated: -3, hating: -3, despise: -3, loathe: -3,
  angry: -3, anger: -3, furious: -3, rage: -3, livid: -3,
  devastated: -4, heartbroken: -3, grief: -3, grieve: -3, mourning: -3,
  depressed: -3, depression: -3, hopeless: -3, worthless: -3,
  crisis: -3, disaster: -3, catastrophe: -4, tragedy: -3, tragic: -3,
  abuse: -4, violence: -3, violent: -3, attack: -2, hit: -1,
  die: -3, died: -3, death: -3, dead: -3, loss: -2, lost: -1,
  cry: -1, cried: -1, crying: -1, tears: -1, sob: -2,
  regret: -2, guilt: -2, guilty: -2, ashamed: -2, shame: -2,

  // Intensifiers / negation handled via multiplier below
  very: 0, really: 0, so: 0, extremely: 0, absolutely: 0,
  not: 0, never: 0, no: 0, don: 0, didn: 0, doesn: 0, won: 0, wasn: 0,
};

/** Intensifier words that multiply the next scored word by 1.5 */
const INTENSIFIERS = new Set([
  "very", "really", "so", "extremely", "absolutely", "incredibly",
  "totally", "completely", "utterly", "deeply", "truly",
]);

/** Negation words that flip the sign of the next scored word */
const NEGATIONS = new Set([
  "not", "never", "no", "don't", "didn't", "doesn't", "won't",
  "wasn't", "isn't", "aren't", "can't", "couldn't", "shouldn't",
  "hardly", "barely", "scarcely",
]);

// ---------------------------------------------------------------------------
// Sentiment scoring
// ---------------------------------------------------------------------------

/**
 * Score text sentiment using AFINN word list.
 * Returns a value from -1.0 (very negative) to +1.0 (very positive).
 * Returns 0 if no scored words are found.
 */
export function scoreSentiment(text: string): number {
  const words = text.toLowerCase().match(/[\w']+/g) ?? [];
  let total = 0;
  let hits = 0;

  for (let i = 0; i < words.length; i++) {
    const word = words[i].replace(/['']/g, "'"); // normalise apostrophes
    const score = AFINN[word];
    if (score === undefined || score === 0) continue;

    let multiplier = 1;

    // Look back up to 2 words for negation or intensifier
    for (let j = Math.max(0, i - 2); j < i; j++) {
      const prev = words[j];
      if (NEGATIONS.has(prev)) { multiplier *= -1; break; }
      if (INTENSIFIERS.has(prev)) { multiplier *= 1.5; }
    }

    total += score * multiplier;
    hits++;
  }

  if (hits === 0) return 0;
  // Normalise: AFINN max per word is ±5, cap result at ±1
  const raw = total / (hits * 5);
  return Math.max(-1, Math.min(1, parseFloat(raw.toFixed(3))));
}

// ---------------------------------------------------------------------------
// People extraction
// ---------------------------------------------------------------------------

/** Relationship nouns commonly used in journal writing */
const RELATIONSHIP_WORDS = [
  "mum", "mom", "dad", "father", "mother", "sister", "brother",
  "grandma", "grandpa", "grandmother", "grandfather", "gran", "granny",
  "uncle", "aunt", "auntie", "cousin", "wife", "husband", "partner",
  "boyfriend", "girlfriend", "fiancé", "fiancée", "son", "daughter",
  "child", "children", "baby", "friend", "colleague", "boss", "teacher",
  "neighbour", "neighbor",
];

/**
 * Extract people from text.
 * Picks up:
 *   1. Relationship nouns (Mum, Dad, Sister …)
 *   2. Capitalised words following "my", "with", "called", "saw", "met",
 *      "visited", "talked to", "spoke to" — likely names
 */
export function extractPeople(text: string): string[] {
  const found = new Set<string>();

  // 1. Relationship words (case-insensitive, return in title case)
  const lower = text.toLowerCase();
  for (const rel of RELATIONSHIP_WORDS) {
    if (lower.includes(rel)) {
      found.add(rel.charAt(0).toUpperCase() + rel.slice(1));
    }
  }

  // 2. Capitalised names after trigger verbs / prepositions
  const namePattern =
    /(?:my|with|called?|saw|met|visited?|talked? to|spoke (?:to|with)|rang?|messaged?|emailed?)\s+([A-Z][a-z]{1,15})(?:\s+([A-Z][a-z]{1,15}))?/g;
  let match;
  while ((match = namePattern.exec(text)) !== null) {
    found.add(match[1]);
    if (match[2]) found.add(match[2]);
  }

  // 3. Any standalone capitalised word that isn't a sentence starter
  // (preceded by a lowercase word or punctuation other than . ! ?)
  const midSentenceCapital = /(?<=[a-z,;:]\s)([A-Z][a-z]{2,15})\b/g;
  while ((match = midSentenceCapital.exec(text)) !== null) {
    const word = match[1];
    // Exclude common non-name capitalised words
    if (!["The", "A", "An", "In", "On", "At", "For", "And", "But",
          "So", "To", "Of", "It", "He", "She", "We", "They",
          "Monday", "Tuesday", "Wednesday", "Thursday", "Friday",
          "Saturday", "Sunday", "January", "February", "March",
          "April", "May", "June", "July", "August", "September",
          "October", "November", "December"].includes(word)) {
      found.add(word);
    }
  }

  return [...found].slice(0, 10); // cap at 10
}

// ---------------------------------------------------------------------------
// Location extraction
// ---------------------------------------------------------------------------

/** Common location prepositions that precede a place name */
const LOCATION_PREPS =
  /(?:in|at|to|from|near|around|through|across|via|visiting?|travelled? to|flew? to|drove? to|went to|arrived? in|stayed? in|booked?|heading to)\s+([A-Z][a-zA-Z\s]{2,30?}?)(?=[,.\n!?]|$)/g;

/** Country / major city list for direct matching */
const KNOWN_PLACES = new Set([
  "london", "paris", "lisbon", "porto", "tokyo", "kyoto", "new york",
  "los angeles", "sydney", "melbourne", "berlin", "rome", "madrid",
  "barcelona", "amsterdam", "prague", "vienna", "dubai", "singapore",
  "hong kong", "beijing", "shanghai", "mumbai", "delhi", "bangkok",
  "bali", "nepal", "kathmandu", "spain", "portugal", "france", "italy",
  "germany", "japan", "australia", "canada", "india", "thailand",
  "ireland", "scotland", "wales", "england", "uk", "usa", "america",
]);

/**
 * Extract location names from text.
 * Uses preposition patterns + a known-places list.
 */
export function extractLocations(text: string): string[] {
  const found = new Set<string>();

  // 1. Known places (case-insensitive)
  const lowerText = text.toLowerCase();
  for (const place of KNOWN_PLACES) {
    if (lowerText.includes(place)) {
      // Title-case multi-word places
      found.add(place.replace(/\b\w/g, (c) => c.toUpperCase()));
    }
  }

  // 2. Capitalised words after location prepositions
  let match;
  while ((match = LOCATION_PREPS.exec(text)) !== null) {
    const candidate = match[1].trim();
    if (candidate.length >= 3 && candidate.length <= 30) {
      found.add(candidate);
    }
  }

  return [...found].slice(0, 8); // cap at 8
}
