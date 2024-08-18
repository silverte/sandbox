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