variable "name_prefix" {
  description = "The prefix to use for all resources."
  type        = string
  default     = "continuum"
}

variable "context" {
  description = "The context to use for all resources."
  type        = string
  default     = "jenkins"
}

variable "encrypted" {
  description = "Whether to encrypt the volume at rest."
  type        = bool
  default     = true
}

variable "cidr_blocks" {
  description = "The CIDR block for the VPC."
  type        = list(string)
}

variable "vpc_id" {
  description = "The ID of the VPC."
  type        = string
}