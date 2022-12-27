output "ecr_repository_url" {
  value       = data.aws_ecr_repository.service.repository_url
  description = "ECR repository URL"
}