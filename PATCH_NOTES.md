# Calendar visibility patch

This patch fixes the selected-date booking panel appearing below the calendar on common laptop-width viewports.

Changes:

- Keeps the calendar and booking panel side-by-side above 820px.
- Stacks the booking panel only on smaller screens.
- Automatically scrolls the booking panel into view after a date is selected on mobile/tablet layouts.
- Adds explicit hidden-state rules so the empty-state and booking form cannot overlap.
- Adds safe focus handling for keyboard and screen-reader users.

No Supabase SQL changes are required for this patch.
