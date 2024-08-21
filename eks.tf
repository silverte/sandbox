################################################################################
# EKS Module
# reference: https://github.com/terraform-aws-modules/terraform-aws-eks
#            https://github.com/aws-ia/terraform-aws-eks-blueprints
#            https://github.com/aws-ia/terraform-aws-eks-blueprints-addon
################################################################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.11"
  create = true

  cluster_name    = "eks-${var.service}-${var.environment}"
  cluster_version = var.cluster_version

  # Gives Terraform identity admin access to cluster which will
  # allow deploying resources (Karpenter) into the cluster
  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions
  cluster_endpoint_public_access           = var.cluster_endpoint_public_access

  cluster_addons = {
    coredns                      = {
      most_recent = true
    }
    eks-pod-identity-agent       = {
      most_recent = true
    }
    kube-proxy                   = {
      most_recent = true
    }
    vpc-cni                      = {
      # Specify the VPC CNI addon should be deployed before compute to ensure
      # the addon is configured before data plane compute resources are created
      # See README for further details
      before_compute = true
      most_recent = true
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
        enableNetworkPolicy: "true",
      })
    }
    # aws-ebs-csi-driver         = {}
    aws-efs-csi-driver           = {
      most_recent = true
    }
    aws-mountpoint-s3-csi-driver = {
      most_recent = true
    }
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  eks_managed_node_groups = {
    management = {
      # Starting on 1.30, AL2023 is the default AMI type for EKS managed node groups
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3a.large"]

      min_size     = 1
      max_size     = 2
      desired_size = 1

      taints = {
        # This Taint aims to keep just EKS Addons and Karpenter running on this MNG
        # The pods that do not tolerate this taint should run on nodes created by Karpenter
        addons = {
          key    = "CriticalAddonsOnly"
          value  = "Exists"
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

  # access_entries = {
  #   # One access entry with a policy associated
  #   example = {
  #     kubernetes_groups = ["admins"]
  #     principal_arn     = "arn:aws:iam::533616270150:role/role-silverte-admin"

  #     policy_associations = {
  #       example = {
  #         policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSFullAccessPolicy"
  #         access_scope = {
  #           type       = "cluster"
  #         }
  #       }
  #     }
  #   }
  # }

  node_security_group_tags = merge(local.tags, {
    # NOTE - if creating multiple security groups with this module, only tag the
    # security group that Karpenter should utilize with the following tag
    # (i.e. - at most, only one security group should have this tag in your account)
    "karpenter.sh/discovery" = "eks-${var.service}-${var.environment}"
  })

  tags = local.tags
}

output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = "aws eks --region ${local.region} update-kubeconfig --name ${module.eks.cluster_name}"
}

################################################################################
# EKS Blueprints Addons
################################################################################

module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.16"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  enable_metrics_server = true
  metrics_server = {
    values = [
      yamlencode({
        "tolerations" = [
          {
            "key"      = "CriticalAddonsOnly"
            "operator" = "Exists"
            "effect"   = "NoSchedule"
          }
        ]
      })
    ]
  }

  # This is required to expose Istio Ingress Gateway
  enable_aws_load_balancer_controller = true
  aws_load_balancer_controller = {
    values = [
      yamlencode({
        "tolerations" = [
          {
            "key"      = "CriticalAddonsOnly"
            "operator" = "Exists"
            "effect"   = "NoSchedule"
          }
        ]
      })
    ]
  }

  # AWS Addons
  enable_karpenter                             = true
  karpenter =  {
    values = [
      yamlencode({
        "tolerations" = [
          {
            "key"      = "CriticalAddonsOnly"
            "operator" = "Exists"
            "effect"   = "NoSchedule"
          }
        ]
      })
    ]
  }
  enable_cert_manager                          = false
  enable_aws_cloudwatch_metrics                = false
  enable_aws_privateca_issuer                  = false
  enable_cluster_autoscaler                    = false
  enable_external_dns                          = false
  enable_external_secrets                      = false
  enable_fargate_fluentbit                     = false
  enable_aws_for_fluentbit                     = false
  enable_aws_node_termination_handler          = false
  enable_velero                                = false
  enable_aws_gateway_api_controller            = false

  # OSS Addons
  enable_argocd                                = false
  enable_argo_rollouts                         = false
  enable_argo_events                           = false
  enable_argo_workflows                        = false
  enable_cluster_proportional_autoscaler       = false
  enable_gatekeeper                            = false
  #enable_gpu_operator                          = false
  enable_ingress_nginx                         = false
  #enable_kyverno                               = false
  enable_kube_prometheus_stack                 = false
  #enable_prometheus_adapter                    = false
  enable_secrets_store_csi_driver              = false
  enable_vpa                                   = false

  tags = local.tags
}

# ################################################################################
# # Karpenter
# ################################################################################
# module "karpenter" {
#   source  = "terraform-aws-modules/eks/aws//modules/karpenter"
#   version = "20.19.0"

#   cluster_name = module.eks.cluster_name

#   enable_pod_identity             = true
#   create_pod_identity_association = true

#   # Used to attach additional IAM policies to the Karpenter node IAM role
#   node_iam_role_additional_policies = {
#     AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
#   }

#   tags = local.tags
# }

# module "karpenter_disabled" {
#   source = "terraform-aws-modules/eks/aws//modules/karpenter"

#   create = false
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
#   version             = "0.37.0"
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

# resource "kubectl_manifest" "karpenter_node_class" {
#   yaml_body = <<-YAML
#     apiVersion: karpenter.k8s.aws/v1beta1
#     kind: EC2NodeClass
#     metadata:
#       name: default
#     spec:
#       amiFamily: AL2023
#       role: ${module.karpenter.node_iam_role_name}
#       subnetSelectorTerms:
#         - tags:
#             karpenter.sh/discovery: ${module.eks.cluster_name}
#       securityGroupSelectorTerms:
#         - tags:
#             karpenter.sh/discovery: ${module.eks.cluster_name}
#       tags:
#         karpenter.sh/discovery: ${module.eks.cluster_name}
#   YAML

#   depends_on = [
#     helm_release.karpenter
#   ]
# }

# resource "kubectl_manifest" "karpenter_node_pool" {
#   yaml_body = <<-YAML
#     apiVersion: karpenter.sh/v1beta1
#     kind: NodePool
#     metadata:
#       name: default
#     spec:
#       template:
#         spec:
#           nodeClassRef:
#             name: default
#           requirements:
#             - key: "karpenter.sh/capacity-type" 
#               operator: In
#               values: ["spot"]
#             - key: "karpenter.k8s.aws/instance-category"
#               operator: In
#               values: ["c", "m", "r"]
#             - key: "karpenter.k8s.aws/instance-cpu"
#               operator: In
#               values: ["4", "8", "16", "32"]
#             - key: "karpenter.k8s.aws/instance-hypervisor"
#               operator: In
#               values: ["nitro"]
#             - key: "karpenter.k8s.aws/instance-generation"
#               operator: Gt
#               values: ["2"]
#       limits:
#         cpu: 1000
#       disruption:
#         consolidationPolicy: WhenEmpty
#         consolidateAfter: 30s
#   YAML

#   depends_on = [
#     kubectl_manifest.karpenter_node_class
#   ]
# }