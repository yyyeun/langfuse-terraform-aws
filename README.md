# Deploy Langfuse on AWS EKS using Terraform

## 👾 Langfuse란?

![image](https://github.com/user-attachments/assets/12e22c2f-9590-4ae0-a8ae-326a8252a15d)

LLM으로 구동되는 애플리케이션을 위해 설계된 오픈 소스 **통합 가시성 및 분석** 플랫폼

**고급 추적 및 분석 모듈**을 통해 **모델 비용, 품질 및 지연 시간**에 대한 심층적인 인사이트를 제공함

### 주요 기능

1. **모니터링**: 추적, 실시간 지표, 피드백
2. **분석**: 평가, 테스트, 사용자 행동
3. **디버깅**: 자세한 디버그 로그, 오류 추적
4. **통합**: 프레임워크 지원, 도구 지원, API


## 🌐 Terraform으로 EKS에 **Langfuse 배포하기**

⚠️ [공식 도큐먼트](https://github.com/langfuse/langfuse-terraform-aws)는 도메인 접속을 가정한 코드이지만, 도메인을 보유하고 있지 않으며 테스트 용도이기 때문에 **ALB DNS 주소로 접근**할 수 있도록 수정했습니다.

### **Architecture**
![image](https://github.com/user-attachments/assets/33e26ba3-2117-434e-bcca-7e8fe23913a1)

- **VPC** with public and private subnets
- **EKS** cluster with Fargate compute
- **Aurora** PostgreSQL Serverless v2 cluster
- **ElastiCache** Redis cluster
- **S3** bucket for storage
- Required **IAM** roles and **security groups**
- AWS **Load Balancer Controller** for ingress
- **EFS** CSI Driver for persistent storage
- ~~TLS certificates and Route53 DNS configuration~~ (제거)

### Project 구조

```bash
langfuse-terraform-aws/
├── examples/
│   └── quickstart/
│       └── quickstart.tf              # 모듈 호출
├── clickhouse.tf                      # ClickHouse DB 구성
├── efs.tf                             # EFS 파일시스템 구성
├── eks.tf                             # EKS 클러스터 및 노드 그룹 구성
├── ingress.tf                         # ALB Ingress Controller 설정
├── langfuse-clickhouse-headless.yaml  # ClickHouse용 Headless Service YAML
├── langfuse.tf                        # Helm으로 Langfuse 설치
├── locals.tf                          # 지역 변수 정의
├── outputs.tf                         # 출력값 정의
├── postgresql.tf                      # Aurora(PostgreSQL) 설정
├── redis.tf                           # Redis 설정
├── s3.tf                              # S3 스토리지 설정
├── variables.tf                       # 입력 변수 정의
├── versions.tf                        # Terraform 및 Provider 버전
└── vpc.tf                             # VPC 및 네트워크 구성
```

### Execution

```bash
terraform init
terraform plan
terraform apply -auto-approve
terraform destroy -auto-approve
```

## 🧨 Trouble Shooting

### #1: kubectl이 EKS 클러스터와 통신하지 못함

**문제 상황**

EKS API 서버에 DNS로 접근할 수 없어서 `kubectl`이 클러스터와 통신하지 못하고 있는 상태

```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

E0707 00:24:23.436865    1904 memcache.go:265] "Unhandled Error" err="couldn't get current server API group list: Get \"https://2DE63831B1AE9EC847781E7DA59CCC6E.yl4.ap-northeast-2.eks.amazonaws.com/api?timeout=32s\": dial tcp: lookup 2DE63831B1AE9EC847781E7DA59CCC6E.yl4.ap-northeast-2.eks.amazonaws.com: no such host"
E0707 00:24:23.439338    1904 memcache.go:265] "Unhandled Error" err="couldn't get current server API group list: Get \"https://2DE63831B1AE9EC847781E7DA59CCC6E.yl4.ap-northeast-2.eks.amazonaws.com/api?timeout=32s\": dial tcp: lookup 2DE63831B1AE9EC847781E7DA59CCC6E.yl4.ap-northeast-2.eks.amazonaws.com: no such host"
E0707 00:24:23.441635    1904 memcache.go:265] "Unhandled Error" err="couldn't get current server API group list: Get \"https://2DE63831B1AE9EC847781E7DA59CCC6E.yl4.ap-northeast-2.eks.amazonaws.com/api?timeout=32s\": dial tcp: lookup 2DE63831B1AE9EC847781E7DA59CCC6E.yl4.ap-northeast-2.eks.amazonaws.com: no such host"
E0707 00:24:23.450225    1904 memcache.go:265] "Unhandled Error" err="couldn't get current server API group list: Get \"https://2DE63831B1AE9EC847781E7DA59CCC6E.yl4.ap-northeast-2.eks.amazonaws.com/api?timeout=32s\": dial tcp: lookup 2DE63831B1AE9EC847781E7DA59CCC6E.yl4.ap-northeast-2.eks.amazonaws.com: no such host"
E0707 00:24:23.454182    1904 memcache.go:265] "Unhandled Error" err="couldn't get current server API group list: Get \"https://2DE63831B1AE9EC847781E7DA59CCC6E.yl4.ap-northeast-2.eks.amazonaws.com/api?timeout=32s\": dial tcp: lookup 2DE63831B1AE9EC847781E7DA59CCC6E.yl4.ap-northeast-2.eks.amazonaws.com: no such host"
Unable to connect to the server: dial tcp: lookup 2DE63831B1AE9EC847781E7DA59CCC6E.yl4.ap-northeast-2.eks.amazonaws.com: no such host
```

**원인**

kubeconfig가 잘못된 클러스터를 가리키고 있음: `~/.kube/config` 파일이 존재하지 않거나, 오래된 EKS 클러스터 정보를 가리키고 있을 수 있음

**해결**

`~/.kube/config` 파일이 현재 EKS 클러스터 정보를 가리키도록 업데이트

```bash
aws eks update-kubeconfig --region ap-northeast-2 --name langfuse
```

![image](https://github.com/user-attachments/assets/0787851b-6403-42aa-a040-12e194092495)


### #2: Fargate 노드가 **스케줄되지 못함**

**문제 상황**

EKS에서 `CoreDNS` Pod가 `Pending` 상태로 멈춰 있음
![image](https://github.com/user-attachments/assets/ff4d8cd7-5a0d-428b-9fae-26d7a73a1ee5)

`kubectl get nodes` 명령어로 노드가 표시되지 않고, `nodeSelector` 값이 `null`로 출력됨

![image](https://github.com/user-attachments/assets/8e6cd8b2-17fb-4f4a-aac2-398ef86c4f2d)


**원인**

EKS Fargate는 명시적 요청을 하지 않으면 스케줄되지 않음

**해결**

1. `kube-system` 네임스페이스의 `CoreDNS`가 Fargate에서 실행되도록 설정

```hcl
# eks.tf
# Fargate Profiles for all configured namespaces
resource "aws_eks_fargate_profile" "namespaces" {
  for_each = toset(var.fargate_profile_namespaces)

  cluster_name           = aws_eks_cluster.langfuse.name
  fargate_profile_name   = "${var.name}-${each.value}"
  pod_execution_role_arn = aws_iam_role.fargate.arn
  subnet_ids             = module.vpc.private_subnets

	## AS-IS
  #selector {
  #  namespace = each.value
  #}
  
  ## TO-BE: kube-system 네임스페이스에서 CoreDNS가 Fargate에서 실행하도록 설정
  dynamic "selector" {
    for_each = each.value == "kube-system" ? [1] : []

    content {
      namespace = "kube-system"
      labels = {
        "k8s-app" = "kube-dns"
      }
    }
  }

  dynamic "selector" {
    for_each = each.value != "kube-system" ? [each.value] : []

    content {
      namespace = each.value
    }
  }

  tags = {
    Name = local.tag_name
  }
}
```

2. `CoreDNS` deployment에 Fargate 실행을 위한 스펙 추가

```hcl
kubectl edit deployment coredns -n kube-system
```

```hcl
spec:
  template:
    spec:
      nodeSelector:
        eks.amazonaws.com/compute-type: fargate

      tolerations:
        - key: "eks.amazonaws.com/compute-type"
          operator: "Equal"
          value: "fargate"
          effect: "NoSchedule"

      # affinity 블록은 Fargate 스케줄링과 충돌 가능성이 있어 주석 처리
```

![image](https://github.com/user-attachments/assets/e181fe1b-962a-491d-b6a9-a85e1544ca78)


### #3: ALB Controller 파드가 Pending 상태

**문제 상황**

ALB Controller가 `Pending` 상태

![image](https://github.com/user-attachments/assets/be80a8cd-14f3-457f-8a07-cf246e4a263a)


**원인**

Fargate에서는 `aws-load-balancer-controller`를 지원하지 않기 때문에 EC2 기반 노드에서 실행되어야 함

**해결**

EC2 NodeGroup 추가해 기존 서비스들(`coredns`, `langfuse` 등)은 Fargate에, `aws-load-balancer-controller`는 EC2 기반 노드에 스케줄되도록 배치

```hcl
# eks.tf
resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.langfuse.name
  node_group_name = "${var.name}-nodegroup"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = module.vpc.private_subnets

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["t3.medium"]
  capacity_type  = "ON_DEMAND"

  tags = {
    Name = "${local.tag_name} NodeGroup"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node,
    aws_iam_role_policy_attachment.eks_cni,
    aws_iam_role_policy_attachment.eks_registry
  ]
}

resource "aws_iam_role" "eks_node" {
  name = "${var.name}-eks-node"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${local.tag_name} EKS Node"
  }
}

resource "aws_iam_role_policy_attachment" "eks_worker_node" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node.name
}

resource "aws_iam_role_policy_attachment" "eks_cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node.name
}

resource "aws_iam_role_policy_attachment" "eks_registry" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node.name
}
```

### #4: langfuse-web 파드가 CrashLoopBackOff 상태

**문제 상황**

langfuse-web 파드가 `CrashLoopBackOff` 상태

![image](https://github.com/user-attachments/assets/78e2b702-67a2-42d3-9b5c-b749d0d310b6)


**원인**

`langfuse-web`이 ClickHouse DB 주소인 `langfuse-clickhouse`를 DNS로 찾지 못하고 있음

Langfuse가 기대하는 ClickHouse 주소가 `langfuse-clickhouse`인데, Helm chart 내에서는 `sharded` 구조로 설치되어 `langfuse-clickhouse-shard0`이라는 이름으로 생성되어 있음

```bash
kubectl logs -n langfuse langfuse-web-***

Script executed successfully.
Prisma schema loaded from packages/shared/prisma/schema.prisma
Datasource "db": PostgreSQL database "langfuse", schema "public" at "langfuse-postgres.cluster-cdu0isg4sttg.ap-northeast-2.rds.amazonaws.com:5432"

310 migrations found in prisma/migrations

No pending migrations to apply.
**error: failed to open database: dial tcp: lookup langfuse-clickhouse on 172.20.0.10:53: no such host in line 0: SHOW TABLES FROM "default" LIKE 'schema_migrations'**
Applying clickhouse migrations failed. This is mostly caused by the database being unavailable.
```

**해결**

1. Headless Service 명시적으로 추가

Langfuse Helm chart가 Headless Service를 생성하지 않기 때문에, 수동으로 생성

```hcl
# langfuse-clickhouse-headless.yaml
apiVersion: v1
kind: Service
metadata:
  name: langfuse-clickhouse-shard0
  namespace: langfuse
spec:
  clusterIP: None
  selector:
    app.kubernetes.io/name: clickhouse
    app.kubernetes.io/instance: langfuse
  ports:
    - name: native
      port: 9000
      targetPort: 9000
```

2. clickhouse host에 정확한 서비스명 명시

```hcl
# langfuse.tf
clickhouse:
  host: langfuse-clickhouse-shard0.langfuse # 추가
  auth:
    existingSecret: langfuse
    existingSecretKey: clickhouse-password
```
