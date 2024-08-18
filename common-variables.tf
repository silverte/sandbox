# generic variables defined

# AWS Region
variable "region" {
  description = "Region in which AWS Resources to be created"
  type        = string
  default     = "us-west-2"
}
# Service Name
variable "service" {
  description = "Service Name for workloads"
  type        = string
  default     = "test"
}
# Environment Variable
variable "environment" {
  description = "Environment Variable used as a prefix"
  type        = string
  default     = "dev"
}
# Business Division
variable "owners" {
  description = "organization this Infrastructure belongs"
  type        = string
  default     = "born2k"
}

# EC2 User Data
variable "ec2_user_data" {
  description = "EC2 User Data"
  type        = string
  default     = ""
}

# Resource Creation
variable "create" {
  description = "Resource Creation"
  type        = bool
  default     = true
}