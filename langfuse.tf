locals {
  langfuse_values = <<EOT
global:
  defaultStorageClass: efs
langfuse:
  salt:
    secretKeyRef:
      name: langfuse
      key: salt
  nextauth:
    #url: "http://localhost"
    secret:
      secretKeyRef:
        name: langfuse
        key: nextauth-secret
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: ${aws_iam_role.langfuse_irsa.arn}
  # Resource configuration for production workloads
  resources:
    limits:
      cpu: "${var.langfuse_cpu}"
      memory: "${var.langfuse_memory}"
    requests:
      cpu: "${var.langfuse_cpu}"
      memory: "${var.langfuse_memory}"
  # The Web container needs slightly increased initial grace period on Fargate
  web:
    livenessProbe:
      initialDelaySeconds: 60
    readinessProbe:
      initialDelaySeconds: 60
postgresql:
  deploy: false
  host: ${aws_rds_cluster.postgres.endpoint}:5432
  auth:
    username: langfuse
    database: langfuse
    existingSecret: langfuse
    secretKeys:
      userPasswordKey: postgres-password
clickhouse:
  host: langfuse-clickhouse-shard0.langfuse
  auth:
    existingSecret: langfuse
    existingSecretKey: clickhouse-password
  # Resource configuration for ClickHouse containers
  resources:
    limits:
      cpu: "${var.clickhouse_cpu}"
      memory: "${var.clickhouse_memory}"
    requests:
      cpu: "${var.clickhouse_cpu}"
      memory: "${var.clickhouse_memory}"
  # Resource configuration for ClickHouse Keeper
  zookeeper:
    resources:
      limits:
        cpu: "${var.clickhouse_keeper_cpu}"
        memory: "${var.clickhouse_keeper_memory}"
      requests:
        cpu: "${var.clickhouse_keeper_cpu}"
        memory: "${var.clickhouse_keeper_memory}"
redis:
  deploy: false
  host: ${aws_elasticache_replication_group.redis.primary_endpoint_address}
  auth:
    existingSecret: langfuse
    existingSecretPasswordKey: redis-password
  tls:
    enabled: true
s3:
  deploy: false
  bucket: ${aws_s3_bucket.langfuse.id}
  region: ${data.aws_region.current.name}
  forcePathStyle: false
  eventUpload:
    prefix: "events/"
  batchExport:
    prefix: "exports/"
  mediaUpload:
    prefix: "media/"
EOT
  ingress_values  = <<EOT
langfuse:
  ingress:
    enabled: true
    className: alb
    annotations:
      alb.ingress.kubernetes.io/scheme: internet-facing
      alb.ingress.kubernetes.io/target-type: 'ip'
      alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80}]'
    hosts:
    - host: ""
      paths:
      - path: /
        pathType: Prefix
EOT
  encryption_values = var.use_encryption_key == false ? "" : <<EOT
langfuse:
  encryptionKey:
    secretKeyRef:
      name: ${kubernetes_secret.langfuse.metadata[0].name}
      key: encryption_key
EOT
}

resource "kubernetes_namespace" "langfuse" {
  depends_on = [
    aws_eks_cluster.langfuse
  ]

  metadata {
    name = "langfuse"
  }
}

resource "random_bytes" "salt" {
  # Should be at least 256 bits (32 bytes): https://langfuse.com/self-hosting/configuration#core-infrastructure-settings ~> SALT
  length = 32
}

resource "random_bytes" "nextauth_secret" {
  # Should be at least 256 bits (32 bytes): https://langfuse.com/self-hosting/configuration#core-infrastructure-settings ~> NEXTAUTH_SECRET
  length = 32
}

resource "random_bytes" "encryption_key" {
  count = var.use_encryption_key ? 1 : 0
  # Must be exactly 256 bits (32 bytes): https://langfuse.com/self-hosting/configuration#core-infrastructure-settings ~> ENCRYPTION_KEY
  length = 32
}

resource "kubernetes_secret" "langfuse" {
  metadata {
    name      = "langfuse"
    namespace = "langfuse"
  }

  data = {
    "redis-password"      = random_password.redis_password.result
    "postgres-password"   = random_password.postgres_password.result
    "salt"                = random_bytes.salt.base64
    "nextauth-secret"     = random_bytes.nextauth_secret.base64
    "clickhouse-password" = random_password.clickhouse_password.result
    "encryption_key"      = var.use_encryption_key ? random_bytes.encryption_key[0].hex : ""
  }
}

resource "helm_release" "langfuse" {
  name             = "langfuse"
  repository       = "https://langfuse.github.io/langfuse-k8s"
  version          = var.langfuse_helm_chart_version
  chart            = "langfuse"
  namespace        = "langfuse"
  create_namespace = true

  values = [
    local.langfuse_values,
    local.ingress_values,
    local.encryption_values,
  ]

  depends_on = [
    aws_iam_role.langfuse_irsa,
    aws_iam_role_policy.langfuse_s3_access,
    aws_eks_fargate_profile.namespaces,
    kubernetes_persistent_volume.clickhouse_data,
    kubernetes_persistent_volume.clickhouse_zookeeper,
  ]
}
