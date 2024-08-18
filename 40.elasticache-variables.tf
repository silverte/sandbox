# Elasticache Cluster 
variable "elasticache_cluster_name" {
  description = "Elasticache Cluster Name"
  type        = string
  default     = "data"
}

# Elasticache Cluster Engine Version
variable "elasticache_cluster_engine_version" {
  description = "Elasticache Cluster Engine Version"
  type        = string
  default     = "7.1"
}

# Elasticache Cluster Instance Class
variable "elasticache_cluster_instance_class" {
  description = "Elasticache Cluster Instance Class"
  type        = string
  default     = "cache.t4g.small"
}