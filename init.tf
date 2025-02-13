terraform {
  backend "s3" {
    bucket = "<your_bucket>"
    key    = "cis/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}
