resource "kubernetes_cluster_role" "eks_console_dashboard_read_only" {
  metadata {
    name = "eks-console-dashboard-read-only"
  }

  rule {
    api_groups = ["*"]
    resources  = ["*"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "eks_console_dashboard_read_only_binding" {
  metadata {
    name = "eks-console-dashboard-read-only"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "eks-console-dashboard-read-only"
  }

  subject {
    kind      = "Group"
    name      = "eks-console-dashboard-read-only"
    api_group = "rbac.authorization.k8s.io"
  }

  depends_on = [kubernetes_cluster_role.eks_console_dashboard_read_only]
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
      }],
      [for role_arn in var.eks_reader_roles : {
        rolearn  = role_arn
        username = role_arn
        groups = [
          "eks-console-dashboard-read-only"
        ]
        }
      ]
    ))
  }

  depends_on = [kubernetes_cluster_role_binding.eks_console_dashboard_read_only_binding]
}

