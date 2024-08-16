# RDS Name
variable "rds_mariadb_as_name" {
  description = "RDS Name"
  type        = string
  default     = "mariadb-as"
}

# RDS Engine
variable "rds_mariadb_as_engine" {
  description = "RDS Engine"
  type        = string
  default     = "mariadb"
}

# RDS Engine Version
variable "rds_mariadb_as_engine_version" {
  description = "RDS Engine Version"
  type        = string
  default     = "10.11.8"
}

# RDS Inatance Class
variable "rds_mariadb_as_instance_class" {
  description = "RDS Instance Class"
  type        = string
  default     = ""
}

# RDS Family
variable "rds_mariadb_as_family" {
  description = "RDS DB parameter group"
  type        = string
  default     = "mariadb10.11"
}

# RDS Major Engine Version
variable "rds_mariadb_as_major_engine_version" {
  description = "RDS DB option group"
  type        = string
  default     = "10.11"
}

# RDS Allocated Storage
variable "rds_mariadb_as_allocated_storage" {
  description = "RDS Allocated Storage"
  type        = number
  default     = 500
}