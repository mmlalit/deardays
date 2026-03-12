// Restrict CORS to your app's web domain. Native mobile apps don't send
// an Origin header so they are unaffected. Override via env var if needed.
const ALLOWED_ORIGIN =
  Deno.env.get("CORS_ALLOWED_ORIGIN") ?? "https://app.deardays.io";

export const corsHeaders = {
  "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// Cache-Control headers for different response types.
// AI responses are user-specific and non-cacheable.
export const noCacheHeaders = {
  ...corsHeaders,
  "Content-Type": "application/json",
  "Cache-Control": "no-store",
};

// Static/semi-static responses (e.g. writing prompts) can be cached briefly.
export const shortCacheHeaders = {
  ...corsHeaders,
  "Content-Type": "application/json",
  "Cache-Control": "private, max-age=300",  // 5 minutes
};
