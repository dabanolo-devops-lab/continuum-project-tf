variable "environment" {
  type    = string
  default = "production"
  description = "Environment"
}

variable "user" {
  type    = string
  default = "admin"
  description = "User designated for the instance"
}

variable "context" {
  type    = string
  default = "jenkins"
  description = "Context of use for the instance"
}