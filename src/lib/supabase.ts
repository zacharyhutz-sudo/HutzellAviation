const supabaseUrl = import.meta.env.PUBLIC_SUPABASE_URL || 'https://svcrlkpyudmksrnvgrsj.supabase.co';
const supabaseKey = import.meta.env.PUBLIC_SUPABASE_PUBLISHABLE_KEY || 'sb_publishable_8RbhMmA8HEI6nWS_un_m_g_ug3kJHPo';

export const isSupabaseConfigured = Boolean(supabaseUrl && supabaseKey);

const browserFactory = typeof window !== 'undefined'
  ? (window as unknown as { supabase?: { createClient: (url: string, key: string, options?: unknown) => any } }).supabase
  : undefined;

if (!browserFactory) {
  throw new Error('Supabase browser library did not load.');
}

export const supabase = browserFactory.createClient(supabaseUrl, supabaseKey || 'missing-publishable-key', {
  auth: {
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: true,
  },
});

export const siteUrl = import.meta.env.PUBLIC_SITE_URL || 'https://zacharyhutz-sudo.github.io/HutzellAviation/';
export const aircraftId = '00000000-0000-0000-0000-000000000001';
export const aviationTimeZone = 'America/New_York';

export type Profile = {
  id: string;
  email: string;
  full_name: string | null;
  phone: string | null;
  role: 'renter' | 'admin';
  approval_status: 'incomplete' | 'pending' | 'approved' | 'suspended' | 'rejected';
};

export type CalendarEvent = {
  event_id: string;
  event_kind: 'reservation' | 'block';
  starts_at: string;
  ends_at: string;
  status: string;
  label: string;
};

export async function getCurrentProfile(): Promise<Profile | null> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return null;
  const { data, error } = await supabase
    .from('profiles')
    .select('id,email,full_name,phone,role,approval_status')
    .eq('id', user.id)
    .single();
  if (error) throw error;
  return data as Profile;
}

export function resolveSiteUrl(base: string): string {
  if (siteUrl) return siteUrl.endsWith('/') ? siteUrl : `${siteUrl}/`;
  return `${window.location.origin}${base}`;
}
