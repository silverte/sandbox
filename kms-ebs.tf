module "kms-ebs" {
  source = "terraform-aws-modules/kms/aws"
  create = var.create

  description = "EBS customer managed key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  is_enabled              = true
  key_usage               = "ENCRYPT_DECRYPT"
  multi_region            = false

  # Policy
  enable_default_policy                  = true
  #key_administrators                 = ["arn:aws:iam::012345678901:role/admin"]

  # Aliases
  aliases = ["ezwel/ebs"]

  tags = merge(
    local.tags,
    {
      "Name" = "kms-${var.service}-ebs"
    }
  )
}