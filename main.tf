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

resource "aws_s3_bucket_acl" "contents_acl" {
  bucket = aws_s3_bucket.contents.bucket
  acl    = "private"
}

resource "aws_s3_bucket" "media" {
  bucket = "iacer-media"
}

resource "aws_s3_bucket_acl" "media_acl" {
  bucket = aws_s3_bucket.media.bucket
  acl    = "private"
}
