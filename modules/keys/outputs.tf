output "public_key_name" {
  value = aws_key_pair.public_key.key_name
}

output "private_key_pem" {
  value = tls_private_key.key.private_key_pem
}