################################################################################
# VPC Module
# reference: https://github.com/terraform-aws-modules/terraform-aws-vpc
################################################################################
module "vpc" {
  source     = "terraform-aws-modules/vpc/aws"
  version    = "5.13.0"
  create_vpc = var.enable_vpc

  # Details
  name                = "vpc-${var.service}-${var.environment}"
  cidr                = var.cidr
  azs                 = local.azs
  public_subnets      = var.public_subnets
  private_subnets     = var.private_subnets
  intra_subnets       = var.endpoint_subnets
  database_subnets    = var.database_subnets
  elasticache_subnets = var.elb_subnets
  redshift_subnets    = var.tgw_attach_subnets

  manage_default_route_table    = false
  manage_default_network_acl    = false
  manage_default_security_group = false
  manage_default_vpc            = false

  # Tag subnets
  public_subnet_names      = ["sub-${var.service}-${var.environment}-pub-a", "sub-${var.service}-${var.environment}-pub-c"]
  private_subnet_names     = ["sub-${var.service}-${var.environment}-pri-a", "sub-${var.service}-${var.environment}-pri-c"]
  database_subnet_names    = ["sub-${var.service}-${var.environment}-db-a", "sub-${var.service}-${var.environment}-db-c"]
  intra_subnet_names       = ["sub-${var.service}-${var.environment}-ep-a", "sub-${var.service}-${var.environment}-ep-c"]
  elasticache_subnet_names = ["sub-${var.service}-${var.environment}-elb-a", "sub-${var.service}-${var.environment}-elb-c"]
  redshift_subnet_names    = ["sub-${var.service}-${var.environment}-tgw-a", "sub-${var.service}-${var.environment}-tgw-c"]

  # Routing
  create_database_subnet_route_table    = true
  create_elasticache_subnet_route_table = true
  create_redshift_subnet_route_table    = true

  # Tag route table
  public_route_table_tags      = { "Name" : "route-${var.service}-${var.environment}-pub" }
  private_route_table_tags     = { "Name" : "route-${var.service}-${var.environment}-pri" }
  database_route_table_tags    = { "Name" : "route-${var.service}-${var.environment}-db" }
  intra_route_table_tags       = { "Name" : "route-${var.service}-${var.environment}-ep" }
  elasticache_route_table_tags = { "Name" : "route-${var.service}-${var.environment}-elb" }
  redshift_route_table_tags    = { "Name" : "route-${var.service}-${var.environment}-tgw" }

  igw_tags = { "Name" : "igw-${var.service}-${var.environment}" }

  # NAT Gateways - Outbound Communication
  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway
  nat_gateway_tags   = { "Name" : "nat-${var.service}-${var.environment}" }
  nat_eip_tags       = { "Name" : "eip-${var.service}-${var.environment}" }

  create_database_subnet_group = true
  database_subnet_group_name   = "rdssg-${var.service}-${var.environment}"
  database_subnet_group_tags   = { "Name" = "rdssg-${var.service}-${var.environment}" }

  # DNS Parameters in VPC
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Flow logs
  enable_flow_log                       = var.enable_vpc_flow_log
  flow_log_destination_type             = "s3"
  flow_log_destination_arn              = var.vpc_flow_log_s3_arn
  flow_log_max_aggregation_interval     = 600
  vpc_flow_log_iam_role_name            = "role-${var.service}-${var.environment}-vpc-flow-log"
  vpc_flow_log_iam_role_use_name_prefix = false
  create_flow_log_cloudwatch_log_group  = true
  create_flow_log_cloudwatch_iam_role   = true

  vpc_flow_log_tags = merge(
    local.tags,
    {
      "Name" = "vpc-${var.service}-${var.environment}-flow-logs"
    }
  )

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    # Tags subnets for Karpenter auto-discovery
    "karpenter.sh/discovery" = "eks-${var.service}-${var.environment}"
  }

  # tags for the VPC
  tags = {
    owners      = local.owners
    environment = "dev"
    service     = local.service
  }
}

# S3 Bucket
# module "s3_bucket" {
#   source  = "terraform-aws-modules/s3-bucket/aws"
#   version = "~> 3.0"

#   bucket        = local.s3_bucket_name
#   policy        = data.aws_iam_policy_document.flow_log_s3.json
#   force_destroy = true

#   tags = local.tags
# }

# data "aws_iam_policy_document" "flow_log_s3" {
#   statement {
#     sid = "AWSLogDeliveryWrite"

#     principals {
#       type        = "Service"
#       identifiers = ["delivery.logs.amazonaws.com"]
#     }

#     actions = ["s3:PutObject"]

#     resources = ["arn:aws:s3:::${local.s3_bucket_name}/AWSLogs/*"]
#   }

#   statement {
#     sid = "AWSLogDeliveryAclCheck"

#     principals {
#       type        = "Service"
#       identifiers = ["delivery.logs.amazonaws.com"]
#     }

#     actions = ["s3:GetBucketAcl"]

#     resources = ["arn:aws:s3:::${local.s3_bucket_name}"]
#   }
# }

# Fully private cluster only
module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 5.13.0"

  vpc_id = module.vpc.vpc_id

  # Security group
  create_security_group      = true
  security_group_name        = "scg-${var.service}-${var.environment}-endpoint"
  security_group_description = "VPC endpoint security group"
  security_group_rules = {
    ingress_https = {
      description = "HTTPS from VPC"
      cidr_blocks = [module.vpc.vpc_cidr_block]
    }
  }
  security_group_tags = merge(
    local.tags,
    { "Name" = "scg-${var.service}-${var.environment}-endpoint"
  })

  endpoints = merge({
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = module.vpc.private_route_table_ids
      tags = merge(
        local.tags,
      { Name = "ep-${var.service}-${var.environment}-gw-s3" })
    }
    },
    #   { for service in toset(["autoscaling", "ecr.api", "ecr.dkr", "ec2", "ec2messages", "elasticloadbalancing", "sts", "kms", "logs", "ssm", "ssmmessages"]) :
    #     replace(service, ".", "_") =>
    #     {
    #       service             = service
    #       subnet_ids          = module.vpc.infra_subnets
    #       private_dns_enabled = true
    #       tags = merge(
    #         local.tags,
    #       { Name = "$ep-${var.service}-${var.environment}-${service}" })
    #     }
    # }
  )
}
