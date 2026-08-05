import { defineConfig } from 'astro/config';

const base = process.env.BASE_PATH || '/';
const site = process.env.SITE_URL || 'http://localhost:4321';

export default defineConfig({
  site,
  base,
  output: 'static',
  trailingSlash: 'always',
  build: {
    assets: '_assets',
  },
});
