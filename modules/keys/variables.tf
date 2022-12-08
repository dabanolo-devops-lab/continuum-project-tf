variable "key_name" {
  description = "The name of the private key to generate and associate with a local key pair."
  type        = string
}

variable "context" {
  description = "The context to deploy into."
  type        = string
}

variable "environment" {
  description = "The environment to deploy into."
  type        = string
  default     = "dev"
}