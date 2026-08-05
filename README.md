# Hutzell Aviation website

A responsive, single-page Astro website for Hutzell Aviation LLC. The design uses the supplied logo and brand palette:

- Midnight Navy: `#082B45`
- Aviation Blue: `#2F6F94`
- Runway Gold: `#D99A2B`
- Steel Gray: `#697985`
- Cloud White: `#F6F8F9`
- White: `#FFFFFF`
- Headings: League Spartan
- Body copy: Lato

## Important placeholders to replace before publishing

The following information is intentionally temporary:

- Phone: `(706) 555-0148`
- Email: `hello@hutzellaviation.com`
- Instagram URL
- Exact airport and meeting location
- Aircraft make, model, equipment, specifications, and rates
- Lesson rates and scheduling policies
- Tyler’s instructor biography and portrait

Most business information is centralized in `src/data/site.ts`.

## Run locally

1. Install Node.js 22.12 or newer.
2. Open a terminal in this project folder.
3. Run:

```bash
npm install
npm run dev
```

Astro will print the local preview address, normally `http://localhost:4321`.

## Build the site

```bash
npm run build
```

The finished static site will be placed in `dist/`.

## Deploy through GitHub Pages

This project includes `.github/workflows/deploy.yml`.

1. Create a new GitHub repository.
2. Upload all files and folders from this project—not the outer ZIP itself.
3. Commit to the `main` branch.
4. In the repository, open **Settings → Pages**.
5. Under **Build and deployment**, choose **GitHub Actions**.
6. Open the **Actions** tab and allow the deployment workflow to finish.

The workflow automatically uses the repository name as the GitHub Pages base path. If the repository itself is named `<username>.github.io`, change `BASE_PATH` in `.github/workflows/deploy.yml` to `/`.

### Custom domain later

When moving to a custom domain, change the workflow environment values:

```yaml
env:
  BASE_PATH: /
  SITE_URL: https://yourdomain.com
```

Then configure the custom domain in GitHub Pages settings.

## Logo note

The current logo uses white masking shapes. The supplied website logo asset changes those masking shapes to pure `#FFFFFF` and only places the logo on white surfaces so they remain hidden. Do not place this logo asset on a colored or photographic background.

## Contact behavior

The contact buttons currently use `mailto:` and `tel:` links. There is no backend form, so the site will not silently collect or lose form submissions. A service such as Formspree can be connected later.
