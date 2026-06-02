terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-1"
}
variable "project_name" {
  type = string
  default = "project1"
}
variable "environment"{
    type = string
    default = "dev"
}
locals {
    bucket_name = "${var.project_name}-${var.environment}-s3-bucket"
}
resource "aws_s3_bucket" "my_bucket"{
    bucket = local.bucket_name
    tags = {
        Env = var.environment
        Project = var.project_name

    }
}
output "final_bucket_name" {
    value = aws_s3_bucket.my_bucket.bucket
}

