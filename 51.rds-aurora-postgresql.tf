################################################################################
# RDS Aurora Module
################################################################################
module "aurora-sb-postgresql" {
  source = "terraform-aws-modules/rds-aurora/aws"
  name            = "rds-${var.service}-${var.environment}-${var.rds_aurora_cluster_name}"
  engine          = var.rds_aurora_cluster_engine
  engine_version  = var.rds_aurora_cluster_engine_version
  master_username = "postgresql"
  master_password = "Ezwel1234!"
  instances = {
    1 = {
      instance_class          = var.rds_aurora_cluster_instance_class
      publicly_accessible     = true
      db_parameter_group_name = "default.aurora-postgresql14"
    }
  }
  vpc_id               = module.vpc.vpc_id
  db_subnet_group_name = module.vpc.database_subnet_group_name
  publicly_accessible = false

  security_group_name  = "scg-${var.service}-${var.environment}-${var.rds_aurora_cluster_name}"
  security_group_description = "Aurora PostgreSQL Security Group"
  security_group_tags = merge(
    local.tags,
    {
      "Name" = "scg-${var.service}-${var.rds_aurora_da_cluster_name}-${var.environment}"
    }
  )
  security_group_rules = {
    vpc_ingress = {
      cidr_blocks = module.vpc.private_subnets_cidr_blocks
    }
  }
  storage_encrypted       = true
  kms_key_id              = module.kms-rds.key_arn
  apply_immediately       = true
  skip_final_snapshot     = true
  auto_minor_version_upgrade = false
  backup_retention_period = 1
  deletion_protection     = false
  create_db_cluster_parameter_group      = true
  db_cluster_parameter_group_name        = "cpg-${var.service}-${var.environment}-${var.rds_aurora_cluster_name}"
  db_cluster_parameter_group_family      = "aurora-postgresql14"
  db_cluster_parameter_group_description = "aurora cluster parameter group"
  db_cluster_parameter_group_parameters = [
    {
      name         = "log_min_duration_statement"
      value        = 4000
      apply_method = "immediate"
      }, {
      name         = "rds.force_ssl"
      value        = 1
      apply_method = "immediate"
    }
  ]
  create_db_parameter_group      = true
  db_parameter_group_name        = "pg-${var.service}-${var.environment}-${var.rds_aurora_cluster_name}"
  db_parameter_group_family      = "aurora-postgresql14"
  db_parameter_group_description = "DB parameter group"
  db_parameter_group_parameters = [
    {
      name         = "log_min_duration_statement"
      value        = 4000
      apply_method = "immediate"
    }
  ]
  # enabled_cloudwatch_logs_exports = ["postgresql"]
  # create_cloudwatch_log_group     = true
  tags = merge(
    local.tags,
    {
      "Name" = "rds-${var.service}-${var.environment}-${var.rds_aurora_cluster_name}"
    },
  )
}