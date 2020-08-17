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

resource "aws_cognito_user_pool" "user_pool" {
  name = "${var.name_prefix}-user-pool"
  admin_create_user_config {
    allow_admin_create_user_only = var.admin_create_user
  }
  password_policy{
    minimum_length    = var.password_policy_minimum_length
    require_lowercase = var.password_policy_require_lowercase
    require_uppercase = var.password_policy_require_uppercase
    require_numbers   = var.password_policy_require_numbers
    require_symbols   = var.password_policy_require_symbols
  }
  
  lambda_config {
    pre_token_generation = aws_lambda_function.cognito_tokengenerator.arn
  }
  
  schema {
      attribute_data_type      = "String"
      mutable                  = true
      name                     = "groups"
	  string_attribute_constraints {
      min_length = 0
      max_length = 2048 
		}
    }
	
  schema {
      attribute_data_type      = "String"
      mutable                  = true
      name                     = "roles"
	  string_attribute_constraints {
      min_length = 0
      max_length = 2048 
		}
    }
  
}

resource "aws_cognito_user_pool_domain" "main" {
  domain          = "${var.custom_pool_domain_subdomain}.${var.hosted_zone_name}"
  certificate_arn = aws_acm_certificate_validation.cert_pool_domain_validation_request.certificate_arn
  user_pool_id    = aws_cognito_user_pool.user_pool.id
}

resource "aws_route53_record" "custom_pool_domain_subdomain" {
  zone_id = data.aws_route53_zone.main.id
  name    = "${var.custom_pool_domain_subdomain}.${var.hosted_zone_name}"
  type    = "A"
  alias {
    name                   = aws_cognito_user_pool_domain.main.cloudfront_distribution_arn
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = true
  }
}

resource "aws_acm_certificate" "cert_pool_domain" {
  domain_name       = "${var.custom_pool_domain_subdomain}.${var.hosted_zone_name}"
  validation_method = "DNS"
  provider          = aws.certificate-provider
  tags              = var.tags
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_pool_domain_validation" {
  name    = aws_acm_certificate.cert_pool_domain.domain_validation_options.0.resource_record_name
  type    = aws_acm_certificate.cert_pool_domain.domain_validation_options.0.resource_record_type
  zone_id = data.aws_route53_zone.main.id
  records = [aws_acm_certificate.cert_pool_domain.domain_validation_options.0.resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "cert_pool_domain_validation_request" {
  certificate_arn         = aws_acm_certificate.cert_pool_domain.arn
  validation_record_fqdns = [aws_route53_record.cert_pool_domain_validation.fqdn]
  provider                = aws.certificate-provider
}

resource "aws_route53_record" "faux_root_a_record" {
  count = var.create_faux_root_a_record ? 1 : 0
  name = ""
  type = "A"
  ttl = "300"
  records = ["127.0.0.1"]
  zone_id = data.aws_route53_zone.main.id
}

data "archive_file" "lambda_cognito_tokengenerator_src" {
  type        = "zip"
  source_dir = "${path.module}/src/"
  output_path = "${path.module}/src/main.zip"
}

resource "aws_lambda_function" "cognito_tokengenerator" {
  function_name    = "${var.name_prefix}-cognito_tokengenerator"
  handler          = "main.lambda_handler"
  role             = aws_iam_role.lambda_cognito_tokengenerator_exec.arn
  runtime          = "python3.8"
  filename         = data.archive_file.lambda_cognito_tokengenerator_src.output_path
  source_code_hash = filebase64sha256(data.archive_file.lambda_cognito_tokengenerator_src.output_path)
  tags             = var.tags
}

resource "aws_iam_role" "lambda_cognito_tokengenerator_exec" {
  name               = "${var.name_prefix}-infra-trigger-pipeline"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "cognito_tokengenerator_lambda" {
  policy = data.aws_iam_policy_document.cognito_tokengenerator.json
  role   = aws_iam_role.lambda_cognito_tokengenerator_exec.id
}


