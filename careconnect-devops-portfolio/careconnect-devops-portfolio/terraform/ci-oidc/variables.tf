variable "region" {
  type    = string
  default = "us-east-1"
}

variable "github_repo" {
  description = "Only this repository may assume the role, written as <github-user>/<repo-name>"
  type        = string
}

variable "create_oidc_provider" {
  description = "An AWS account can have only ONE GitHub OIDC provider. Set false if your account already has one."
  type        = bool
  default     = true
}
