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

  vpc_id = module.vpc.vpc_id
  # subnet_ids               = module.vpc.private_subnets
  # Sandbox, Dev, Staging Only!!
  subnet_ids               = [element(module.vpc.private_subnets, 0)]
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
      name            = "eksng-${var.environment}-mgmt"
      use_name_prefix = false
      instance_types  = ["t4g.medium"]
      capacity_type   = "ON_DEMAND"

      lanch_template_name             = "ekslt-${var.environment}-mgmt"
      launch_template_use_name_prefix = false

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
    },
    app = {
      # Starting on 1.30, AL2023 is the default AMI type for EKS managed node groups
      ami_type        = "AL2023_ARM_64_STANDARD"
      name            = "eksng-${var.environment}-app"
      use_name_prefix = false
      instance_types  = ["c7g.2xlarge"]
      capacity_type   = "ON_DEMAND"

      lanch_template_name             = "ekslt-${var.environment}-app"
      launch_template_use_name_prefix = false

      min_size     = 0
      max_size     = 2
      desired_size = 0

      labels = {
        node_type = "app"
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