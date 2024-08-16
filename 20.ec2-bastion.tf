################################################################################
# EC2 Module
################################################################################

module "ec2_bastion" {
  source = "terraform-aws-modules/ec2-instance/aws"

  name = "ec2-${var.service}-bastion-${var.environment}"

  ami                         = data.aws_ami.ec2_bastion.id
  instance_type               = var.ec2_bastion_instance_type
  availability_zone           = element(module.vpc.azs, 0)
  subnet_id                   = element(module.vpc.public_subnets, 0)
  vpc_security_group_ids      = [module.security_group_ec2_bastion.security_group_id]
  associate_public_ip_address = true
  disable_api_stop            = false
  key_name                    = module.key_pair_bastion.key_pair_name

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
      volume_size = var.ec2_bastion_root_volume_size
      tags = {
        Name = "ec2-bastion-root-block"
      }
    },
  ]

  ebs_block_device = [
    {
      device_name = "/dev/sdf"
      volume_type = "gp3"
      volume_size = var.ec2_bastion_ebs_volume_size
    #   throughput  = 200 # default: 125
      encrypted   = true
      kms_key_id  = module.kms-ebs.key_arn
      tags = {
        Name = "ec2-bastion-data-block"
        MountPoint = "/mnt/data"
      }
    }
  ]

  tags = merge(
    local.tags,
    {
      "Name" = "ec2-${var.service}-bastion-${var.environment}"
    },
  )
}

module "security_group_ec2_bastion" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "scg-${var.service}-bastion-${var.environment}"
  description = "Security group for EC2 Bastion"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp", "all-icmp"]
  egress_rules        = ["all-all"]

  tags = merge(
    local.tags,
    {
      "Name" = "scg-${var.service}-bastion-${var.environment}"
    },
  )
}

data "aws_ami" "ec2_bastion" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = [var.ec2_bastion_ami_filter_value]
  }
}

module "key_pair_bastion" {
  source = "terraform-aws-modules/key-pair/aws"

  key_name           = "key-${var.service}-bastion-${var.environment}"
  create_private_key = true

  tags = merge(
    local.tags,
    {
      "Name" = "key-${var.service}-bastion-${var.environment}"
    },
  )
}