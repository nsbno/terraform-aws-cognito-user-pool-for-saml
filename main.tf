provider "aws" {
  region = "us-east-1"
  alias  = "certificate-provider"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  current_account_id = data.aws_caller_identity.current.account_id
  current_region     = data.aws_region.current.name
}

data "aws_route53_zone" "main" {
  name = var.hosted_zone_name
}



