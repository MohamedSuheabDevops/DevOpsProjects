output "role_arn" {
  description = "Save as the GitHub secret AWS_ROLE_ARN"
  value       = aws_iam_role.github_ci.arn
}

output "registry" {
  description = "ECR registry host. Images are <registry>/careconnect/<service>:<version>"
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com"
}
