# Whether to create an ALB ingress (True or False)
variable "enable_alb_ingress" {
  description = "Whether to create an ALB ingress"
  type        = bool
  default     = true
}
