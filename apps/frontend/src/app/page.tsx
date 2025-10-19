import styles from './page.module.css'

export default function Home() {
  return (
    <main className={styles.main}>
      <div className={styles.container}>
        <h1 className={styles.title}>
          Welcome to <span className={styles.highlight}>ECS Next.js</span>
        </h1>
        <p className={styles.description}>
          This application is running on AWS ECS with Managed Instances
        </p>

        <div className={styles.grid}>
          <div className={styles.card}>
            <h2>⚡ Fast</h2>
            <p>Built with Next.js 14 and optimized for production</p>
          </div>

          <div className={styles.card}>
            <h2>🔒 Secure</h2>
            <p>Running in private subnets with VPC endpoints</p>
          </div>

          <div className={styles.card}>
            <h2>📈 Scalable</h2>
            <p>Auto-scaling with ECS Capacity Providers</p>
          </div>

          <div className={styles.card}>
            <h2>🌐 Global</h2>
            <p>Load balanced across multiple availability zones</p>
          </div>
        </div>

        <div className={styles.info}>
          <p>Environment: {process.env.NODE_ENV}</p>
          <p>Region: {process.env.AWS_REGION || 'ap-northeast-1'}</p>
        </div>
      </div>
    </main>
  )
}
