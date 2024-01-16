# Terraform Module: terraform-aws-auth-configmap
# This module facilitates the creation of AWS EKS cluster with aws-auth configmap to provide console access to eks cluster resources

## Overview
The `terraform-aws-auth-configmap` module includes examples to easily deploy AWS EKS using official Terraform module as a source and aws-auth configmap to manage access to eks cluster resources. 

## Usage

```hcl
data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source             = "github.com/terraform-aws-modules/terraform-aws-vpc"
  name               = var.vpc_name
  cidr               = var.cidr_block
  azs                = slice(data.aws_availability_zones.available.names, 0, 3)
  public_subnets     = [cidrsubnet(var.cidr_block, 8, 3), cidrsubnet(var.cidr_block, 8, 4), cidrsubnet(var.cidr_block, 8, 5)]
  private_subnets    = [cidrsubnet(var.cidr_block, 8, 0), cidrsubnet(var.cidr_block, 8, 1), cidrsubnet(var.cidr_block, 8, 2)]
  enable_nat_gateway = true
  single_nat_gateway = true
  public_subnet_tags = {
    "kubernetes.io/cluster/demo-cluster" = "shared"
    "kubernetes.io/role/elb"             = 1
  }
  private_subnet_tags = {
    "kubernetes.io/cluster/demo-cluster" = "shared"
    "kubernetes.io/role/internal-elb"    = 1
  }
}

module "eks" {
  source                         = "github.com/terraform-aws-modules/terraform-aws-eks"
  cluster_name                   = "demo-cluster"
  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  control_plane_subnet_ids       = module.vpc.public_subnets
  create_kms_key                 = true
  cluster_endpoint_public_access = true
  eks_managed_node_groups = {
    one = {
      name = "node-group-1"

      instance_types = ["t3.micro"]

      min_size     = 1
      max_size     = 1
      desired_size = 1
    }
  }
}
```

aws-auth configuration part
```hcl
data "aws_caller_identity" "current" {}

locals {
  default_admin = {
    userarn  = data.aws_caller_identity.current.arn
    username = "terraform"
    groups   = ["system:masters"]
  }
}

resource "kubernetes_config_map_v1_data" "aws_auth" {
  force = true

  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode(concat(
      [for ng_name, ng_data in module.eks.eks_managed_node_groups : {
        rolearn  = ng_data.iam_role_arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups   = ["system:bootstrappers", "system:nodes"]
      }]
    ))
    mapUsers = yamlencode(concat(
      [for admin in var.eks_admins : {
        userarn  = admin.userarn
        username = admin.username
        groups   = admin.groups
      }],
      [local.default_admin]
    ))
  }

  depends_on = [module.eks]
}
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.47 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.10 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.31.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.25.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_eks"></a> [eks](#module\_eks) | github.com/terraform-aws-modules/terraform-aws-eks | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | github.com/terraform-aws-modules/terraform-aws-vpc | n/a |

## Resources

| Name | Type |
|------|------|
| [kubernetes_cluster_role.eks_console_dashboard_read_only](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role) | resource |
| [kubernetes_cluster_role_binding.eks_console_dashboard_read_only_binding](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_binding) | resource |
| [kubernetes_config_map_v1_data.aws_auth](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map_v1_data) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_eks_cluster_auth.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster_auth) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cidr_block"></a> [cidr\_block](#input\_cidr\_block) | CIDR block for the VPC. | `string` | `"10.10.0.0/16"` | no |
| <a name="input_eks_reader_roles"></a> [eks\_reader\_roles](#input\_eks\_reader\_roles) | List of user maps to add to the aws-auth configmap. | `list(any)` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region to deploy. | `string` | `"us-east-1"` | no |
| <a name="input_vpc_name"></a> [vpc\_name](#input\_vpc\_name) | Name for the VPC. | `string` | `"eks-vpc"` | no |

## Outputs

No outputs.
