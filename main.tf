terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.44.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
}


resource "aws_s3_bucket" "contents" {
  bucket = "iacer-contents"
}


resource "aws_s3_bucket" "media" {
  bucket = "iacer-media"
}
