# # output "jenkins_main_instance_public_ip" {
# #   value = aws_instance.jenkins_main_controller.public_ip
# #   # sensitive   = true
# #   description = "Public IP of Jenkins main controller"
# # }

# output "ecr_repository_url" {
#   value       = data.aws_ecr_repository.service.repository_url
#   description = "ECR repository URL"
# }

# # output "alb_output" {
# #   value = aws_alb.cluster_alb.dns_name
# # }