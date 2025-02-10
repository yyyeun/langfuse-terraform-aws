![GitHub Banner](https://github.com/langfuse/langfuse-k8s/assets/2834609/2982b65d-d0bc-4954-82ff-af8da3a4fac8)

# Langfuse Cloud Deployment

This repository contains Infrastructure as Code (IaC) configurations for deploying [Langfuse](https://langfuse.com/) - the open-source LLM observability platform - on major cloud providers. The goal is to provide production-ready, secure, and scalable deployment configurations using managed services whenever possible.

## Repository Structure

```
.
├── aws/                    # AWS Terraform configurations
│   ├── eks.tf             # EKS cluster configuration
│   └── ...               # Other AWS resources
├── gcp/                   # Google Cloud Platform configurations
│   ├── gke.tf            # GKE cluster setup
│   └── ...               # Other GCP resources
├── azure/                 # Azure configurations
│   ├── aks.tf            # AKS cluster setup
│   └── ...               # Other Azure resources
├── values/               # Helm values for different cloud providers
│   ├── aws.yaml   # AWS-specific Helm values
│   ├── gcp.yaml   # GCP-specific Helm values
│   └── azure.yaml # Azure-specific Helm values
└── docs/                  # Detailed documentation
    ├── aws.md            # AWS-specific setup guide
    ├── gcp.md            # GCP-specific setup guide
    └── azure.md          # Azure-specific setup guide
```

## Deployment Options

### AWS Deployment (Coming Soon)

The AWS deployment utilizes the following managed services:
- Amazon EKS for Kubernetes orchestration
- Amazon RDS Aurora Serverless v2 for PostgreSQL
- Amazon ElastiCache for Redis
- AWS CloudWatch for logging and monitoring

### GCP Deployment (Coming Soon)

Planned managed services:
- Google Kubernetes Engine (GKE)
- Cloud SQL for PostgreSQL
- Cloud Memorystore for Redis
- Cloud Logging and Monitoring

### Azure Deployment (Coming Soon)

Planned managed services:
- Azure Kubernetes Service (AKS)
- Azure Database for PostgreSQL
- Azure Cache for Redis
- Azure Monitor for logging and monitoring

## Prerequisites

- Terraform >= 1.0
- kubectl
- Cloud provider CLI tools (aws-cli, gcloud, az)
- Helm >= 3.0

## Quick Start

1. Clone this repository
2. Choose your cloud provider directory
3. Configure your cloud credentials
4. Apply the Terraform configuration
5. Deploy Langfuse using Helm with the provided values file:
   ```bash
   # For AWS
   helm install langfuse langfuse/langfuse -f values/aws-values.yaml
   
   # For GCP
   helm install langfuse langfuse/langfuse -f values/gcp-values.yaml
   
   # For Azure
   helm install langfuse langfuse/langfuse -f values/azure-values.yaml
   ```

## Kubernetes Deployment

This repository focuses on the cloud infrastructure setup. For the actual Langfuse Kubernetes deployment, we use the official [Langfuse Kubernetes Helm Chart](https://github.com/langfuse/langfuse-k8s).

The Helm chart provides:
- Production-ready defaults
- Horizontal scaling configuration
- Ingress configuration
- Monitoring setup
- Database migrations

### Helm Values

We provide ready-to-use values files for each cloud provider in the `values/` directory. These files are pre-configured to:
- Use cloud-native managed services
- Set up appropriate connection strings
- Configure monitoring and logging
- Enable recommended security settings
- Set resource requests/limits based on provider recommendations

You can customize these values files based on your specific needs. Common customizations include:
- Adjusting replica counts
- Modifying resource limits
- Configuring custom domains
- Setting up additional monitoring

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. Here are some ways you can contribute:
- Add support for new cloud providers
- Improve existing configurations
- Add monitoring and alerting templates
- Improve documentation
- Report issues

## Support

- [Langfuse Documentation](https://langfuse.com/docs)
- [Langfuse GitHub](https://github.com/langfuse/langfuse)
- [Join Langfuse Discord](https://langfuse.com/discord)

## License

MIT License - see LICENSE file for details
