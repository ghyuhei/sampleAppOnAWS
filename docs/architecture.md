# システムアーキテクチャ

## 全体構成図

```
┌─────────────────────────────────────────────────────────────────┐
│  Users                                                           │
└────────────────────────────┬─────────────────────────────────────┘
                             │ HTTPS
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  CloudFront                                                      │
│  - Global CDN                                                    │
│  - WAF (Rate Limiting, AWS Managed Rules)                       │
│  - Origin Access Control (OAC)                                  │
└─────────┬──────────────────────────────┬─────────────────────────┘
          │                              │
          │ /_next/static/*              │ /api/*, /*
          ▼                              ▼
┌─────────────────────┐      ┌─────────────────────────────────────┐
│  S3 Bucket          │      │  Application Load Balancer          │
│  - Static Assets    │      │  - Public Subnet                    │
│  - _next/static/*   │      │  - Dynamic Port Mapping             │
│  - OAC Only Access  │      │  - Health Check                     │
└─────────────────────┘      └───────────────┬─────────────────────┘
                                             │
                                             │ Port 32768-65535
                                             ▼
                             ┌────────────────────────────────────┐
                             │  ECS Cluster (Private Subnet)      │
                             │  ┌──────────────┐  ┌─────────────┐│
                             │  │  Frontend    │  │  Backend    ││
                             │  │  Next.js 14  │  │  Fastify    ││
                             │  │  Port 3000   │  │  Port 3001  ││
                             │  └──────────────┘  └─────────────┘│
                             │                                    │
                             │  Auto Scaling Group                │
                             │  - t3.small/medium/large           │
                             │  - Amazon Linux 2023 (ECS-opt)     │
                             │  - IMDSv2, EBS Encrypted           │
                             └────────────────────────────────────┘
                                             │
                                             │ Private Access
                                             ▼
                             ┌────────────────────────────────────┐
                             │  VPC Endpoints                     │
                             │  - ECR (Docker Images)             │
                             │  - S3 (Artifacts)                  │
                             │  - CloudWatch Logs                 │
                             │  - SSM (Session Manager)           │
                             └────────────────────────────────────┘
```

## ネットワーク構成

### VPC設計

```
VPC: 10.x.0.0/16 (環境別)
├── Public Subnets (10.x.0.0/20)
│   ├── AZ-a: 10.x.0.0/24
│   ├── AZ-c: 10.x.1.0/24
│   └── AZ-d: 10.x.2.0/24
│   └── Resources: ALB, NAT Gateway
│
└── Private Subnets (10.x.128.0/20)
    ├── AZ-a: 10.x.128.0/24
    ├── AZ-c: 10.x.129.0/24
    └── AZ-d: 10.x.130.0/24
    └── Resources: ECS Instances
```

### セキュリティグループ

```
┌─────────────────┐
│  ALB SG         │  Allow: 80/443 from 0.0.0.0/0
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  ECS SG         │  Allow: 32768-65535 from ALB SG
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  VPC Endpoints  │  Allow: 443 from ECS SG
└─────────────────┘
```

## コンポーネント詳細

### CloudFront

**役割**: グローバルCDN、WAF統合、オリジン保護

**設定**:
- Distribution: IPv4 + IPv6対応
- Price Class: 200 (US, Europe, Asia)
- SSL/TLS: TLS 1.2以上
- HTTP/3: 有効

**Origin**:
1. ALB (Primary): SSR、API (`/api/*`, `/*`)
2. S3 (Secondary): 静的アセット (`/_next/static/*`)

**Cache Behaviors**:
| Path Pattern | Origin | TTL | Cache |
|--------------|--------|-----|-------|
| `/_next/static/*` | S3 | 31536000s | All |
| `/api/*` | ALB | 0s | None |
| `/*` | ALB | 0s | Header-based |

**WAF Rules**:
- AWS Managed Rules (Core, Bad Inputs)
- Rate Limiting: 2000 req/5min
- Geo Blocking: オプション

### Application Load Balancer

**役割**: L7ロードバランシング、ヘルスチェック、SSL終端

**設定**:
- Scheme: internet-facing
- IP Address Type: ipv4
- Subnets: Public Subnets (3 AZ)
- Security Groups: ALB SG

**Listeners**:
- HTTP:80 → HTTPS:443 リダイレクト
- HTTPS:443 → Target Group (Forward)

**Target Group**:
- Type: instance
- Protocol: HTTP
- Health Check: `/api/health` (30s interval)
- Deregistration Delay: 30s (dev) / 60s (prod)

**Stickiness**:
- Type: lb_cookie
- Duration: 86400s (24h)

### ECS Cluster

**役割**: コンテナオーケストレーション

**Capacity Provider**:
- Type: EC2 Auto Scaling Group
- Managed Scaling: 有効
- Target Capacity: 100%
- Scale Protection: 有効

**Instance Configuration**:
- AMI: Amazon Linux 2023 (ECS-optimized)
- Instance Type: 環境別 (t3.small/medium/large)
- IAM Role: ECS Instance Role
- User Data: ECS_CLUSTER設定

**Auto Scaling**:
| 環境 | Min | Desired | Max | Scaling Metric |
|------|-----|---------|-----|----------------|
| dev | 0 | 1 | 3 | CPU/Memory |
| staging | 1 | 2 | 5 | CPU/Memory |
| prod | 2 | 3 | 10 | CPU/Memory |

**Tasks**:
- CPU: 256-1024 (環境別)
- Memory: 512-2048MB (環境別)
- Network Mode: bridge (Dynamic Port Mapping)
- Logging: CloudWatch Logs

### VPC Endpoints

**役割**: NAT Gateway通信削減、プライベートアクセス

**Endpoints**:
- `com.amazonaws.ap-northeast-1.ecr.dkr` (Interface)
- `com.amazonaws.ap-northeast-1.ecr.api` (Interface)
- `com.amazonaws.ap-northeast-1.s3` (Gateway)
- `com.amazonaws.ap-northeast-1.logs` (Interface)
- `com.amazonaws.ap-northeast-1.ecs` (Interface)
- `com.amazonaws.ap-northeast-1.ssm` (Interface)

**コスト削減効果**:
- NAT Gateway: ~$30-50/月削減
- Data Transfer: ~$20-30/月削減

## データフロー

### リクエストフロー

```
1. User Request
   ↓
2. CloudFront (CDN)
   ├─ Cache Hit → Return Cached Response
   └─ Cache Miss ↓
3. Origin Selection
   ├─ Static Assets (/_next/static/*) → S3
   └─ Dynamic Content (/*, /api/*) → ALB
   ↓
4. ALB (Load Balancing)
   ↓
5. ECS Task (Container)
   ↓
6. Response
```

### デプロイフロー

```
1. Git Push (GitHub)
   ↓
2. GitHub Actions (CI/CD)
   ├─ Lint, Test, Build
   ├─ Docker Build
   └─ Push to ECR (via VPC Endpoint)
   ↓
3. ecspresso Deploy
   ├─ Update Task Definition
   ├─ Update Service
   └─ Rolling Update
   ↓
4. ECS (Blue/Green Deployment)
   ├─ Start New Tasks
   ├─ Health Check
   ├─ Register to ALB
   └─ Deregister Old Tasks
   ↓
5. CloudFront Invalidation
   └─ Clear Cache (/_next/static/*)
```

## 環境別構成

### Development

**コスト重視**: ~$50/月

```
- ECS: t3.small x1, Single AZ
- NAT Gateway: 1個 (共有)
- Monitoring: Basic
- Backup: なし
```

### Staging

**バランス型**: ~$150/月

```
- ECS: t3.medium x2, Multi-AZ
- NAT Gateway: 1個 (共有)
- Monitoring: Enhanced + X-Ray
- Backup: 14日保持
```

### Production

**高可用性**: ~$300/月

```
- ECS: t3.large x3, Multi-AZ
- NAT Gateway: 各AZに1個
- Monitoring: Full (GuardDuty, Config)
- Backup: 30日保持
- Deletion Protection: 有効
```

## セキュリティ

### 多層防御

```
Layer 1: WAF (CloudFront)
  - Rate Limiting
  - AWS Managed Rules
  - Custom Rules

Layer 2: Security Groups
  - ALB: 80/443 only
  - ECS: ALB SG only
  - Least Privilege

Layer 3: Network Isolation
  - Private Subnets
  - VPC Endpoints
  - No Public IP

Layer 4: IAM
  - Task Execution Role (Pull Images)
  - Task Role (Application)
  - Instance Role (ECS Agent)

Layer 5: Encryption
  - At Rest: KMS (S3, ECR, EBS, Secrets)
  - In Transit: TLS 1.2+
```

### コンプライアンス

- IMDSv2: 強制有効
- EBS Encryption: 必須
- S3 Public Access: ブロック
- VPC Flow Logs: ステージング/本番
- GuardDuty: ステージング/本番
- AWS Config: ステージング/本番

## 監視とアラート

### メトリクス収集

```
Application
├─ CloudWatch Logs (All containers)
├─ Container Insights (CPU, Memory)
└─ X-Ray (Tracing) - staging/prod

Infrastructure
├─ EC2 Metrics (CPU, Network)
├─ ALB Metrics (Requests, Latency)
├─ CloudFront Metrics (Requests, Errors)
└─ VPC Flow Logs - staging/prod

Security
├─ GuardDuty (Threats)
├─ CloudTrail (API Audit)
└─ Config (Compliance)
```

### アラート閾値

| メトリクス | 閾値 | アクション |
|-----------|------|-----------|
| ECS CPU | >80% | Email + Auto Scale |
| ECS Memory | >80% | Email + Auto Scale |
| ALB 5xx | >10/5min | Email |
| ALB Response Time | >1s (p95) | Email |
| Unhealthy Targets | >0 | Email |

## スケーラビリティ

### 水平スケーリング

**ECS Service Auto Scaling**:
- Metric: CPU Utilization, Memory Utilization
- Target: 70% (staging), 60% (prod)
- Scale Out: 1分クールダウン
- Scale In: 5-10分クールダウン

**ECS Capacity Provider**:
- Metric: Task Placement
- Target Capacity: 100%
- Managed Scaling: 有効

### 垂直スケーリング

環境別にインスタンスタイプとタスクリソースを調整:
- dev: t3.small, 256 CPU, 512 MB
- staging: t3.medium, 512 CPU, 1024 MB
- prod: t3.large, 1024 CPU, 2048 MB

## 災害復旧

### バックアップ

```
Infrastructure
└─ Terraform State (S3 Versioning)

Application
├─ Docker Images (ECR Lifecycle)
└─ Task Definitions (Versioning)

Data
└─ (Future: RDS Automated Backup)
```

### RTO/RPO

- **dev**: RTO 4h, RPO 24h
- **staging**: RTO 2h, RPO 4h
- **prod**: RTO 1h, RPO 1h

### 復旧手順

1. **インフラ再構築**: `terraform apply` (15-20分)
2. **アプリデプロイ**: `ecspresso deploy` (5-10分)
3. **ヘルスチェック**: 自動
4. **検証**: 手動

## コスト最適化

### 実施済み施策

1. **VPC Endpoints**: NAT Gateway通信削減
2. **CloudFront**: Origin通信削減
3. **ECR Lifecycle**: 古いイメージ削除
4. **ECS Auto Scaling**: 需要に応じた調整
5. **Spot Instances**: (Future) 非本番環境

### コスト配分 (本番環境)

```
ECS (EC2): 40%    (~$120)
ALB: 10%          (~$30)
NAT Gateway: 30%  (~$90)
CloudFront: 5%    (~$15)
VPC Endpoints: 5% (~$15)
その他: 10%       (~$30)
─────────────────────────
合計: 100%        (~$300)
```

## 参考資料

- [AWS ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- [ALB with ECS](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/alb.html)
- [CloudFront with ALB](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/DownloadDistS3AndCustomOrigins.html)
