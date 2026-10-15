# Hutzell Aviation — Actual Aircraft & Owner Photography Patch

This ZIP contains **only new or modified files** relative to the `HutzellAviation-main (1).zip` version supplied for this patch. No booking, payment, Supabase, or other functional files were changed.

## Apply to GitHub
1. Download and **unzip** this archive. **Do not upload the ZIP itself** to the repository.
2. Open the GitHub repository at its root, then choose **Add file → Upload files**.
3. Drag the extracted `src` and `public` directories into the uploader (preserving their nested paths), or use Git/GitHub Desktop to copy these paths into the same repository directories. Include this readme only if desired.
4. Check that the upload shows the `src/pages/...`, `src/styles/...`, and `public/images/...` paths before committing.
5. Commit the files to `main`; your existing Pages workflow builds/deploys the change.

Important: GitHub's web upload may not support folder drag-and-drop in every browser. If it does not preserve directories, use GitHub Desktop (recommended) or upload the photos inside `public/images/` and edit files inside `src/pages/` and `src/styles/` at their existing paths. Do not put `src` or `public` inside an extra top-level folder.

## Image assignments
- Home hero: `n8491f-hero.jpg` ← EI8A1761(1)
- Aircraft main showcase: `n8491f-rear-quarter.jpg` ← EI8A1744
- Aircraft gallery: `n8491f-rear-portrait.jpg` ← EI8A1749; `n8491f-cockpit.jpg` ← EI8A1750; `n8491f-front-view.jpg` ← EI8A1758(1); registration/avionics closeups cropped from EI8A1744 and EI8A1750
- About portrait: `tyler-hutzell-portrait.jpg` ← EI8A1734
- About gallery: `tyler-hutzell-airport.jpg` ← EI8A1733; `n8491f-front-quarter.jpg` ← EI8A1766(1); `n8491f-side-profile.jpg` ← EI8A1741; `n8491f-rear-quarter.jpg` ← EI8A1744; `n8491f-hero.jpg` ← EI8A1761(1)

Images have been JPEG-optimized; they remain photographs from your shoot. Source images were not altered stylistically. Old unused images (such as `tyler-hutzell.png` and `n8491f-home-hero.jpeg`) may remain in your repository, but are no longer referenced by these pages; delete manually if desired.

The previous public-domain photo URLs and inaccurate placeholder/stock-image descriptions are removed. No claim is made that the parked aircraft is in flight. All references use Astro's BASE_URL to work with your existing site configuration.
