# Local Values in Terraform
locals {
  region      = var.region
  azs         = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[2]]
  service     = var.service
  owners      = var.owners
  environment = var.environment

  tags = {
    owners      = local.owners
    environment = local.environment
  }
}