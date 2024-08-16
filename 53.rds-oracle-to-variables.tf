# RDS Name
variable "rds_oracle_to_name" {
  description = "RDS Name"
  type        = string
  default     = "oracle-to"
}

# RDS Engine
variable "rds_oracle_to_engine" {
  description = "RDS Engine"
  type        = string
  default     = "oracle-ee"
}

# RDS Engine Version
variable "rds_oracle_to_engine_version" {
  description = "RDS Engine Version"
  type        = string
  default     = "19"
}


# RDS Aurora Cluster Engine
variable "rds_oracle_to_instance_class" {
  description = "RDS Instance Class"
  type        = string
  default     = "db.t3.large"
}

# RDS Family
variable "rds_oracle_to_family" {
  description = "RDS DB parameter group"
  type        = string
  default     = "oracle-ee-19"
}

# RDS Major Engine Version
variable "rds_oracle_to_major_engine_version" {
  description = "RDS DB option group"
  type        = string
  default     = "19"
}

# RDS Allocated Storage
variable "rds_oracle_to_allocated_storage" {
  description = "RDS Allocated Storage"
  type        = number
  default     = 500
}