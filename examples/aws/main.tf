terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.81.0"
    }
    ghost = {
      source = "ghostsecurity/ghost",
      version = "~> 0.1.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

provider "ghost" {}

module "dev-alb-forwarder" {
  source = "../../"
  name   = "dev-alb-forwarder"
}
