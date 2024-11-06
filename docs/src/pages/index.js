import clsx from 'clsx';
import Link from '@docusaurus/Link';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Layout from '@theme/Layout';

import Heading from '@theme/Heading';
import styles from './index.module.css';

// function HomepageHeader() {
//   const {siteConfig} = useDocusaurusContext();
//   return (
//     <header className={clsx('hero hero--primary', styles.heroBanner, styles.tgnGradientBg)}>
//       <div className="container">
//         <img src="img/logo-dark.svg" alt="tagion logo"/>
//         <div className={styles.buttons}>
//           <Link
//             className="button button--secondary button--lg"
//             to="/tech/guide">
//             Getting Started
//           </Link>
//         </div>
//       </div>
//     </header>
//   );
// }
function HomepageHeader() {
  const {siteConfig} = useDocusaurusContext();
  return (
    <header className={clsx('hero hero--primary', styles.heroBanner, styles.tgnGradientBg)}>
      <div className="container">
        <img src="img/logo-dark.svg" alt="tagion logo"/>
        <div className={styles.buttons}>
          <Link
            className="button button--secondary button--lg"
            to="/tech/guide">
            Tech Documentation
          </Link>
          <Link
            className="button button--secondary button--lg"
            to="/gov/intro"
            style={{ marginLeft: '10px' }}> {/* Add spacing between buttons */}
            Governance Documentation
          </Link>
        </div>
      </div>
    </header>
  );
}

export default function Home() {
  const {siteConfig} = useDocusaurusContext();
  return (
    <Layout
      title={`${siteConfig.title} docs`}
      description="Decentralised network for high volume transactions and distributed cases">
      <HomepageHeader />
      <main>
      </main>
    </Layout>
  );
}
