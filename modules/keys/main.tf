resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content  = tls_private_key.key.private_key_pem
  filename = "./keys/${var.key_name}-${var.context}.pem"
  file_permission = "0400"
}

resource "aws_ssm_parameter" "key_private_key" {
  name      = "/${var.environment}/${var.key_name}/${var.context}/private_key"
  type      = "SecureString"
  value     = tls_private_key.key.private_key_pem
  key_id    = "alias/aws/ssm"
  overwrite = true
  tier      = "Standard"
  tags = {
    Name        = "${var.key_name}_private_key"
    Environment = "${var.environment}"
    Automation  = "Terraform"
  }
}

resource "aws_key_pair" "public_key" {
  key_name   = "${var.key_name}-${var.context}"
  public_key = tls_private_key.key.public_key_openssh
}