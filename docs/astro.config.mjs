import { defineConfig } from 'astro/config';

export default defineConfig({
  i18n: {
    locales: ['en', 'zh-cn', 'zh-hant', 'ja', 'ko', 'es'],
    defaultLocale: 'en',
    routing: {
      prefixDefaultLocale: false,
    },
  },
});
