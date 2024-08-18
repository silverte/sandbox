# RDS Name
variable "rds_postgresql_da_name" {
  description = "RDS Name"
  type        = string
  default     = "postgresql-da"
}

# RDS Engine
variable "rds_postgresql_da_engine" {
  description = "RDS Engine"
  type        = string
  default     = "postgres"
}

# RDS Engine Version
variable "rds_postgresql_da_engine_version" {
  description = "RDS Engine Version"
  type        = string
  default     = "14"
}

# RDS Inatance Class
variable "rds_postgresql_da_instance_class" {
  description = "RDS Instance Class"
  type        = string
  default     = ""
}

# RDS Family
variable "rds_postgresql_da_family" {
  description = "RDS DB parameter group"
  type        = string
  default     = "postgres14"
}

# RDS Major Engine Version
variable "rds_postgresql_da_major_engine_version" {
  description = "RDS DB option group"
  type        = string
  default     = "14"
}

# RDS Allocated Storage
variable "rds_postgresql_da_allocated_storage" {
  description = "RDS Allocated Storage"
  type        = number
  default     = 500
}