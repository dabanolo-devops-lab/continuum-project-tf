variable "instance_name" {
  type    = string
  description = "Name of the instance"
}

variable "cloud" {
  type    = string
  default = "gcp"
  description = "Cloud provider"
}

variable "environment" {
  type    = string
  default = "production"
  description = "Environment"
}

variable "user" {
  type    = string
  description = "User designated for the instance"
}

variable "context" {
  type    = string
  description = "Context of use for the instance"
}

variable "image_family" {
  type = string
  default = "ubuntu-2204-lts"
  description = "Image family"
}

variable "image_project" {
  type = string
  default = "ubuntu-os-cloud"
  description = "Image project"
}

variable "instance_type" {
  type = string
  description = "Instance type"
}

variable "instance_zone" {
  type = string
  default = "us-east1-b"
  description = "Instance zone"
}

variable "vpc_network" {
  type = string
  description = "VPC network"
}

variable "vpc_subnet" {
  type = string
  description = "VPC subnet"
}

variable "disk_source" {
  type = string
  description = "Disk source"
  default = ""
}

variable "disk_name" {
  type = string
  description = "Disk name"
  default = ""
}

variable "template_file" {
  type = string
  description = "Terraform template for user-data"
  default = ""
}

variable "template_vars" {
  type = map
  description = "Terraform template variables"
  default = {}
}

variable "public_key" {
  type = string
  sensitive = true
  description = "Public key"
}

variable "private_key" {
  type = string
  sensitive = true
  description = "Private key"
}

variable "file_source" {
  type = string
  description = "File source"
  default = ""
}

variable "file_destination" {
  type = string
  description = "File destination"
  default = ""
}