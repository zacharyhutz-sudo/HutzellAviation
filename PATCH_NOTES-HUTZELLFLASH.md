# HutzellFlash / Hangar 10 patch

This patch adds the hidden HutzellFlash arcade integration to Hutzell Aviation.

## What changes

- The `#10` in the site footer's `Tie-down spot #10` is now an intentionally unstyled Easter-egg link.
- New unlisted `/hangar/` page with HutzellFlash and a live global Top 10 leaderboard.
- HutzellFlash is bundled under `public/hutzellflash/` and reports run start/game-over events to the Hangar page.
- Top-10 qualifiers are prompted for exactly three A-Z/0-9 characters.
- Supabase tracks one-time run tokens and validates submissions through RPC functions.
- The Hangar page is `noindex, nofollow`.

## Deploy

1. In Supabase Dashboard -> SQL Editor, run `supabase/hutzellflash.sql` once.
2. Copy the patch files into the Hutzell Aviation repo root, preserving folders.
3. Commit and push to GitHub.
4. Open the live site, scroll to the footer, and click only the `#10` in `Tie-down spot #10`.

The leaderboard keeps historical scores in Supabase but displays only the current Top 10.
