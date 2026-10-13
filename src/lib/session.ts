import { getCurrentProfile, supabase, type Profile } from './supabase';

export type SessionState = { loading: boolean; userId: string | null; profile: Profile | null; error: boolean };
let state: SessionState = { loading: true, userId: null, profile: null, error: false };
const listeners = new Set<(value: SessionState) => void>();
let pending: Promise<void> | null = null;
let started = false;
export const isApproved = (profile: Profile | null) => profile?.role === 'admin' || profile?.approval_status === 'approved';
export function refreshSession() {
  if (pending) return pending;
  pending = (async () => {
    try {
      const { data: { session }, error } = await supabase.auth.getSession();
      if (error) throw error;
      const profile = session ? await getCurrentProfile() : null;
      if (session && !profile) throw new Error('Profile unavailable');
      state = { loading: false, userId: session?.user.id || null, profile, error: false };
    } catch {
      state = { loading: false, userId: null, profile: null, error: true };
    }
    listeners.forEach((listener) => listener(state));
  })().finally(() => { pending = null; });
  return pending;
}
export function onSession(listener: (value: SessionState) => void) {
  listeners.add(listener);
  listener(state);
  if (!started) { started = true; void refreshSession(); }
  return () => listeners.delete(listener);
}
supabase.auth.onAuthStateChange(() => {
  // Run outside the auth callback's lock, and refresh again if an earlier read was in flight.
  window.setTimeout(async () => { if (pending) await pending; void refreshSession(); }, 0);
});
