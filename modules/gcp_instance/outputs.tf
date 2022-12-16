output "instance_static_ip" {
  value = "${google_compute_address.static_ip.address}"
  description = "The static IP address of the instance"
}