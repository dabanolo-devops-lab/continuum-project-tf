resource "aws_efs_file_system" "efs_storage" {
  creation_token = "${var.context}-${var.name_prefix}-efs"
  encrypted      = var.encrypted

  tags = {
    Name = "${var.context}-${var.name_prefix}-efs"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_security_group" "efs_security_group" {
  name        = "${var.context}-efs-security-group"
  description = "Allow inbound traffic from the internet on port 2049"
  vpc_id      = var.vpc_id
  ingress {
    description = "Allow NFS traffic"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = var.cidr_blocks
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "efs-${var.name_prefix}-security-group"
  }
}

data "aws_subnets" "subnets" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
}

resource "aws_efs_mount_target" "efs_storage" {
  for_each        = toset(data.aws_subnets.subnets.ids)
  file_system_id  = aws_efs_file_system.efs_storage.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs_security_group.id]
}