################################################################################
# SQS Module
# reference: https://github.com/terraform-aws-modules/terraform-aws-sqs
################################################################################
module "sqs" {
  source = "terraform-aws-modules/sqs/aws"
  create = var.create

  name = "sqs-${var.service}-${var.environment}"

  tags = merge(
    local.tags,
    {
      "Name" = "sqs-${var.service}-${var.environment}"
    }
  )
}
