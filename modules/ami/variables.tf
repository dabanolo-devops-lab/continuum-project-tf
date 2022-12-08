variable "owners" {
  description = "List of owners"
  type = list(string)
  default = ["user1", "user2"]
}

variable "ami_name" {
  description = "AMI name"
  type = list(string)
}