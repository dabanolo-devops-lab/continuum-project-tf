variable "free_tier_instance_type" {
  description = "The instance type to use based on free tier availability."
  type        = string
  default     = "t2.micro"
}

variable "vpc_cidr_block" {
  description = "The CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "A list of public subnets inside the VPC."
  type        = map(string)
  default = {
    "public-1" = 1,
    "public-2" = 2
  }
}

variable "amis" {
  description = "A map of AMIs to use for the instances."
  type        = map(map(list(string)))
  default = {
    "ubuntu" = {
      owners   = ["099720109477"]
      ami_name = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
    },
    "linux_ecs" = {
      owners   = ["591542846629"]
      ami_name = ["*amazon-ecs-optimized"]
    }
  }
}

variable "key_pairs" {
  description = "A map of key pairs to use for the instances."
  type        = map(map(string))
  default = {
    "chat_ecs" = {
      key_name = "chat"
      context  = "ecs"
    },
  }
}

variable "jenkins_main_instance_type" {
  description = "The instance type to use for the Jenkins master."
  type        = string
  default     = "t2.micro"
}

variable "key_pair_path" {
  description = "The path to the SSH key pair to use for the Jenkins master."
  type        = string
  default     = "./keys"
}

variable "public_security_group_ingress" {
  description = "A list of ingress rules for the public security group."
  type        = list(map(string))
  default = [
    {
      description = "Allow SSH traffic"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      description = "Allow HTTPS traffic"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      description = "Allow Jenkins traffic"
      from_port   = 50000
      to_port     = 50000
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
    },
  ]
}

variable "cluster_security_group_ingress" {
  description = "A list of ingress rules for the public security group."
  type        = list(map(string))
  default = [
    {
      description = "Allow SSH traffic"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      description = "Allow HTTP traffic"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      description = "Allow HTTP traffic"
      from_port   = 3000
      to_port     = 3000
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      description = "Allow HTTPS traffic"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
    },
  ]
}

variable "name_prefix" {
  description = "The prefix to use for all resources."
  type        = string
  default     = "continuum"
}

variable "app_version" {
  description = "The tag to use for the Docker image."
  type        = string
  default     = "10"
}