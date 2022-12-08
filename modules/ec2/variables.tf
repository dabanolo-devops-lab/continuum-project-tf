variable "efs_repository_id" {
  description = "The ID of the EFS repository"
  type = string
}

variable "keystore_pass" {
  description = "The password for the keystore"
  type = string
}

variable "ami_id" {
  description = "The ID of the AMI to use for the instance"
  type = string
}

variable "instance_type" {
  description = "The type of instance to use"
  type = string
  default = "t2.micro"
}

variable "subnet_id" {
  description = "The ID of the subnet to use"
  type = string
}

variable "security_group_ids" {
  description = "The IDs of the security groups to use"
  type = list(string)
}

variable "key_name" {
  description = "The name of the key pair to use"
  type = string
}

variable "instance_name" {
  description = "The name of the instance"
  type = string
}

variable "private_key" {
  description = "The private key to use for SSH"
  type = string
}
