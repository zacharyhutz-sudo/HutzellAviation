import { aviationTimeZone, type CalendarEvent } from './supabase';

const dateTimeParts = new Intl.DateTimeFormat('en-US', {
  timeZone: aviationTimeZone,
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
  hour: '2-digit',
  minute: '2-digit',
  second: '2-digit',
  hourCycle: 'h23',
});

export function zonedDateTimeToUtc(date: string, time: string): Date {
  const [year, month, day] = date.split('-').map(Number);
  const [hour, minute] = time.split(':').map(Number);
  let timestamp = Date.UTC(year, month - 1, day, hour, minute, 0);

  // Resolve the Eastern-time wall clock to a UTC instant, including DST.
  for (let i = 0; i < 3; i += 1) {
    const parts = Object.fromEntries(
      dateTimeParts.formatToParts(new Date(timestamp))
        .filter((part) => part.type !== 'literal')
        .map((part) => [part.type, Number(part.value)]),
    ) as Record<string, number>;
    const displayedAsUtc = Date.UTC(parts.year, parts.month - 1, parts.day, parts.hour, parts.minute, parts.second);
    timestamp -= displayedAsUtc - Date.UTC(year, month - 1, day, hour, minute, 0);
  }
  return new Date(timestamp);
}

export function easternDateKey(value: string | Date): string {
  const date = typeof value === 'string' ? new Date(value) : value;
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: aviationTimeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(date);
  const get = (type: string) => parts.find((part) => part.type === type)?.value || '';
  return `${get('year')}-${get('month')}-${get('day')}`;
}

export function formatEasternTime(value: string): string {
  return new Intl.DateTimeFormat('en-US', {
    timeZone: aviationTimeZone,
    hour: 'numeric',
    minute: '2-digit',
  }).format(new Date(value));
}

export function formatEasternDate(value: string | Date): string {
  const date = typeof value === 'string' ? new Date(value) : value;
  return new Intl.DateTimeFormat('en-US', {
    timeZone: aviationTimeZone,
    weekday: 'long',
    month: 'long',
    day: 'numeric',
    year: 'numeric',
  }).format(date);
}

export function monthUtcRange(year: number, monthIndex: number): { start: string; end: string } {
  const month = String(monthIndex + 1).padStart(2, '0');
  const next = new Date(Date.UTC(year, monthIndex + 1, 1));
  const nextDate = `${next.getUTCFullYear()}-${String(next.getUTCMonth() + 1).padStart(2, '0')}-01`;
  return {
    start: zonedDateTimeToUtc(`${year}-${month}-01`, '00:00').toISOString(),
    end: zonedDateTimeToUtc(nextDate, '00:00').toISOString(),
  };
}

export function eventsForDate(events: CalendarEvent[], dateKey: string): CalendarEvent[] {
  const dayStart = zonedDateTimeToUtc(dateKey, '00:00').getTime();
  const dayEnd = zonedDateTimeToUtc(dateKey, '23:59').getTime() + 60_000;
  return events
    .filter((event) => new Date(event.starts_at).getTime() < dayEnd && new Date(event.ends_at).getTime() > dayStart)
    .sort((a, b) => new Date(a.starts_at).getTime() - new Date(b.starts_at).getTime());
}

export function overlaps(events: CalendarEvent[], start: Date, end: Date): CalendarEvent | undefined {
  return events.find((event) => new Date(event.starts_at) < end && new Date(event.ends_at) > start);
}

export function timeOptions(startHour = 7, endHour = 21, stepMinutes = 30): Array<{ value: string; label: string }> {
  const options: Array<{ value: string; label: string }> = [];
  for (let minutes = startHour * 60; minutes <= endHour * 60; minutes += stepMinutes) {
    const hour = Math.floor(minutes / 60);
    const minute = minutes % 60;
    const value = `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`;
    const label = new Intl.DateTimeFormat('en-US', { hour: 'numeric', minute: '2-digit', timeZone: 'UTC' })
      .format(new Date(Date.UTC(2020, 0, 1, hour, minute)));
    options.push({ value, label });
  }
  return options;
}
