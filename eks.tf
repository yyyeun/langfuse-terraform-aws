data "aws_eks_cluster_auth" "langfuse" {
  name = aws_eks_cluster.langfuse.name
}

resource "aws_eks_cluster" "langfuse" {
  name     = var.name
  role_arn = aws_iam_role.eks.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = module.vpc.private_subnets
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids      = [aws_security_group.eks.id]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  tags = {
    Name = local.tag_name
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_service_policy,
    aws_cloudwatch_log_group.eks
  ]
}

# EC2 NodeGroup 추가
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

# Enable IRSA
resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.langfuse.identity[0].oidc[0].issuer

  tags = {
    Name = local.tag_name
  }
}

# Get EKS OIDC certificate
data "tls_certificate" "eks" {
  url = aws_eks_cluster.langfuse.identity[0].oidc[0].issuer
}

# Fargate Profile Role
resource "aws_iam_role" "fargate" {
  name = "${var.name}-fargate"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks-fargate-pods.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${local.tag_name} Fargate"
  }
}

resource "aws_iam_role_policy_attachment" "fargate_pod_execution_role_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.fargate.name
}

# Fargate Role에 권한 추가
resource "aws_iam_role_policy_attachment" "fargate_cni" {
  role       = aws_iam_role.fargate.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# Fargate Profiles for all configured namespaces
resource "aws_eks_fargate_profile" "namespaces" {
  for_each = toset(var.fargate_profile_namespaces)

  cluster_name           = aws_eks_cluster.langfuse.name
  fargate_profile_name   = "${var.name}-${each.value}"
  pod_execution_role_arn = aws_iam_role.fargate.arn
  subnet_ids             = module.vpc.private_subnets

  #selector {
  #  namespace = each.value
  #}
  # kube-system 네임스페이스에서 CoreDNS만 Fargate에서 실행하도록 제한
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

resource "aws_security_group" "eks" {
  name        = "${var.name}-eks"
  description = "Security group for Langfuse EKS cluster"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name = "${local.tag_name} EKS"
  }
}

resource "aws_security_group_rule" "eks_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks.id
}

resource "aws_security_group_rule" "eks_vpc" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = [module.vpc.vpc_cidr_block]
  security_group_id = aws_security_group.eks.id
}

resource "aws_iam_role" "eks" {
  name = "${var.name}-eks"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${local.tag_name} EKS"
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks.name
}

resource "aws_iam_role_policy_attachment" "eks_service_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks.name
}

resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.name}/cluster"
  retention_in_days = 30
} 