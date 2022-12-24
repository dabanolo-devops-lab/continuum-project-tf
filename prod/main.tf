locals {
  user = "ubuntu"
  instance_definition = {
    "jenkins" = {
      context       = "jenkins",
      user          = local.user,
      instance_name = "jenkins-instance",
      instance_type = "e2-medium",
      tags          = ["jenkins"]
      attached_disk = {
        "jenkins_data" = {
          source = google_compute_disk.jenkins_data.id,
          name   = google_compute_disk.jenkins_data.name
        }
      },
      template_file = "${path.root}/../tpl_files/gcp_jenkins.tftpl"
      template_vars = {
        "keystore-pass"     = data.aws_ssm_parameter.jenkins_pass.value,
        "user-instance"     = local.user,
        "jenkins-caddyfile" = data.aws_ssm_parameter.intermediate_cert.value,
        "domain-cert"       = data.aws_ssm_parameter.domain_cert.value,
        "private-key-cert"  = data.aws_ssm_parameter.private_key.value,
      },
      # file_source      = "${path.root}/../../certs/jenkins.keystore",
      # file_destination = "/home/${local.user}/jenkins.jks",
    },
    "sonarqube" = {
      instance_name = "sonarqube",
      user          = local.user,
      context       = "sonarqube",
      instance_type = "e2-medium",
      tags          = ["sonarqube"]
      attached_disk = {},
      template_file = "${path.root}/../tpl_files/gcp_sonarqube.tftpl"
      template_vars = {
        "user-instance"           = local.user,
        "sonarqube-jdbc-username" = data.aws_ssm_parameter.sonarqube_id.value,
        "sonarqube-jdbc-password" = data.aws_ssm_parameter.sonarqube_pass.value,
      },
    },
    "worker" = {
      instance_name = "worker",
      user          = local.user,
      context       = "worker",
      instance_type = "e2-small",
      tags          = ["jenkins"]
      attached_disk = {},
      template_file = "${path.root}/../tpl_files/jk_worker/main.tftpl"
      template_vars = {
        "user-instance" = local.user,
        "docker-install" = templatefile("${path.root}/../tpl_files/jk_worker/docker-install.tftpl", {"user-instance" = local.user }),
        "java-install" = file("${path.root}/../tpl_files/jk_worker/java-install.tftpl"),
        "tfenv-install" = templatefile("${path.root}/../tpl_files/jk_worker/tfenv-install.tftpl", {"user-instance" = local.user , "terraform-version" = "1.3.5"}),
        "awscli-install" = file("${path.root}/../tpl_files/jk_worker/awscli-install.tftpl"),
        "nvm-install" = templatefile("${path.root}/../tpl_files/jk_worker/nvm-install.tftpl", {"node_version" = "18.12.1"}),
      },
    }
    # "monitoring" = {
    #   instance_name = "monitoring",
    #   user          = local.user,
    #   context       = "monitoring",
    #   instance_type = "e2-medium",
    #   tags = ["monitoring"]
    #   attached_disk = {},
    #   template_file = "${path.root}/../tpl_files/monitor/gcp_monitoring.tftpl"
    #   template_vars = {
    #     "user-instance" = local.user,
    #     "docker-install" = file("${path.root}/../tpl_files/gcp_docker.tftpl"),
    #     "docker-compose" = file("${path.root}/../tpl_files/monitor/gcp_docker-compose_monitor.tftpl")
    #     "prometheus-config" = file("${path.root}/../tpl_files/monitor/gcp_prometheus_config.tftpl")
    #     "loki-config" = file("${path.root}/../tpl_files/monitor/gcp_loki_config.tftpl")
    #   },
    # },
  }
}

resource "local_file" "jenkins_password" {
  filename = "${path.root}/../../certs/jenkins.keystore"
}

data "aws_ssm_parameter" "jenkins_pass" {
  name = "/production/jenkins/keystore/pass"
}

#  ----------------- VPC -----------------
resource "google_compute_network" "vpc_network" {
  name                    = "vpc-network"
  auto_create_subnetworks = false
}

# ----------------- SUBNET -----------------
resource "google_compute_subnetwork" "vpc_subnet" {
  name                     = "vpc-subnet"
  ip_cidr_range            = "10.0.1.0/24"
  region                   = "us-east1"
  network                  = google_compute_network.vpc_network.self_link
  private_ip_google_access = true
}

# ----------------- FIREWALL -----------------
resource "google_compute_firewall" "vpc_firewall" {
  name    = "vpc-firewall"
  network = google_compute_network.vpc_network.self_link

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "8081", "9100", "9494", "50000"]
  }

  allow {
    protocol = "icmp"
  }
  # Change to the IP address provided by VPN
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["jenkins"]
}

resource "google_compute_firewall" "vpc_firewall_sonarqube" {
  name    = "vpc-firewall-sonarqube"
  network = google_compute_network.vpc_network.self_link

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "9000", "9090", "9091", "9092", "9093", "9094", "9100", "3100", "3000"]
  }

  allow {
    protocol = "icmp"
  }
  # Change to the IP address provided by VPN
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["sonarqube", "monitoring"]
}

# resource "google_compute_firewall" "vpc_firewall_monitoring" {
#   name    = "vpc-firewall-monitoring"
#   network = google_compute_network.vpc_network.self_link

#   allow {
#     protocol = "tcp"
#     ports    = ["22", "80", "443", "9090", "9091", "9092", "9093", "9094", "9095", "3100", "3000"]
#   }
#   allow {
#     protocol = "icmp"
#   }
#   # Change to the IP address provided by VPN
#   source_ranges = ["0.0.0.0/0"]
#   target_tags   = ["monitoring"]
# }

# ----------------- ROUTE -----------------
# resource "google_compute_route" "vpc_route" {
#   name                   = "vpc-route"
#   network                = google_compute_network.vpc_network.self_link
#   dest_range             = "

# ----------------- INSTANCE CONFIG -----------------
module "key_pairs" {
  for_each = {
    "jenkins" = {
      "context" = "jenkins",
    },
    "sonarqube" = {
      "context" = "sonarqube",
    },
    "worker" = {
      "context" = "worker",
    },
  }
  source      = "../modules/key_pairs"
  context     = each.value.context
  environment = var.environment
  user        = var.user
}

# -----------SONARQUBE CREDENTIALS-----------
data "aws_ssm_parameter" "sonarqube_id" {
  name = "/production/sonarqube/admin/id"
}

data "aws_ssm_parameter" "sonarqube_pass" {
  name = "/production/sonarqube/admin/pass"
}

# ----------- JENKINS DATA DISK -----------
resource "google_compute_disk" "jenkins_data" {
  name = "jenkins"
  type = "pd-ssd"
  zone = "us-east1-b"
  size = "5"
}

module "gcp_instance" {
  source        = "../modules/gcp_instance"
  for_each      = local.instance_definition
  instance_name = each.value.instance_name
  environment   = var.environment
  user          = each.value.user
  context       = each.value.context
  instance_type = each.value.instance_type

  tags = each.value.tags

  vpc_network = google_compute_network.vpc_network.self_link
  vpc_subnet  = google_compute_subnetwork.vpc_subnet.self_link

  public_key  = module.key_pairs[each.value.context].public_key
  private_key = module.key_pairs[each.value.context].private_key

  attached_disk = each.value.attached_disk

  template_file = each.value.template_file
  template_vars = each.value.template_vars
}