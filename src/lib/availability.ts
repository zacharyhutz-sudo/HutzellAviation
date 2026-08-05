export type DayStatus = 'available' | 'limited' | 'reserved' | 'maintenance';

export interface AvailabilityDay {
  date: string;
  status: DayStatus;
  note?: string;
  slots?: string[];
}

// Front-end prototype data only. Replace with Supabase queries when the backend is connected.
export const demoAvailability: AvailabilityDay[] = [
  { date: '2026-08-06', status: 'available', slots: ['8:00 AM–11:00 AM', '1:00 PM–5:00 PM'] },
  { date: '2026-08-07', status: 'limited', note: 'Afternoon only', slots: ['2:00 PM–6:00 PM'] },
  { date: '2026-08-08', status: 'reserved', note: 'Reserved' },
  { date: '2026-08-09', status: 'available', slots: ['9:00 AM–1:00 PM', '3:00 PM–7:00 PM'] },
  { date: '2026-08-10', status: 'maintenance', note: 'Scheduled maintenance' },
  { date: '2026-08-11', status: 'available', slots: ['8:00 AM–12:00 PM', '12:30 PM–4:30 PM'] },
  { date: '2026-08-12', status: 'reserved', note: 'Reserved' },
  { date: '2026-08-13', status: 'available', slots: ['7:30 AM–11:30 AM', '1:30 PM–6:00 PM'] },
  { date: '2026-08-14', status: 'limited', note: 'Morning only', slots: ['8:00 AM–11:00 AM'] },
  { date: '2026-08-15', status: 'available', slots: ['9:00 AM–2:00 PM'] },
  { date: '2026-08-16', status: 'reserved', note: 'Reserved' },
  { date: '2026-08-17', status: 'available', slots: ['8:00 AM–12:00 PM', '2:00 PM–6:00 PM'] },
  { date: '2026-08-18', status: 'available', slots: ['10:00 AM–3:00 PM'] },
  { date: '2026-08-19', status: 'maintenance', note: 'Inspection block' },
  { date: '2026-08-20', status: 'available', slots: ['8:00 AM–1:00 PM', '2:00 PM–6:00 PM'] },
  { date: '2026-08-21', status: 'limited', note: 'Evening only', slots: ['4:00 PM–8:00 PM'] },
  { date: '2026-08-22', status: 'reserved', note: 'Reserved' },
  { date: '2026-08-23', status: 'available', slots: ['9:00 AM–5:00 PM'] },
  { date: '2026-08-24', status: 'available', slots: ['8:00 AM–12:00 PM'] },
  { date: '2026-08-25', status: 'reserved', note: 'Reserved' },
  { date: '2026-08-26', status: 'available', slots: ['8:00 AM–11:30 AM', '1:00 PM–5:00 PM'] },
  { date: '2026-08-27', status: 'available', slots: ['10:00 AM–6:00 PM'] },
  { date: '2026-08-28', status: 'limited', note: 'Morning only', slots: ['7:30 AM–10:30 AM'] },
  { date: '2026-08-29', status: 'available', slots: ['9:00 AM–3:00 PM'] },
  { date: '2026-08-30', status: 'reserved', note: 'Reserved' },
  { date: '2026-08-31', status: 'available', slots: ['8:00 AM–12:00 PM', '2:00 PM–6:00 PM'] },
  { date: '2026-09-01', status: 'available', slots: ['9:00 AM–1:00 PM'] },
  { date: '2026-09-02', status: 'limited', note: 'Afternoon only', slots: ['1:00 PM–5:30 PM'] },
  { date: '2026-09-03', status: 'reserved', note: 'Reserved' },
  { date: '2026-09-04', status: 'available', slots: ['8:00 AM–4:00 PM'] },
  { date: '2026-09-05', status: 'maintenance', note: 'Maintenance' },
  { date: '2026-09-06', status: 'available', slots: ['9:00 AM–3:00 PM'] },
  { date: '2026-09-07', status: 'reserved', note: 'Reserved' },
  { date: '2026-09-08', status: 'available', slots: ['8:00 AM–12:00 PM', '1:00 PM–6:00 PM'] },
];
