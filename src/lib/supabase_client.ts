import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://clgwpwtfsjspoybnikpd.supabase.co';
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || '';

// Initialize and export the clean client without breaking on missing type paths
export const supabase = createClient(supabaseUrl, supabaseAnonKey);