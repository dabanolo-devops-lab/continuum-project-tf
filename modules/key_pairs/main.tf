resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_ssm_parameter" "private_key" {
  name      = "/${var.environment}/${var.user}/${var.context}/private_key"
  type      = "SecureString"
  value     = tls_private_key.key.private_key_pem
  key_id    = "alias/aws/ssm"
  overwrite = true
  tier      = "Standard"
  tags = {
    Name        = "${var.user}_private_key"
    Environment = "${var.environment}"
    Automation  = "Terraform"
  }
}

resource "aws_ssm_parameter" "public_key" {
  name      = "/${var.environment}/${var.user}/${var.context}/public_key"
  type      = "SecureString"
  value     = tls_private_key.key.public_key_openssh
  key_id    = "alias/aws/ssm"
  overwrite = true
  tier      = "Standard"
  tags = {
    Name        = "${var.user}_public_key"
    Environment = "${var.environment}"
    Automation  = "Terraform"
  }
}

resource "local_file" "private_key" {
  content  = aws_ssm_parameter.private_key.value
  filename = "${path.root}/../../key_pairs/${var.user}-${var.context}"
  file_permission = "0400"
}