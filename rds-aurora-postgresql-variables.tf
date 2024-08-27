# RDS Aurora Cluster Name
variable "rds_aurora_cluster_name" {
  description = "RDS Aurora Cluster Name"
  type        = string
  default     = "aurora-postgresql"
}

# RDS Aurora Cluster Engine
variable "rds_aurora_cluster_engine" {
  description = "RDS Aurora Cluster Engine"
  type        = string
  default     = "aurora-postgresql"
}

# RDS Aurora Cluster Engine Version
variable "rds_aurora_cluster_engine_version" {
  description = "RDS Aurora Cluster Engine Version"
  type        = string
  default     = "14.7"
}

# RDS Aurora Cluster Instance Class
variable "rds_aurora_cluster_instance_class" {
  description = "RDS Aurora Cluster Instance Class"
  type        = string
  default     = ""
}

# RDS Aurora Master Username
variable "rds_aurora_master_username" {
  description = "RDS Aurora Master Username"
  type        = string
  default     = ""
}

# RDS Aurora Master Password
variable "rds_aurora_master_password" {
  description = "RDS Aurora Master Password"
  type        = string
  default     = ""
}

# RDS Aurora Port
variable "rds_aurora_port" {
  description = "RDS Aurora Port"
  type        = number
  default     = 5432
}

# Whether to create an Aurora DA PostreSQL (True or False)
variable "enable_aurora_postresql" {
  description = "Whether to create an Aurora DA PostreSQL"
  type        = bool
  default     = true
}
