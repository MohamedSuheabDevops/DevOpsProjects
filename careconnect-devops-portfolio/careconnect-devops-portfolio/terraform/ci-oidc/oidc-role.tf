# Terraform for the GitHub Actions -> AWS trust (OIDC) and one ECR repository per service.
# Run once per AWS account:  terraform init && terraform apply -var github_repo=<github-user>/<repo-name>

data "aws_caller_identity" "current" {}

locals {
  services = ["portal", "appointments", "billing", "doctors", "booking"]
}

# ---------- The trust: AWS accepts identity tokens issued by GitHub ----------
resource "aws_iam_openid_connect_provider" "github" {
  count           = var.create_oidc_provider ? 1 : 0
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"] # AWS now validates GitHub's certificate itself; kept for older provider versions
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

locals {
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
}

# ---------- The role the pipeline assumes (no access keys stored anywhere) ----------
resource "aws_iam_role" "github_ci" {
  name = "github-actions-ecr-push"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" }
        # ONLY your repository, and only runs started by a version tag, can assume this role:
        StringLike = { "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:ref:refs/tags/v*" }
      }
    }]
  })
}

resource "aws_iam_role_policy" "ecr_push" {
  role = aws_iam_role.github_ci.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["ecr:GetAuthorizationToken"], Resource = "*" },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload", "ecr:PutImage", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"
        ]
        Resource = "arn:aws:ecr:${var.region}:${data.aws_caller_identity.current.account_id}:repository/careconnect/*"
      }
    ]
  })
}

# ---------- One ECR repository per service: careconnect/portal, careconnect/appointments, ... ----------
resource "aws_ecr_repository" "svc" {
  for_each             = toset(local.services)
  name                 = "careconnect/${each.key}"
  image_tag_mutability = "IMMUTABLE" # a tag can never be overwritten
  force_delete         = true        # practice account: lets "terraform destroy" delete repositories that still hold images

  image_scanning_configuration {
    scan_on_push = true
  }
}
