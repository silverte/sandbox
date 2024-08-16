# EC2 Instance Type
variable "ec2_bastion_instance_type" {
  description = "EC2 Instance Type"
  type        = string
  default     = "t4g.medium"
}

# EC2 User Data
variable "ec2_bastion_user_data" {
  description = "EC2 User Data"
  type        = string
  default     = ""
}

# EC2 Root Volume size
variable "ec2_bastion_root_volume_size" {
  description = "EC2 Root Volume size"
  type        = number
  default     = 30
}

# EC2 EBS Volume size
variable "ec2_bastion_ebs_volume_size" {
  description = "EC2 EBS Volume size"
  type        = number
  default     = 30
}

# EC2 AMI Filter value
variable "ec2_bastion_ami_filter_value" {
  description = "EC2 AMI Filter value"
  type        = string
  default     = ""
}