# ami-0dd06f1d492b5025a
locals {
  region      = "us-east-1"
  name_prefix = "chat"
  environment = "production"
  app_name    = "chatapp"
  domain_name = "dannybanol.dev"
  create_cloudwatch_log_group = true
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_region" "current" {}

# Defining a VPC
resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name        = "${local.name_prefix}-vpc"
    Environment = local.environment
    Terraform   = "true"
  }
}
# Defining a public subnet
resource "aws_subnet" "public_subnet" {
  for_each                = var.public_subnets
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(aws_vpc.vpc.cidr_block, 8, each.value)
  availability_zone       = tolist(data.aws_availability_zones.available.names)[each.value]
  map_public_ip_on_launch = true
  tags = {
    Name        = each.key
    Terraform   = "true"
    Environment = local.environment
  }
}

# Defining route table for public subnet
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
  tags = {
    Name = "public-${local.name_prefix}-route-table"
  }
}

# Defining route table association for public subnet
resource "aws_route_table_association" "public_route_table_association" {
  for_each       = aws_subnet.public_subnet
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_route_table.id
  depends_on     = [aws_subnet.public_subnet]
}

# Defining internet gateway for public subnet
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "public-${local.name_prefix}-internet-gateway"
  }
}

# Defining a security group for public subnet to allow SSH and HTTP traffic
resource "aws_security_group" "public_security_group" {
  name        = "$public-ssh-http-security-group"
  description = "Allow inbound traffic from the internet on port 22 and 8080"
  # use dynamic blocks foreach construction
  dynamic "ingress" {
    for_each = var.public_security_group_ingress
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  vpc_id = aws_vpc.vpc.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "public-${local.name_prefix}-security-group"
  }
}

# --- EFS JENKINS VOLUME ---
module "efs" {
  source      = "../modules/efs"
  cidr_blocks = [aws_vpc.vpc.cidr_block]
  vpc_id      = aws_vpc.vpc.id
}
# ---------------------------

# --- KEY PAIRS AND SSM PARAMETERS ---
# Creating a key pair for EC2 instance and storing it in local machine and in parameter store
resource "tls_private_key" "jenkins_main" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "jenkins_private_key" {
  content  = tls_private_key.jenkins_main.private_key_pem
  filename = "keys/jenkins_main.pem"
}

resource "aws_key_pair" "jenkins_main" {
  key_name   = "jenkins_main"
  public_key = tls_private_key.jenkins_main.public_key_openssh
}

resource "aws_ssm_parameter" "jenkins_main_private_key" {
  name      = "/${local.environment}/jenkins/main/private_key"
  type      = "SecureString"
  value     = tls_private_key.jenkins_main.private_key_pem
  key_id    = "alias/aws/ssm"
  overwrite = true
  tier      = "Standard"
  tags = {
    Name        = "jenkins_main_private_key"
    Environment = "production"
    Automation  = "Terraform"
  }
}

module "ami" {
  source = "../modules/ami"
  for_each = var.amis
  owners = each.value.owners
  ami_name = each.value.ami_name
}

data "aws_ami" "ubuntu_ami" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# --- ECS AMI ---
data "aws_ami" "ecs_ami" {
  most_recent = true
  owners      = ["591542846629"]
  filter {
    name   = "name"
    values = ["*amazon-ecs-optimized"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
# ---------------
# defining an EC2 instance in public subnet for running docker container with jenkins
# resource "aws_instance" "jenkins_main_controller" {
#   ami                         = data.aws_ami.ubuntu_ami.id
#   ami                         = module.ami["ubuntu"].id
#   instance_type               = var.jenkins_main_instance_type
#   subnet_id                   = aws_subnet.public_subnet["public-1"].id
#   vpc_security_group_ids      = [aws_security_group.public_security_group.id]
#   associate_public_ip_address = true
#   key_name                    = aws_key_pair.jenkins_main.key_name
#   tags                        = { Name = "public-${local.name_prefix}-instance" }
#   lifecycle { ignore_changes = [security_groups] }

#   # installing EFS utils and mounting EFS to /var/jenkins_home
#   # add sudo chown ubuntu:ubuntu /home/ubuntu/jenkins_certs/
#   user_data = <<-EOF
#               #!/bin/bash
#               mkdir jenkins
#               mkdir /home/ubuntu/jenkins_certs/
#               sudo chown ubuntu:ubuntu /home/ubuntu/jenkins_certs/
#               sudo apt-get update
#               sudo apt-get install \
#                   ca-certificates \
#                   curl \
#                   gnupg \
#                   lsb-release -y
#               sudo mkdir -p /etc/apt/keyrings
#               curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
#               echo \
#                 "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
#                 $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
#               sudo apt-get update
#               sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y
#               sudo systemctl start docker
#               sudo systemctl enable docker
#               sudo groupadd docker
#               sudo usermod -aG docker ubuntu
#               sudo systemctl enable docker

#               # Install EFS utils for ubuntu
#               sudo apt-get update
#               sudo apt-get -y install git binutils
#               git clone https://github.com/aws/efs-utils
#               cd /efs-utils
#               ./build-deb.sh
#               sudo apt-get -y install ./build/amazon-efs-utils*deb

#               # Mount EFS to /var/jenkins_home
#               mkdir -p /var/jenkins_home
#               sudo mount -t efs -o tls ${aws_efs_file_system.jenkins_main.id}:/ /var/jenkins_home
#               EOF

#   connection {
#     user        = "ubuntu"
#     private_key = tls_private_key.jenkins_main.private_key_pem
#     host        = self.public_ip
#   }

#   provisioner "file" {
#     source      = "./docker-compose.yml"
#     destination = "/home/ubuntu/docker-compose.yml"
#   }

#   provisioner "local-exec" {
#     command = "chmod 400 ${var.key_pair_path}/${aws_key_pair.jenkins_main.key_name}.pem"
#   }

#   provisioner "file" {
#     source      = "../../certs/jenkins.keystore"
#     destination = "/home/ubuntu/jenkins_certs/jenkins.jks"
#   }
#   # provisioner "remote-exec" {
#   #   inline = [
#   #     "sudo docker compose up -d",
#   #   ]
#   # }
# }


# # aws_acm_certificate.cert.arn
# resource "aws_acm_certificate" "cert" {
#   domain_name       = "${local.app_name}.${local.domain_name}"
#   validation_method = "DNS"
#   lifecycle {
#     create_before_destroy = true
#   }
#   tags = {
#     Name = "${local.app_name}-${local.name_prefix}-cert"
#   }
# }

# --- ECR REPOSITORY ---
data "aws_ecr_repository" "service" {
  name = "${local.name_prefix}-app"
}
# -----------------------

# --- ECS INSTANCE KEY PAIR ---
resource "tls_private_key" "chat_app_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "chat_app_key" {
  filename        = "keys/${local.app_name}-key.pem"
  content         = tls_private_key.chat_app_key.private_key_pem
  file_permission = "0400"
}

resource "aws_key_pair" "chat_app_key" {
  key_name   = "${local.app_name}-key"
  public_key = tls_private_key.chat_app_key.public_key_openssh
}
# ------------------------------

# --- IAM role for ECS agent ---
data "aws_iam_policy_document" "ecs_agent" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_agent" {
  name               = "chat-app"
  assume_role_policy = data.aws_iam_policy_document.ecs_agent.json
}

resource "aws_iam_role_policy_attachment" "ecs_agent" {
  role       = aws_iam_role.ecs_agent.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_agent" {
  name = aws_iam_role.ecs_agent.name
  role = aws_iam_role.ecs_agent.name
}
# --------------------------------


# --- IAM role for ECS agent ---
data "aws_iam_policy_document" "ecs_agent_ecs" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_agent_ecs" {
  name               = "chat-app-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_agent_ecs.json
}

resource "aws_iam_role_policy_attachment" "ecs_agent_ecs" {
  role       = aws_iam_role.ecs_agent_ecs.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
# --------------------------------


# --- ALB ---
resource "aws_alb" "cluster_alb" {
  #   arn = aws_elastic_beanstalk_environment.chat_env.load_balancers[0]
  name = "alb-${local.app_name}"
  # internal        = false
  security_groups = [aws_security_group.chat_app_cluster.id]
  subnets         = [for subnet in aws_subnet.public_subnet : subnet.id]

  enable_http2 = true
  idle_timeout = 600

  tags = {
    Name = "alb-${local.name_prefix}"
  }
}

resource "aws_alb_target_group" "app" {
  name       = "${local.app_name}-${local.environment}-tg"
  port       = 80
  protocol   = "HTTP"
  vpc_id     = aws_vpc.vpc.id
  depends_on = [aws_alb.cluster_alb]
  # target_type = "instance"

  health_check {
    path                = "/"
    healthy_threshold   = 2
    interval            = 300
    protocol            = "HTTP"
    matcher             = "200,301,302"
    timeout             = 60
    unhealthy_threshold = 10
  }

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
  }
}

resource "aws_alb_listener" "front_end" {
  load_balancer_arn = aws_alb.cluster_alb.id
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.app.id
    type             = "forward"
  }
}
# -----------



# --- AUTOSCALING GROUP ---
resource "aws_autoscaling_group" "chat_app_asg" {
  name                      = "chat-app"
  vpc_zone_identifier       = [aws_subnet.public_subnet["public-1"].id]
  max_size                  = 2
  min_size                  = 1
  desired_capacity          = 1
  health_check_grace_period = 120
  default_cooldown          = 30
  # health_check_type         = "ELB"
  health_check_type    = "EC2"
  launch_configuration = aws_launch_configuration.chat_app_lc.name
  termination_policies = ["OldestInstance"]

  tag {
    key                 = "Name"
    value               = "chat-app"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "chat_app_asg_policy" {
  name                      = "chat-app"
  policy_type               = "TargetTrackingScaling"
  estimated_instance_warmup = 90
  adjustment_type           = "ChangeInCapacity"
  autoscaling_group_name    = aws_autoscaling_group.chat_app_asg.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 40.0
  }
}
# -------------------------

#  --- ECS CLUSTER SECURITY GROUP ---
resource "aws_security_group" "chat_app_cluster" {
  name        = "chat-app"
  description = "Allow inbound traffic from the internet"
  vpc_id      = aws_vpc.vpc.id

  dynamic "ingress" {
    for_each = var.cluster_security_group_ingress
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# ------------------------------------

# --- ECS CLUSTER ---
resource "aws_launch_configuration" "chat_app_lc" {
  name_prefix = "chat-app"
  # image_id             = "ami-0fe5f366c083f59ca"
  # image_id                    = data.aws_ami.ecs_ami.id
  image_id                    = module.ami["linux_ecs"].id
  instance_type               = var.free_tier_instance_type
  iam_instance_profile        = aws_iam_instance_profile.ecs_agent.name
  key_name                    = aws_key_pair.chat_app_key.key_name
  security_groups             = [aws_security_group.chat_app_cluster.id]
  user_data                   = "#!/bin/bash\necho ECS_CLUSTER=chat-app >> /etc/ecs/ecs.config"
  associate_public_ip_address = true

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_ecs_cluster" "chat_app_cluster" {
  name = "chat-app"
}

resource "aws_ecs_task_definition" "chat_app" {
  family = "chat-app"
  execution_role_arn = aws_iam_role.ecs_agent_ecs.arn
  task_role_arn = aws_iam_role.ecs_agent_ecs.arn
  # network_mode = "awsvpc"
  container_definitions = jsonencode([
    {
      name      = "${data.aws_ecr_repository.service.name}"
      image     = "${data.aws_ecr_repository.service.repository_url}:latest"
      essential = true
      memory    = 512
      # cpu         = 256
      cpu         = 512
      environment = []
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.chat_app.name
          "awslogs-region"        = local.region
          "awslogs-stream-prefix" = "chat-app"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "chat_app" {
  name            = "chat-app"
  cluster         = aws_ecs_cluster.chat_app_cluster.id
  task_definition = aws_ecs_task_definition.chat_app.arn
  desired_count   = 1

  load_balancer {
    target_group_arn = aws_alb_target_group.app.id
    container_name   = data.aws_ecr_repository.service.name
    container_port   = 3000
  }

}
# --------------------

# --- CLOUDWATCH ECS LOG GROUP ---
resource "aws_cloudwatch_log_group" "chat_app" {
  name              = "/ecs/chat-app"
  retention_in_days = 14
}
# ---------------------------------



# # Include instances to the  "aws_alb_target_group"

# resource "aws_lb_target_group_attachment" "alb_tg_attachment" {
#   target_group_arn = aws_alb_target_group.app.arn
#   #count            = 3
#   #target_id = aws_instance.my_Amazon_Linux[0].id
#   port      = 80
#   count     = length(aws_instance.my_Amazon_Linux)
#   target_id = aws_instance.my_Amazon_Linux[count.index].id

# }





# # Create a target group fior the ALB cluster to point to the instances
# resource "aws_alb_target_group" "eb_target_group" {
#   name     = "eb-target-group"
#   port     = 80
#   protocol = "HTTP"
#   vpc_id   = aws_vpc.vpc.i

#   health_check {
#     healthy_threshold = 3
#     interval         = 30
#     protocol         = "HTTP"
#     # path              = var.health_check_path
#     matcher             = 200
#     timeout             = 3
#     unhealthy_threshold = 2
#   }

# }

# resource "aws_alb_listener" "eb_listener" {
#   load_balancer_arn = data.aws_alb.eb_alb.arn
#   port = 80
#   protocol = "HTTP"

#   default_action {
#     type = "redirect"
#     redirect {
#       port = "443"
#       protocol = "HTTPS"
#       status_code = "HTTP_301"
#     }
#   }
# }

# resource "aws_security_group_rule" "allow_http" {
#   type              = "ingress"
#   from_port         = 80
#   to_port           = 80
#   protocol          = "tcp"
#   cidr_blocks       = ["0.0.0.0/0"]
#   security_group_id = tolist(data.aws_alb.eb_alb.security_groups)[0]
# }

# resource "aws_alb_listener" "eb_listener_https" {
#   load_balancer_arn = data.aws_alb.eb_alb.arn
#   port = 443
#   protocol = "HTTPS"
#   certificate_arn = aws_acm_certificate.cert.arn

#   default_action {
#     type = "forward"
#     target_group_arn = aws_elastic_beanstalk_environment.chat_env.load_balancers[0]
#   }
# }

# resource "aws_alb_listener" "eb_listener" {
# load_balancer_arn = data.aws_alb.eb_alb.arn
# port              = "443"
# protocol          = "HTTPS"
# ssl_policy        = "ELBSecurityPolicy-2016-08"
# certificate_arn   = aws_acm_certificate.cert.arn

# default_action {
#   type             = "forward"
#   target_group_arn = aws_elastic_beanstalk_environment.chat_env.load_balancers[0]
# }
# }

