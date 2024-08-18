module "simple_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"
  create_bucket = var.create

  bucket = "s3-${var.service}-${var.environment}-aa"
  force_destroy = true

  tags = merge(
    local.tags,
    {
      "Name" = "s3-${var.service}-${var.environment}-aa"
    }
  )
}