locals {
  region      = "us-east-1"
  name_prefix = "chat"
  environment = "production"
  app_name    = "chatapp"
  domain_name = "dannybanol.dev"
  create_cloudwatch_log_group = true
  create_jenkins_main_instance = true
}
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_region" "current" {}

# ---------- DEFINE VPC ----------
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
# ---------- DEFINE SUBNETS ----------
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

# ---------- DEFINE ROUTE TABLE ----------
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

# ---------- DEFINE ROUTE TABLE ASSOCIATION ----------
  resource "aws_route_table_association" "public_route_table_association" {
    for_each       = aws_subnet.public_subnet
    subnet_id      = each.value.id
    route_table_id = aws_route_table.public_route_table.id
    depends_on     = [aws_subnet.public_subnet]
  }

# ---------- DEFINE INTERNET GATEWAY ----------
  resource "aws_internet_gateway" "internet_gateway" {
    vpc_id = aws_vpc.vpc.id
    tags = {
      Name = "public-${local.name_prefix}-internet-gateway"
    }
  }

# # ---------- DEFINE SECURITY GROUP JK ----------
#   resource "aws_security_group" "public_security_group" {
#     name        = "$public-ssh-http-security-group"
#     description = "Allow inbound traffic from the internet on port 22 and 8080"
#     # use dynamic blocks foreach construction
#     dynamic "ingress" {
#       for_each = var.public_security_group_ingress
#       content {
#         from_port   = ingress.value.from_port
#         to_port     = ingress.value.to_port
#         protocol    = "tcp"
#         cidr_blocks = ["0.0.0.0/0"]
#       }
#     }
#     vpc_id = aws_vpc.vpc.id
#     egress {
#       from_port   = 0
#       to_port     = 0
#       protocol    = "-1"
#       cidr_blocks = ["0.0.0.0/0"]
#     }
#     tags = {
#       Name = "public-${local.name_prefix}-security-group"
#     }
#   }

# --- KEY PAIRS ---
module "key_pairs_aws"{
  source = "../modules/keys"
  for_each = var.key_pairs
  key_name = each.value.key_name
  context = each.value.context
  environment = local.environment
}

# --- AMI USED FOR EC2 INSTANCES ---
  module "ami" {
    source = "../modules/ami"
    for_each = var.amis
    owners = each.value.owners
    ami_name = each.value.ami_name
  }


# # # aws_acm_certificate.cert.arn
# # resource "aws_acm_certificate" "cert" {
# #   domain_name       = "${local.app_name}.${local.domain_name}"
# #   validation_method = "DNS"
# #   lifecycle {
# #     create_before_destroy = true
# #   }
# #   tags = {
# #     Name = "${local.app_name}-${local.name_prefix}-cert"
# #   }
# # }

# ---------- ECR REPOSITORY ----------
data "aws_ecr_repository" "service" {
  name = "${local.name_prefix}-app"
}




# -------- IAM ROLE ECS AGENT --------
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


# -------- IAM role for ECS agent --------
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

# ---------- SSL CERTIFICATE -----------
data "aws_ssm_parameter" "intermediate_cert" {
  name = "/production/porkbun/ssl/cert/intermediate"
}
data "aws_ssm_parameter" "domain_cert" {
  name = "/production/porkbun/ssl/cert/domain"
}
data "aws_ssm_parameter" "private_key" {
  name = "/production/porkbun/ssl/key/private"
}

resource "aws_acm_certificate" "cert" {
  private_key        =  data.aws_ssm_parameter.private_key.value
  certificate_body   =  data.aws_ssm_parameter.domain_cert.value
  certificate_chain  =  data.aws_ssm_parameter.intermediate_cert.value
  # depends_on = [data.local_file.chain_cert, data.local_file.body_cert, data.local_file.key_cert]
}
# # ----------------------

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

# resource "aws_alb_listener" "front_end" {
#   load_balancer_arn = aws_alb.cluster_alb.id
#   port              = 80
#   protocol          = "HTTP"

#   default_action {
#     target_group_arn = aws_alb_target_group.app.id
#     type             = "forward"
#   }
# }

resource "aws_alb_listener" "front_end_https" {
  load_balancer_arn = aws_alb.cluster_alb.id
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.cert.arn

  default_action {
    target_group_arn = aws_alb_target_group.app.id
    type             = "forward"
  }
}

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


# ---------- ECS CLUSTER ----------
resource "aws_launch_configuration" "chat_app_lc" {
  name_prefix = "chat-app"
  image_id                    = module.ami["linux_ecs"].id
  instance_type               = var.free_tier_instance_type
  iam_instance_profile        = aws_iam_instance_profile.ecs_agent.name
  key_name                    = module.key_pairs_aws["chat_ecs"].public_key_name
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
      image     = "${data.aws_ecr_repository.service.repository_url}:${var.app_version}"
      essential = true
      memory    = 512
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
 output "task_definition" {
  value = aws_ecs_task_definition.chat_app.arn
 }

 output "ecs_cluster" {
  value = aws_ecs_cluster.chat_app_cluster.id
 }

 output "target_group_alb" {
  value = aws_alb_target_group.app.id
 }

 output "container_name" {
  value = data.aws_ecr_repository.service.name
 }