output "public_key" {
  value = aws_ssm_parameter.public_key.value
}

output "private_key" {
  value = aws_ssm_parameter.private_key.value
}