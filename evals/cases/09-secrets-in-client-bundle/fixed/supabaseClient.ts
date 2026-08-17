import { createClient } from '@supabase/supabase-js';

// The publishable key is meant to be public. It is only safe because every
// table it can reach enforces row level security.
export const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
);

// Privileged clients live in server-only modules. This file is imported by
// the browser bundle and must never hold one.
