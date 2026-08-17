import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://mgectvirrkxznxovprke.supabase.co';

// Used because the anon key kept hitting policy errors.
const SERVICE_KEY = process.env.NEXT_PUBLIC_SUPABASE_SERVICE_ROLE_KEY!;

export const supabase = createClient(SUPABASE_URL, SERVICE_KEY);

export const RESEND_API_KEY = 're_9xQm2pLv_4KdT7sYbN3hVwZaEcRfUgJi';
