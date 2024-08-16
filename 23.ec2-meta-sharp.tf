################################################################################
# EC2 Module
################################################################################

module "ec2_meta_sharp" {
  source = "terraform-aws-modules/ec2-instance/aws"

  name = "ec2-${var.service}-meta-sharp-${var.environment}"

  ami                         = data.aws_ami.ec2_meta_sharp.id
  instance_type               = var.ec2_meta_sharp_instance_type
  availability_zone           = element(module.vpc.azs, 0)
  subnet_id                   = element(module.vpc.private_subnets, 0)
  vpc_security_group_ids      = [module.security_group_ec2_meta_sharp.security_group_id]
  associate_public_ip_address = false
  disable_api_stop            = false
  key_name                    = module.key_pair_meta_sharp.key_pair_name

  create_iam_instance_profile = true
  iam_role_description        = "IAM role for EC2 instance"
  iam_role_policies = {
    AdministratorAccess = "arn:aws:iam::aws:policy/AdministratorAccess"
  }

  # https://docs.aws.amazon.com/ko_kr/AWSEC2/latest/UserGuide/hibernating-prerequisites.html#hibernation-prereqs-supported-amis
  hibernation = false 
  user_data_base64            = base64encode(var.ec2_user_data)
  user_data_replace_on_change = true

  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 8
    instance_metadata_tags      = "enabled"
  }
  
  enable_volume_tags = false
  root_block_device = [
    {
      encrypted   = true
      volume_type = "gp3"
    #   throughput  = 200 # default: 125
      volume_size = var.ec2_meta_sharp_root_volume_size
      tags = {
        Name = "ec2-meta-sharp-root-block"
      }
    },
  ]

  ebs_block_device = [
    {
      device_name = "/dev/sdf"
      volume_type = "gp3"
      volume_size = var.ec2_meta_sharp_ebs_volume_size
    #   throughput  = 200 # default: 125
      encrypted   = true
      kms_key_id  = module.kms-ebs.key_arn
      tags = {
        Name = "ec2-meta-sharp-data-block"
        MountPoint = "/mnt/data"
      }
    }
  ]

  tags = merge(
    local.tags,
    {
      "Name" = "ec2-${var.service}-meta-sharp-${var.environment}"
    },
  )
}

module "security_group_ec2_meta_sharp" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "scg-${var.service}-meta-sharp-${var.environment}"
  description = "Security group for EC2 Nexus"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp", "all-icmp"]
  egress_rules        = ["all-all"]

  tags = merge(
    local.tags,
    {
      "Name" = "scg-${var.service}-meta-sharp-${var.environment}"
    },
  )
}

data "aws_ami" "ec2_meta_sharp" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = [var.ec2_meta_sharp_ami_filter_value]
  }
}

module "key_pair_meta_sharp" {
  source = "terraform-aws-modules/key-pair/aws"

  key_name           = "key-${var.service}-meta-sharp-${var.environment}"
  create_private_key = true

  tags = merge(
    local.tags,
    {
      "Name" = "key-${var.service}-meta-sharp-${var.environment}"
    },
  )
}