import { defineConfig } from 'vitepress'
import { apiSidebar } from './generated/api-sidebar'
import { guideSidebar } from './generated/guide-sidebar'
import { dartpadPlugin } from './theme/plugins/dartpad'
import { apiLinkerPlugin } from './theme/plugins/api-linker'
// import llmstxt from 'vitepress-plugin-llms'

export default defineConfig({
  title: 'acme_client API',
  description: 'API documentation for acme_client',
  srcExclude: ['CLAUDE.md', 'AGENTS.md'],
  // Cross-references to SDK types (dart:core, dart:collection) produce
  // dead links since we only generate docs for this package.
  ignoreDeadLinks: true,
  // Show "Last updated" timestamps on pages (requires git history).
  lastUpdated: true,
  // vite: {
  //   plugins: [llmstxt()],
  // },
  markdown: {
    config: (md) => {
      md.use(dartpadPlugin)
      md.use(apiLinkerPlugin)
    },
  },
  themeConfig: {
    // "On this page" outline: show h2–h4 with nested tree structure.
    outline: { level: [2, 4] },
    // Full-text search powered by MiniSearch (built into VitePress).
    search: {
      provider: 'local',
    },
    // Navigation bar links.
    nav: [
      { text: 'Guide', link: '/guide/' },
      { text: 'API Reference', link: '/api/' },
    ],
    sidebar: {
      ...apiSidebar,
      ...guideSidebar,
    },
    socialLinks: [{ icon: 'github', link: 'https://github.com/Ephenodrom/Dart-Acme-Client' }],
  },
})
