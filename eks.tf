################################################################################
# EKS Module
# reference: https://github.com/terraform-aws-modules/terraform-aws-eks
#            https://github.com/aws-ia/terraform-aws-eks-blueprints
#            https://github.com/aws-ia/terraform-aws-eks-blueprints-addon
################################################################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.11"
  create  = var.enable_cluster

  # TO-DO 클러스터 Secret 암호화 적용 확인
  create_kms_key                = false
  enable_kms_key_rotation       = false
  kms_key_enable_default_policy = false
  cluster_encryption_config     = {}

  cluster_name                     = "eks-${var.service}-${var.environment}"
  cluster_version                  = var.cluster_version
  attach_cluster_encryption_policy = false

  # Gives Terraform identity admin access to cluster which will
  # allow deploying resources (Karpenter) into the cluster
  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions
  cluster_endpoint_public_access           = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs     = ["0.0.0.0/0"]
  cluster_security_group_name              = "scg-${var.service}-${var.environment}-cluster"
  cluster_security_group_description       = "EKS cluster security group"
  cluster_security_group_use_name_prefix   = false
  cluster_security_group_tags              = { "Name" = "scg-${var.service}-${var.environment}-cluster" }

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    eks-pod-identity-agent = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      # Specify the VPC CNI addon should be deployed before compute to ensure
      # the addon is configured before data plane compute resources are created
      # See README for further details
      before_compute = true
      most_recent    = true
      timeout = {
        create = "25m"
        delete = "10m"
      }
      configuration_values = jsonencode({
        env = {
          # Reference docs https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
        # Network Policy
        enableNetworkPolicy : "true",
      })
    }
    # aws-ebs-csi-driver = {
    #   most_recent = true
    # }
    aws-efs-csi-driver = {
      most_recent = true
    }
    aws-mountpoint-s3-csi-driver = {
      most_recent = true
    }
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  node_security_group_name            = "scg-${var.service}-${var.environment}-node"
  node_security_group_description     = "EKS node security group"
  node_security_group_use_name_prefix = false
  node_security_group_tags = {
    # NOTE - if creating multiple security groups with this module, only tag the
    # security group that Karpenter should utilize with the following tag
    # (i.e. - at most, only one security group should have this tag in your account)
    "karpenter.sh/discovery" = "eks-${var.service}-${var.environment}",
    "Name"                   = "scg-${var.service}-${var.environment}-node"
  }

  eks_managed_node_groups = {
    management = {
      # Starting on 1.30, AL2023 is the default AMI type for EKS managed node groups
      ami_type        = "AL2023_ARM_64_STANDARD"
      instance_types  = ["t4g.medium"]
      name            = "eksng-${var.environment}-mgmt"
      use_name_prefix = false

      min_size     = 1
      max_size     = 2
      desired_size = 1

      taints = {
        # This Taint aims to keep just EKS Addons and Karpenter running on this MNG
        # The pods that do not tolerate this taint should run on nodes created by Karpenter
        addons = {
          key    = "CriticalAddonsOnly"
          effect = "NO_SCHEDULE"
        },
      }
    }
  }

  #  EKS K8s API cluster needs to be able to talk with the EKS worker nodes with port 15017/TCP and 15012/TCP which is used by Istio
  #  Istio in order to create sidecar needs to be able to communicate with webhook and for that network passage to EKS is needed.
  node_security_group_additional_rules = {
    ingress_15017 = {
      description                   = "Cluster API - Istio Webhook namespace.sidecar-injector.istio.io"
      protocol                      = "TCP"
      from_port                     = 15017
      to_port                       = 15017
      type                          = "ingress"
      source_cluster_security_group = true
    }
    ingress_15012 = {
      description                   = "Cluster API to nodes ports/protocols"
      protocol                      = "TCP"
      from_port                     = 15012
      to_port                       = 15012
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }

  tags = merge(
    local.tags,
    {
      "Name" = "eks-${var.service}-${var.environment}"
    }
  )
}

# output "configure_kubectl" {
#   description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
#   value       = "aws eks --region ${local.region} update-kubeconfig --name ${module.eks.cluster_name}"
# }

################################################################################
# Karpenter
################################################################################
# module "karpenter" {
#   source  = "terraform-aws-modules/eks/aws//modules/karpenter"
#   version = "20.19.0"
#   create = true

#   cluster_name = module.eks.cluster_name

#   enable_pod_identity             = true
#   create_pod_identity_association = true

#   # Used to attach additional IAM policies to the Karpenter node IAM role
#   node_iam_role_additional_policies = {
#     AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
#   }

#   tags = local.tags
# }

# ################################################################################
# # Karpenter Helm chart & manifests
# # Not required; just to demonstrate functionality of the sub-module
# ################################################################################
# resource "helm_release" "karpenter" {
#   namespace           = "kube-system"
#   name                = "karpenter"
#   repository          = "oci://public.ecr.aws/karpenter"
#   repository_username = data.aws_ecrpublic_authorization_token.token.user_name
#   repository_password = data.aws_ecrpublic_authorization_token.token.password
#   chart               = "karpenter"
#   version             = "1.0.0"
#   wait                = false

#   values = [
#     <<-EOT
#     serviceAccount:
#       name: ${module.karpenter.service_account}
#     settings:
#       clusterName: ${module.eks.cluster_name}
#       clusterEndpoint: ${module.eks.cluster_endpoint}
#       interruptionQueue: ${module.karpenter.queue_name}
#     EOT
#   ]
# }

# ################################################################################
# # Metrics Server
# ################################################################################
# resource "helm_release" "metrics_server" {
#   count      = var.enable_cluster_creator_addon ? 1 : 0
#   name       = "metrics-server"
#   repository = "https://kubernetes-sigs.github.io/metrics-server/"
#   chart      = "metrics-server"
#   namespace  = "kube-system"

#   # values = [
#   #   <<EOF
#   #   args:
#   #     - --kubelet-insecure-tls
#   #   EOF
#   # ]

#   set {
#     name  = "replicas"
#     value = "1"
#   }

#   set {
#     name = "tolerations[0].key"
#     value = "CriticalAddonsOnly"
#   }

#   set {
#     name = "tolerations[0].operator"
#     value = "Exists"
#   }

#   set {
#     name = "tolerations[0].effect"
#     value = "NoSchedule" 
#   }
# }

################################################################################
# AWS Load Balancer Controller IRSA
################################################################################
module "aws_load_balancer_controller_role" {
  source      = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  create_role = var.enable_cluster

  role_name                              = "role-aws-load-balancer-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
  tags = merge(
    local.tags,
    {
      "Name" = "role-aws-load-balancer-controller"
    }
  )
}

# resource "kubernetes_service_account" "service-account" {
#   metadata {
#     name      = "aws-load-balancer-controller"
#     namespace = "kube-system"
#     labels = {
#       "app.kubernetes.io/name"      = "aws-load-balancer-controller"
#       "app.kubernetes.io/component" = "controller"
#     }
#     annotations = {
#       "eks.amazonaws.com/role-arn"               = module.aws_load_balancer_controller_role.iam_role_arn
#       "eks.amazonaws.com/sts-regional-endpoints" = "true"
#     }
#   }
# }

# data "aws_iam_policy_document" "alb_controller_assume_role" {
#   statement {
#     actions = ["sts:AssumeRole"]
#     principals {
#       type        = "Service"
#       identifiers = ["eks.amazonaws.com"]
#     }
#   }
# }

# resource "aws_iam_role" "alb_controller_role" {
#   name               = "eks-alb-controller-role"
#   assume_role_policy = data.aws_iam_policy_document.alb_controller_assume_role.json
# }

# resource "aws_iam_policy" "alb_controller_policy" {
#   name        = "alb-controller-policy"
#   path        = "/"
#   description = "Policy for the AWS Load Balancer Controller"

#   policy = data.aws_iam_policy_document.alb_controller_policy.json
# }

# resource "aws_iam_role_policy_attachment" "alb_controller_policy_attachment" {
#   role       = aws_iam_role.alb_controller_role.name
#   policy_arn = aws_iam_policy.alb_controller_policy.arn
# }

# module "aws_load_balancer_controller_irsa_role" {
#   count = var.enable_cluster_creator_addon ? 1 : 0
#   source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
#   role_name = "aws-load-balancer-controller"
#   create_role = var.enable_cluster_creator_addon

#   attach_load_balancer_controller_policy = true

#   oidc_providers = {
#     ex = {
#       provider_arn               = module.eks.oidc_provider_arn
#       namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
#     }
#   }
# }

# resource "helm_release" "aws_load_balancer_controller" {
#   count      = var.enable_cluster_creator_addon ? 1 : 0
#   name = "aws-load-balancer-controller"
#   repository = "https://aws.github.io/eks-charts"
#   chart      = "aws-load-balancer-controller"
#   namespace  = "kube-system"
#   depends_on = [ module.aws_load_balancer_controller_irsa_role ]

#   set {
#     name  = "replicaCount"
#     value = 1
#   }

#   set {
#     name  = "clusterName"
#     value = module.eks.cluster_name
#   }

#   set {
#     name  = "serviceAccount.create"
#     value = false
#   }

#   set {
#     name  = "serviceAccount.name"
#     value = "aws-load-balancer-controller"
#   }

#   # set {
#   #   name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
#   #   value = module.aws_load_balancer_controller_irsa_role.iam_role_arn
#   # }

#   set {
#     name  = "tolerations[0].key"
#     value = "CriticalAddonsOnly"
#   }

#   set {
#     name  = "tolerations[0].operator"
#     value = "Exists"
#   }

#   set {
#     name  = "tolerations[0].effect"
#     value = "NoSchedule" 
#   }
# }


# resource "helm_release" "alb-controller" {
#   name       = "aws-load-balancer-controller"
#   repository = "https://aws.github.io/eks-charts"
#   chart      = "aws-load-balancer-controller"
#   namespace  = "kube-system"
#   depends_on = [
#     kubernetes_service_account.service-account
#   ]

#   set {
#     name  = "region"
#     value = var.region
#   }

#   set {
#     name  = "vpcId"
#     value = module.vpc.vpc_id
#   }

#   set {
#     name  = "serviceAccount.create"
#     value = "false"
#   }

#   set {
#     name  = "serviceAccount.name"
#     value = "aws-load-balancer-controller"
#   }

#   set {
#     name  = "clusterName"
#     value = module.eks.cluster_name
#   }

#   set {
#     name  = "tolerations[0].key"
#     value = "CriticalAddonsOnly"
#   }

#   set {
#     name  = "tolerations[0].operator"
#     value = "Exists"
#   }

#   set {
#     name  = "tolerations[0].effect"
#     value = "NoSchedule" 
#   }
# }
