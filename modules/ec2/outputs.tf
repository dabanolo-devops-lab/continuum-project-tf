output "instance_ip" {
  description = "The public IP address of the instance"
  value = aws_instance.this.public_ip
}