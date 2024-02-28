// @ts-check
// `@type` JSDoc annotations allow editor autocompletion and type checking
// (when paired with `@ts-check`).
// There are various equivalent ways to declare your Docusaurus config.
// See: https://docusaurus.io/docs/api/docusaurus-config

import {themes as prismThemes} from 'prism-react-renderer';

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'Tagion',
  tagline: 'Tagion documentation',
  favicon: 'img/favicon.svg',
  markdown: {
    mermaid: true,
  },
  themes: [
        '@docusaurus/theme-mermaid',
        'docusaurus-theme-github-codeblock',
    ],
  plugins: [
    ['@docusaurus/plugin-content-blog',
      {
        path: 'tips',
        id: "TIPS",
        // Simple use-case: string editUrl
        editUrl: 'https://github.com/tagion/tagion/edit/master/docs/',
        editLocalizedFiles: false,
        blogTitle: 'Tagion Improvement Proposals',
        blogDescription: 'Blog',
        blogSidebarCount: 5,
        blogSidebarTitle: 'All TIPs',
        routeBasePath: 'tips',
        include: ['**/*.{md,mdx}'],
        exclude: [
          '**/_*.{js,jsx,ts,tsx,md,mdx}',
          '**/_*/**',
          '**/*.test.{js,jsx,ts,tsx}',
          '**/__tests__/**',
        ],
        postsPerPage: 10,
        blogListComponent: '@theme/BlogListPage',
        blogPostComponent: '@theme/BlogPostPage',
        blogTagsListComponent: '@theme/BlogTagsListPage',
        blogTagsPostsComponent: '@theme/BlogTagsPostsPage',
        truncateMarker: /<!--\s*(truncate)\s*-->/,
        showReadingTime: true,
        feedOptions: {
          type: 'rss',
          title: 'TIPs',
          description: 'Tagion Improvement proposals',
          copyright: 'tagion',
          language: undefined,
          createFeedItems: async (params) => {
            const {blogPosts, defaultCreateFeedItems, ...rest} = params;
            return defaultCreateFeedItems({
              // keep only the 10 most recent blog posts in the feed
              blogPosts: blogPosts.filter((item, index) => index < 10),
              ...rest,
            });
          },
        },
      },
        ]
  ],

  // Set the production url of your site here
  url: 'https://docs.tagion.org',
  // Set the /<baseUrl>/ pathname under which your site is served
  // For GitHub pages deployment, it is often '/<projectName>/'
  baseUrl: '/',
  trailingSlash: false,

  // GitHub pages deployment config.
  // If you aren't using GitHub pages, you don't need these.
  organizationName: 'tagion', // Usually your GitHub org/user name.
  projectName: 'tagion', // Usually your repo name.

  onBrokenLinks: 'warn',
  onBrokenMarkdownLinks: 'warn',

  // Even if you don't use internationalization, you can use this field to set
  // useful metadata like html lang. For example, if your site is Chinese, you
  // may want to replace "en" with "zh-Hans".
  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          sidebarPath: './sidebars.js',
          // Please change this to your repo.
          // Remove this to remove the "edit this page" links.
          editUrl:
            'https://github.com/tagion/tagion/tree/master/docs/',
        },
        // blog: {
        //   showReadingTime: true,
        //   // Please change this to your repo.
        //   // Remove this to remove the "edit this page" links.
        //   editUrl: 'https://github.com/tagion/tagion/tree/master/docs/',
        // },
        pages: {
        },
        theme: {
          customCss: './src/css/custom.css',
        },
      }),
    ],
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
    algolia: {
      appId: 'SK35XFOZMR',
      apiKey: 'da880a39f3909734f07a1a115c7331de',
      indexName: 'tagion',
      contextualSearch: false,
    },
      // Replace with your project's social card
      image: 'img/tagion-social-card.jpg',
      navbar: {
        title: 'Tagion',
        logo: {
          alt: 'Tagion logo',
          src: 'img/favicon.svg',
          srcDark: 'img/favicon-dark.svg',
        },
        items: [
          {
            type: 'docSidebar',
            sidebarId: 'tutorialSidebar',
            position: 'left',
            label: 'Docs',
          },
          {to: '/tips', label: 'TIPs', position: 'left'},
          {to: '/blog', label: 'blog', position: 'left'},
          {to: '/changelog', label: 'Changelog', position: 'right'},
          {
            href: 'https://ddoc.tagion.org',
            label: 'Ddoc',
            position: 'right',
          },
          {
            href: 'https://github.com/tagion/tagion',
            label: 'GitHub',
            position: 'right',
          },
        ],
      },
      footer: {
        style: 'dark',
        links: [
          {
            title: 'Docs',
            items: [
              {
                label: 'Getting Started',
                to: '/docs/guide',
              },
              {
                label: 'HiBON',
                href: 'https://www.hibon.org',
              },
              {
                label: 'Ddoc',
                href: 'https://ddoc.tagion.org',
              },
            ],
          },
          {
            title: 'Community',
            items: [
              {
                label: 'Discord',
                href: 'https://discord.gg/za2hb62quR',
              },
              {
                label: 'Twitter',
                href: 'https://twitter.com/TagionOfficial',
              },
              {
                label: 'Telegram',
                href: 'https://t.me/tagionChat',
              },
            ],
          },
          {
            title: 'More',
            items: [
              {
                label: 'Blog',
                href: 'https://tagion.medium.com',
              },
              {
                label: 'GitHub',
                href: 'https://github.com/tagion/tagion',
              },
              {
                label: 'Tagion',
                href: 'https://www.tagion.org',
              },
            ],
          },
        ],
        copyright: `Copyright © ${new Date().getFullYear()} Tagion.org, Built with Docusaurus.`,
      },
      prism: {
        theme: prismThemes.github,
        darkTheme: prismThemes.dracula,
        additionalLanguages: [ 'd' ],
      },
    }),
};

export default config;
