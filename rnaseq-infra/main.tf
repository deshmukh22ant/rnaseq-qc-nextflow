
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "pipeline" {
  bucket = "rnaseq-pipeline-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_public_access_block" "pipeline" {
  bucket                  = aws_s3_bucket.pipeline.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_role" "batch_instance_role" {
  name = "batch-instance-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "batch_instance_s3" {
  role       = aws_iam_role.batch_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_instance_profile" "batch_instance" {
  name = "batch-instance-profile"
  role = aws_iam_role.batch_instance_role.name
}

resource "aws_batch_job_queue" "rnaseq" {
  name                 = "rnaseq-queue"
  state                = "ENABLED"
  priority             = 1
  compute_environment_order {
    order              = 1
    compute_environment = aws_batch_compute_environment.rnaseq.arn
  }
}

resource "aws_batch_job_queue" "rnaseq_head" {
  name                 = "rnaseq-head-queue"
  state                = "ENABLED"
  priority             = 2
  compute_environment_order {
    order              = 1
    compute_environment = aws_batch_compute_environment.rnaseq.arn
  }
}

resource "aws_iam_role" "batch_service_role" {
  name = "batch-service-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "batch.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "batch_service_policy" {
  role       = aws_iam_role.batch_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"
}

resource "aws_iam_role" "spot_fleet_role" {
  name = "batch-spot-fleet-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "spotfleet.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "spot_fleet_policy" {
  role       = aws_iam_role.spot_fleet_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2SpotFleetTaggingRole"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "batch" {
  name   = "batch-security-group"
  vpc_id = data.aws_vpc.default.id
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_batch_compute_environment" "rnaseq" {
  compute_environment_name = "rnaseq-batch-env"
  type                     = "MANAGED"
  state                    = "ENABLED"
  service_role             = aws_iam_role.batch_service_role.arn

  compute_resources {
    type                = "SPOT"
    min_vcpus           = 0
    max_vcpus           = 256
    desired_vcpus       = 0
    instance_type       = ["m5.large"]
    subnets             = data.aws_subnets.default.ids
    security_group_ids  = [aws_security_group.batch.id]
    instance_role       = aws_iam_instance_profile.batch_instance.arn
    spot_iam_fleet_role = aws_iam_role.spot_fleet_role.arn
  }

  depends_on = [
    aws_iam_role_policy_attachment.batch_service_policy,
    aws_iam_role_policy_attachment.batch_instance_s3,
    aws_iam_role_policy_attachment.spot_fleet_policy
  ]
}

output "s3_bucket_name" {
  value = aws_s3_bucket.pipeline.id
}

output "batch_compute_env_arn" {
  value = aws_batch_compute_environment.rnaseq.arn
}
