# Hutzell Aviation website — rental update

This Astro project updates the original flight-training homepage into a professional aircraft-rental website for Hutzell Aviation LLC.

## Included pages

- Home
- About Tyler and Hutzell Aviation
- Piper Cherokee aircraft profile
- Pay-as-you-go and 15-, 25-, and 50-hour pricing options
- Interactive custom availability-calendar prototype
- Renter-application prototype
- Renter-account sign-in preview
- Custom 404 page

## Current business positioning

The site presents Hutzell Aviation as an aircraft-rental company for approved pilots and time builders. It does not advertise Hutzell Aviation as a flight school and does not offer instruction through the aircraft.

## What is functional now

- Responsive multi-page navigation
- Branded page layouts
- Interactive month calendar
- Calendar status and time-slot selection
- Browser validation for the renter application
- GitHub Pages deployment workflow

## What is still a prototype

The following features are intentionally not connected yet:

- User accounts and authentication
- Saving renter applications
- Secure document uploads
- Tyler’s approval dashboard
- Live availability records
- Reservation holds and confirmations
- Payments and hour-package purchases
- Actual aircraft-hour reconciliation

See `docs/BACKEND_IMPLEMENTATION_PLAN.md` for the next phase.

## Important placeholders to replace

Most editable business information is centralized in `src/data/site.ts`.

Replace before public launch:

- Phone: `(706) 555-0148`
- Email: `hello@hutzellaviation.com`
- Exact airport and aircraft location
- Piper Cherokee model, year, tail number, avionics, and specifications
- Exact renter and checkout requirements
- Wet/dry policy and Hobbs/tach policy
- Pay-as-you-go and block-hour rates
- Cancellation, expiration, overnight, fuel, and refund policies
- Tyler’s complete ATP biography and photographs
- Actual aircraft photography

## Logo note

The current logo contains white masking shapes. The site keeps the logo on `#FFFFFF` surfaces so those shapes remain hidden. Do not place the supplied logo directly on a colored or photographic background.

## Run locally

1. Install Node.js 22 or newer.
2. Open a terminal in the project folder.
3. Run:

```bash
npm install
npm run dev
```

Astro normally opens the site at `http://localhost:4321`.

## Build

```bash
npm run build
```

The static production site is generated in `dist/`.

## Deploy to GitHub Pages

The ZIP includes `.github/workflows/deploy.yml`.

1. Upload the contents of this project to the repository root.
2. Confirm that `.github/workflows/deploy.yml` is visible in GitHub.
3. In **Settings → Pages**, choose **GitHub Actions** as the source.
4. Commit to `main` or manually run the workflow from the Actions tab.

For a normal project repository, the workflow uses the repository name as the Astro base path. If the repository is named exactly `<username>.github.io`, set `BASE_PATH` to `/` in the workflow.

## Custom domain later

When using a custom domain:

1. Set `BASE_PATH: /`.
2. Set `SITE_URL` to the complete custom-domain URL.
3. Add a `public/CNAME` file containing the domain.
4. Configure the domain in GitHub Pages and at the DNS provider.
