const defaultSupabaseUrl = 'https://aleqesajbbcmufcydgqy.supabase.co';
const defaultSupabasePublishableKey = 'sb_publishable_7x3CeWFHC9LxDjrluuTXqA_QLBMMNbU';

const viteEnv = import.meta.env || {};

export const supabaseUrl = viteEnv.VITE_SUPABASE_URL || defaultSupabaseUrl;
export const supabasePublishableKey = viteEnv.VITE_SUPABASE_PUBLISHABLE_KEY || defaultSupabasePublishableKey;
