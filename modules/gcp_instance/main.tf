resource "google_compute_address" "static_ip" {
  name = "${var.context}-static-ip"
}

data "google_compute_image" "ubuntu" {
  family  = var.image_family
  project = var.image_project
}

# resource "google_compute_attached_disk" "attached_disk" {
#   for_each    = var.attached_disk
#   disk        = each.value.source
#   instance    = google_compute_instance.gcp_instance.name
#   device_name = each.value.name
#   mode        = "READ_WRITE"
# }

resource "google_compute_instance" "gcp_instance" {
  name                      = "${var.cloud}-${var.context}-${var.instance_name}-${var.environment}"
  machine_type              = var.instance_type
  zone                      = var.instance_zone
  allow_stopping_for_update = true

  tags = var.tags
  boot_disk {
    device_name = "${var.context}-${var.instance_name}-${var.cloud}"
    initialize_params {
      image = data.google_compute_image.ubuntu.self_link
      type  = "pd-ssd"
      size  = 10
    }
  }

  network_interface {
    network    = var.vpc_network
    subnetwork = var.vpc_subnet
    access_config {
      nat_ip = google_compute_address.static_ip.address
    }
  }

  metadata = {
    startup-script = <<EOF
    ${templatefile(var.template_file, var.template_vars)}
    EOF
    ssh-keys       = "${var.user}:${var.public_key}"
  }

  labels = {
    environment = "production",
    function    = "automation_server"
  }
  # connection {
  #   user        = var.user
  #   private_key = var.private_key
  #   host        = google_compute_address.static_ip.address
  #   type        = "ssh"
  #   timeout     = "500s"
  # }
  # provisioner "file" {
  #   source      = var.file_source
  #   destination = var.file_destination
  # }

  lifecycle {
    ignore_changes = [
      attached_disk,
    ]
  }
}