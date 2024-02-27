// @ts-check
// `@type` JSDoc annotations allow editor autocompletion and type checking
// (when paired with `@ts-check`).
// There are various equivalent ways to declare your Docusaurus config.
// See: https://docusaurus.io/docs/api/docusaurus-config

import {themes as prismThemes} from 'prism-react-renderer';

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'Tagion',
  tagline: 'Tagion',
  favicon: 'img/favicon.svg',
  markdown: {
    mermaid: true,
  },
  themes: ['@docusaurus/theme-mermaid'],
  plugins: [
    [
        'content-docs',
        {
          id: 'tips',
          path: 'tips',
          routeBasePath: 'tips',
          editUrl: 'https://github.com/tagion/tagion/tree/master/docs/',
          editCurrentVersion: true,
          sidebarPath: './sidebarTips.js',
          showLastUpdateAuthor: true,
          showLastUpdateTime: true,
        } // satisfies DocsOptions
      ],
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
        blog: {
          showReadingTime: true,
          // Please change this to your repo.
          // Remove this to remove the "edit this page" links.
          editUrl:
            'https://github.com/tagion/tagion/tree/master/docs/',
        },
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
                label: 'Tutorial',
                to: '/docs/intro',
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
                label: 'HiBON',
                href: 'https://www.hibon.org',
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
