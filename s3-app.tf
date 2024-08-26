################################################################################
# S3 Module
# reference: https://github.com/terraform-aws-modules/terraform-aws-s3-bucket
#            https://github.com/terraform-aws-modules/terraform-aws-s3-object
################################################################################
module "simple_bucket" {
  source        = "terraform-aws-modules/s3-bucket/aws"
  create_bucket = var.create

  bucket        = "s3-${var.service}-${var.environment}-${var.s3_app_name}"
  force_destroy = true

  tags = merge(
    local.tags,
    {
      "Name" = "s3-${var.service}-${var.environment}-${var.s3_app_name}"
    }
  )
}
