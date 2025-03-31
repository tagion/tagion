// @ts-check
// `@type` JSDoc annotations allow editor autocompletion and type checking
// (when paired with `@ts-check`).
// There are various equivalent ways to declare your Docusaurus config.
// See: https://docusaurus.io/docs/api/docusaurus-config

import {themes as prismThemes} from 'prism-react-renderer';
import remarkMath from 'remark-math';
import rehypeKatex from 'rehype-katex';

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'Tagion',
  tagline: 'Tagion documentation',
  favicon: 'img/favicon.svg',
  markdown: {
    mermaid: true,
  },
  stylesheets: [
    {
      href: 'https://cdn.jsdelivr.net/npm/katex@0.13.24/dist/katex.min.css',
      type: 'text/css',
      integrity:
        'sha384-odtC+0UGzzFL/6PNoE8rX/SPcQDXBJ+uRepguP4QkPCm2LBxH3FA3y+fKSiJ+AmM',
      crossorigin: 'anonymous',
    },
  ],
  themes: [
        '@docusaurus/theme-mermaid',
        'docusaurus-theme-github-codeblock',
    ],
  // plugins: [
  //   ['@docusaurus/plugin-content-blog',
  //     {
  //       path: 'tips',
  //       id: "TIPS",
  //       // Simple use-case: string editUrl
  //       editUrl: 'https://github.com/tagion/tagion/edit/master/docs/',
  //       editLocalizedFiles: false,
  //       blogTitle: 'Tagion Improvement Proposals',
  //       blogDescription: 'Blog',
  //       blogSidebarCount: 5,
  //       blogSidebarTitle: 'All TIPs',
  //       routeBasePath: 'tips',
  //       include: ['**/*.{md,mdx}'],
  //       exclude: [
  //         '**/_*.{js,jsx,ts,tsx,md,mdx}',
  //         '**/_*/**',
  //         '**/*.test.{js,jsx,ts,tsx}',
  //         '**/__tests__/**',
  //       ],
  //       postsPerPage: 10,
  //       blogListComponent: '@theme/BlogListPage',
  //       blogPostComponent: '@theme/BlogPostPage',
  //       blogTagsListComponent: '@theme/BlogTagsListPage',
  //       blogTagsPostsComponent: '@theme/BlogTagsPostsPage',
  //       truncateMarker: /<!--\s*(truncate)\s*-->/,
  //       showReadingTime: true,
  //       feedOptions: {
  //         type: 'rss',
  //         title: 'TIPs',
  //         description: 'Tagion Improvement proposals',
  //         copyright: 'tagion',
  //         language: undefined,
  //         createFeedItems: async (params) => {
  //           const {blogPosts, defaultCreateFeedItems, ...rest} = params;
  //           return defaultCreateFeedItems({
  //             // keep only the 10 most recent blog posts in the feed
  //             blogPosts: blogPosts.filter((item, index) => index < 10),
  //             ...rest,
  //           });
  //         },
  //       },
  //     },
  //       ]
  // ],

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
          path: 'tech',
          routeBasePath: 'tech',
          remarkPlugins: [remarkMath],
          rehypePlugins: [rehypeKatex],
          //showLastUpdateTime: true,
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
  plugins: [
    [
      '@docusaurus/plugin-content-docs',
      {
        id: 'gov',
        path: 'gov',
        routeBasePath: 'gov',
        showLastUpdateTime: true,
        sidebarPath: './sidebars.js',
        remarkPlugins: [remarkMath],
        rehypePlugins: [rehypeKatex],
        editUrl:
            'https://github.com/tagion/tagion/tree/current/docs/',
      },
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
      extraUrls: ['https://docs.tagion.org/ddoc/tagion'],
    },
      // Replace with your project's social card
      image: 'img/tagion-social-card.jpg',
      navbar: {
        logo: {
          href: 'https://tagion.org',
          alt: 'Tagion logo',
          src: 'img/logo.svg',
          srcDark: 'img/logo-dark.svg',
        },
        items: [
          {
            type: 'docSidebar',
            sidebarId: 'tutorialSidebar',
            position: 'left',
            label: 'Tech',
          },
          {to: '/gov/intro', label: 'Gov', position: 'left'},
          {to: '/tech/tips/0', label: 'TIPs', position: 'left'},
       // {href: 'https://tagion.medium.com', label: 'Blog', position: 'left'},
          {to: '/changelog', label: 'Changelog', position: 'right'},
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
            title: 'Tech Documentation',
            items: [
              {
                 label: 'Concept paper',
                to: 'https://www.tagion.org/resources/tagion-whitepaper.pdf',
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
                label: 'Tagion Website',
                href: 'https://www.tagion.org',
              },
              {
                label: 'Tagion Blog',
                href: 'https://tagion.medium.com',
              },
              {
                label: 'Decard Website',
                href: 'https://decard.io',
              },
              
            ],
          },
        ],
        copyright: `Copyright © ${new Date().getFullYear()} Decard AG, Built with Docusaurus.`,
      },
      prism: {
        theme: prismThemes.github,
        darkTheme: prismThemes.dracula,
        additionalLanguages: [ 'd' ],
      },
    }),
};

export default config;
