import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

/// Checks if the authenticated user has an active premium subscription.
/// Returns { isPremium, userId } or throws if not authenticated.
export async function getUserTier(
  authHeader: string,
): Promise<{ isPremium: boolean; userId: string }> {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const {
    data: { user },
    error,
  } = await supabase.auth.getUser();

  if (error || !user) {
    throw new Error("Unauthorized");
  }

  const { data: profile } = await supabase
    .from("profiles")
    .select("is_subscribed")
    .eq("id", user.id)
    .single();

  return {
    isPremium: profile?.is_subscribed === true,
    userId: user.id,
  };
}
