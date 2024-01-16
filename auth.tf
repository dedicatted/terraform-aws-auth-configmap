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