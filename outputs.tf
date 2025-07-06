output "cluster_name" {
  description = "EKS Cluster Name to use for a Kubernetes terraform provider"
  value       = aws_eks_cluster.langfuse.name
}

output "cluster_host" {
  description = "EKS Cluster host to use for a Kubernetes terraform provider"
  value       = aws_eks_cluster.langfuse.endpoint
}

output "cluster_ca_certificate" {
  description = "EKS Cluster CA certificate to use for a Kubernetes terraform provider"
  value       = base64decode(aws_eks_cluster.langfuse.certificate_authority[0].data)
  sensitive   = true
}

output "cluster_token" {
  description = "EKS Cluster Token to use for a Kubernetes terraform provider"
  value       = data.aws_eks_cluster_auth.langfuse.token
  sensitive   = true
}
