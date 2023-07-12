terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}
provider "aws" {
  region = "us-east-1"
}

resource "aws_iam_role" "challenge3" {
  name = "challenge3"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
  inline_policy {
    name = "ssmreadwrite"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action   = ["ssm:*"]
          Effect   = "Allow"
          Resource = "*"
        },
      ]
    })
  }

}


resource "aws_lambda_function" "challenge3" {
  filename      = "challenge-03.zip"
  function_name = "Bens-Function"
  role          = aws_iam_role.challenge3.arn
  handler       = "challenge-03"

  source_code_hash = filebase64sha256("challenge-03.zip")

  runtime = "go1.x"

  environment {
    variables = {
      Author   = "Ben",
      PWD_PATH = aws_ssm_parameter.secret.name
    }
  }
}

resource "aws_ssm_parameter" "secret" {
  name        = "/bglover/production/database/password/master"
  description = "The parameter description"
  type        = "SecureString"
  value = "changeme1"
}
