resource "local_file" "docker_compose" {
  content  = templatefile("${path.root}/../tpl_files/docker-compose.tftpl", {
    keystore_pass = var.keystore_pass
  })
  filename = "${path.root}/../files/docker-compose.yml"
  file_permission = "0400"
}

resource "aws_instance" "this" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  associate_public_ip_address = true
  key_name                    = var.key_name
  tags                        = { 
    Name = var.instance_name
  }
  lifecycle { 
    ignore_changes = [security_groups]
  }

  user_data = templatefile("${path.root}/../tpl_files/jenkins_main.tftpl", {
    efs_repository_id = var.efs_repository_id
  })

  connection {
    user        = "ubuntu"
    private_key = var.private_key
    host        = self.public_ip
  }

  provisioner "file" {
    source      = local_file.docker_compose.filename
    destination = "/home/ubuntu/docker-compose.yml"
  }

  provisioner "file" {
    source      = "${path.root}/../../certs/jenkins.keystore"
    destination = "/home/ubuntu/jenkins_certs/jenkins.jks"
  }

  # provisioner "remote-exec" {
  #   inline = [
  #     "sudo docker compose up -d",
  #   ]
  # }
}

resource "aws_eip" "this" {
  instance = aws_instance.this.id
  vpc = true
}