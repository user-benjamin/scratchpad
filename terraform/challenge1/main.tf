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

resource "aws_iam_role" "lambda_exec" {
  name = "challenge1_lambda"

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
}

(* where is this file?{ *)

resource "aws_lambda_function" "challenge1"
  filename      = "challenge-01.zip"
  function_name = "Bens-Function"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "challenge-01"

  source_code_hash = filebase64sha256("challenge-01.zip")

  runtime = "go1.x"

  environment {
    variables = {
      foo = "bar"
    }
  }
}
