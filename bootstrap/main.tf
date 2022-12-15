locals {
  region                  = "us-east-1"
}

# Terraform backend S3 bucket

resource "aws_s3_bucket" "private_bucket" {
  bucket                  = "continuum-private-bucket"
  force_destroy           = false

  tags                    = {
    Name                  = "continuum-private-bucket"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "private_bucket" {
  bucket                  = aws_s3_bucket.private_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm       = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_acl" "private_bucket_acl" {
  bucket                  = aws_s3_bucket.private_bucket.id
  acl                     = "private"
}


resource "aws_s3_bucket_public_access_block" "private_bucket" {
  bucket                  = aws_s3_bucket.private_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Terraform state bucket logging ?? 



# Terraform state lock table

resource "aws_dynamodb_table" "tf-state-lock" {
  name                    = "tf-state-lock"
  read_capacity           = 2
  write_capacity          = 2
  hash_key                = "LockID"

  server_side_encryption {
    enabled               = true
  }

  attribute {
    name                  = "LockID"
    type                  = "S"
  }

  point_in_time_recovery {
    enabled               = false
  }

  tags                    = {
    Name                  = "tf-state-lock"
    Automation            = "Terraform"
  }

}

# New parameters
resource "aws_ssm_parameter" "tf-state-bucket" {
  name                    = "/production/terraform/state/bucket"
  description             = "Terraform state bucket name for production environment"
  type                    = "String"
  value                   = aws_s3_bucket.private_bucket.id
  overwrite               = true
  tier                    = "Standard"

  tags                    = {
    Name                  = "tf_state_bucket"
    Environment           = "production"
    Automation            = "Terraform"
  }
}

resource "aws_ssm_parameter" "tf-state-lock-table" {
  name                    = "/production/terraform/state/locktable"
  description             = "Terraform state lock table name for production environment"
  type                    = "String"
  value                   = aws_dynamodb_table.tf-state-lock.id
  overwrite               = true
  tier                    = "Standard"

  tags                    = {
    Name                  = "tf_state_lock_table"
    Environment           = "production"
    Automation            = "Terraform"
  }
}