terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  backend "s3" {
    bucket = "continuum-bucket"
    key    = "terraform.tfstate"
    region = "us-east-2"
    encrypt = true
  }
}

provider "aws" {
  region = "us-east-2"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = true
  enable_dns_support = true

  tags = {
    Name = "main"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public-a" {
  # count = length(var.public_CIDR_list)
  vpc_id = aws_vpc.main.id
  # cidr_block = tolist(var.public_CIDR_list)[count.index]
  cidr_block = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    # Name = "public-a-${count.index + 1}"
    Name = "public-a"
    AZ = data.aws_availability_zones.available.names[0]
  }
  depends_on = [aws_vpc.main]
}

resource "aws_key_pair" "architect" {
  key_name = "architect-key"
  public_key = file("./jenkins_ec2_key.pub")
}

resource "aws_key_pair" "agent" {
  key_name = "agent-key"
  public_key = file("./jk-rsa_key.pub")
}



resource "aws_security_group" "allow_ssh_http" {
  name = "allow_ssh_http"
  description = "Allow SSH and HTTP traffic"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    # cidr_blocks = [aws_vpc.main.cidr_block]
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    # cidr_blocks = [aws_vpc.main.cidr_block]
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh_http"
  }

  depends_on = [aws_vpc.main]
}

resource "aws_instance" "jenkins-controller" {
  ami = "ami-097a2df4ac947655f"
  instance_type = "t2.micro"
  key_name = aws_key_pair.architect.key_name
  subnet_id = aws_subnet.public-a.id
  vpc_security_group_ids = [aws_security_group.allow_ssh_http.id]
  associate_public_ip_address = true
  user_data = file("./jenkins_user_data.sh")

  tags = {
    Name = "jenkins-controller"
  }

  depends_on = [aws_subnet.public-a, aws_security_group.allow_ssh_http]
}

resource "aws_instance" "jenkins-agent" {
  ami = "ami-097a2df4ac947655f"
  instance_type = "t2.micro"
  key_name = aws_key_pair.agent.key_name
  subnet_id = aws_subnet.public-a.id
  vpc_security_group_ids = [aws_security_group.allow_ssh_http.id]
  associate_public_ip_address = true
  user_data = file("./build_node.sh")

  tags = {
    Name = "jenkins-agent"
  }

  depends_on = [aws_subnet.public-a, aws_security_group.allow_ssh_http]
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "gw"
  }

  depends_on = [aws_vpc.main]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "public"
  }

  depends_on = [aws_vpc.main, aws_internet_gateway.gw]
}

resource "aws_route_table_association" "public-a" {
  subnet_id = aws_subnet.public-a.id
  route_table_id = aws_route_table.public.id

  depends_on = [aws_subnet.public-a, aws_route_table.public]
}

resource "aws_security_group" "socket_server_sg" {
  name = "socket_server_sg"
  vpc_id = aws_vpc.main.id

  # socket io server
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 3000
    to_port = 3000
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "socket_server_sg"
  }

}

resource "aws_instance" "socket_server" {
  ami = "ami-097a2df4ac947655f"
  instance_type = "t2.micro"
  key_name = aws_key_pair.agent.key_name
  subnet_id = aws_subnet.public-a.id
  vpc_security_group_ids = [aws_security_group.socket_server_sg.id]
  associate_public_ip_address = true
  user_data = file("./only_docker.sh")

  tags = {
    Name = "socket_server"
  }

  depends_on = [aws_subnet.public-a, aws_security_group.socket_server_sg]
}

resource "aws_eip" "xcom-socket-server" {
  vpc = true
  instance = aws_instance.socket_server.id
}

# data "aws_iam_policy_document" "ecs_agent" {
#   statement {
#     action = ["sts:AssumeRole"]

#     principals {
#       type = "Service"
#       identifiers = ["ec2.amazonaws.com"]
#     }
#   }
# }

# resource "aws_iam_role" "ecs_agent" {
#   name = "ecs_agent"
#   assume_role_policy = data.aws_iam_policy_document.ecs_agent.json
# }

# resource "aws_iam_role_policy_attachment" "ecs_agent" {
#   role = aws_iam_role.ecs_agent.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
# }

# resource "aws_iam_instance_profile" "ecs_agent" {
#   name = "ecs_agent"
#   role = aws_iam_role.ecs_agent.name
# }

# resource "aws_launch_configuration" "ecs_lconfig" {
#   name_prefix = "ecs_lconfig"
#   image_id = "ami-097a2df4ac947655f"
#   instance_type = "t2.micro"
#   iam_instance_profile = aws_iam_instance_profile.ecs_agent.name
#   key_name = aws_key_pair.agent.key_name
#   security_groups = [aws_security_group.socket_server_sg.id]
#   user_data = "#!/bin/bash\necho ECS_CLUSTER=my-cluster >> /etc/ecs/ecs.config"
# }

# resource "aws_autoscaling_group" "ecs_asg" {
#   name = "ecs_asg"
#   launch_configuration = aws_launch_configuration.ecs_lconfig.name
#   vpc_zone_identifier = [aws_subnet.public-a.id]
#   desired_capacity = 1
#   min_size = 1
#   max_size = 1
#   health_check_type = "EC2"
#   health_check_grace_period = 300
# }

# resource "aws_ecr_repository" "continuum-app" {
#   name = "continuum-app"
#   image_tag_mutability = "MUTABLE"
#   repository_url = "210220393398.dkr.ecr.us-east-2.amazonaws.com/continuum-app"
# }

# resource "aws_ecs_cluster" "my-cluster" {
#   name = "my-cluster"
# }

# resource "aws_ecs_task_definition" "continuum-app" {
#   family = "continuum-app"
#   container_definitions = <<DEFINITION
# [
#   {
#     "essential": true,
#     "name": "continuum-app",
#     "image": "${aws_ecr_repository.continuum-app.repository_url}:latest",
#     "portMappings": [
#       {
#         "containerPort": 3000,
#         "hostPort": 3000,
#         "protocol": "tcp"
#       },
#       {
#         "containerPort": 8080,
#         "hostPort": 80,
#         "protocol": "tcp"
#       },
#       {
#         "containerPort": 22,
#         "hostPort": 22,
#         "protocol": "tcp"
#       }
#     ],
#     "memory": 512,
#     "cpu": 1,
#     "environment": [
#       {
#         "name": "NODE_ENV",
#         "value": "development"
#       }
#     ],
#     "logConfiguration": {
#       "logDriver": "awslogs",
#       "options": {
#         "awslogs-group": "continuum-app",
#         "awslogs-region": "us-east-2",
#         "awslogs-stream-prefix": "continuum-app"
#       }
#     }
#   }
# ]
# DEFINITION
# }

# resource "aws_ecs_service" "continuum-app" {
#   name = "continuum-app"
#   cluster = aws_ecs_cluster.my-cluster.id
#   task_definition = aws_ecs_task_definition.continuum-app.arn
#   desired_count = 1

#   network_configuration {
#     subnets = [aws_subnet.public-a.id]
#     security_groups = [aws_security_group.socket_server_sg.id]
#     assign_public_ip = true
#   }
# }


# resource "aws_lb" "app-lb" {
#   name = "jenkins-lb"
#   internal = false
#   load_balancer_type = "application"
#   security_groups = [aws_security_group.allow_ssh_http.id]
#   subnets = [aws_subnet.public-a.id]

#   depends_on = [aws_subnet.public-a, aws_security_group.allow_ssh_http]
# }

# resource "aws_lb_target_group" "app" {
#   name = "app"
#   port = 8080
#   protocol = "HTTP"
#   vpc_id = aws_vpc.main.id
#   target_type = "instance"

#   health_check {
#     # path = "/"
#     # port = "8080"
#     protocol = "HTTP"
#     interval = "30"
#     timeout = "3"
#     matcher = "200"
#     healthy_threshold = "3"
#     unhealthy_threshold = "2"
#   }

#   depends_on = [aws_vpc.main]
# }

# resource "aws_lb_listener" "front_end" {
#   load_balancer_arn = aws_lb.app-lb.arn
#   port = "80"
#   protocol = "HTTP"

#   default_action {
#     type = "forward"
#     target_group_arn = aws_lb_target_group.app.id
#   }
# }

# resource "aws_lb_target_group_attachment" "app-attachment" {
#   target_group_arn = aws_lb_target_group.app.arn
#   count = length(aws_instance.jenkins-controller)
#   target_id = aws_instance.jenkins-controller[count.index].id
#   port = 8080

#   depends_on = [aws_lb_target_group.app]
# }

