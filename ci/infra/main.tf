terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.16.2"
    }
  }
}

provider "aws" {
  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
    }
  }
}

data "local_file" "livemedia_pub_pgp" {
  filename = var.pgp_pub_key
}

data "aws_iam_policy_document" "livemedia" {
  statement {
    sid    = "FullAccessToBucket"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_user.livemedia.arn]
    }
    actions = ["*"]
    resources = [
      "${aws_s3_bucket.livemedia.arn}/*",
      aws_s3_bucket.livemedia.arn
    ]
  }

  statement {
    sid    = "PublicReadAccess"
    effect = "Allow"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.livemedia.arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:ExistingObjectTag/public"
      values   = ["yes"]
    }
  }
}

resource "aws_iam_user" "livemedia" {
  name = var.user
  path = "/bots/"
}

resource "aws_iam_access_key" "livemedia" {
  user    = aws_iam_user.livemedia.name
  pgp_key = data.local_file.livemedia_pub_pgp.content_base64
}

resource "aws_s3_bucket" "livemedia" {
  bucket        = var.bucket
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "livemedia" {
  bucket = aws_s3_bucket.livemedia.id

  block_public_acls       = true
  block_public_policy     = false
  ignore_public_acls      = true
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "allow_livemedia_user_access_and_download" {
  bucket = aws_s3_bucket.livemedia.id
  policy = data.aws_iam_policy_document.livemedia.json
}

resource "aws_s3_bucket_accelerate_configuration" "livemedia" {
  bucket = aws_s3_bucket.livemedia.id
  status = "Enabled"
}

output "livemedia_user_access_key" {
  value = aws_iam_access_key.livemedia.id
}

output "livemedia_user_secret_key" {
  description = "Secret access key of user"

  value     = aws_iam_access_key.livemedia.encrypted_secret
  sensitive = true
}
