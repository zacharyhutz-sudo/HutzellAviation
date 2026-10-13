const key = `${import.meta.env.BASE_URL}hutzell-booking-draft-v1`;
export type BookingDraft = { date: string; startTime: string; endTime: string; estimatedHours: string; notes: string; savedAt: number; userId: string | null };
export function saveBookingDraft(draft: Omit<BookingDraft, 'savedAt'>) {
  try { sessionStorage.setItem(key, JSON.stringify({ ...draft, savedAt: Date.now() })); } catch { /* Booking still works without browser storage. */ }
}
export function clearBookingDraft() { try { sessionStorage.removeItem(key); } catch {} }
export function readBookingDraft(userId: string | null): BookingDraft | null {
  try {
    const draft = JSON.parse(sessionStorage.getItem(key) || 'null');
    if (!draft || typeof draft.savedAt !== 'number' || Date.now() - draft.savedAt > 2 * 60 * 60 * 1000 || draft.savedAt > Date.now() || (draft.userId && draft.userId !== userId)) return null;
    if (!/^\d{4}-\d{2}-\d{2}$/.test(draft.date) || !/^\d{2}:\d{2}$/.test(draft.startTime) || !/^\d{2}:\d{2}$/.test(draft.endTime)) return null;
    if (typeof draft.notes !== 'string' || draft.notes.length > 500 || typeof draft.estimatedHours !== 'string') return null;
    return draft;
  } catch { return null; }
}
