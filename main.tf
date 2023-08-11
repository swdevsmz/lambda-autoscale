terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      # version = "~> 4.16"
    }
  }

  required_version = ">= 1.5.5"
}

provider "aws" {
  region = "ap-northeast-1"
  #   profile = "test" # name of the profile in credentials file
}
