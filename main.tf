terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }

  required_version = ">= 1.5.5"
}

provider "aws" {
  region = "ap-northeast-1"
}
