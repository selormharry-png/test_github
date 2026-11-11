resource "aws_s3_bucket" "type" {
  bucket = var.aws_bucket_name

  lifecycle {
    prevent_destroy = true
  }
}


resource "aws_s3_bucket_versioning" "type" {
  bucket = aws_s3_bucket.type.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "type" {
  bucket                  = aws_s3_bucket.type.id
  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true

}

resource "aws_s3_bucket_server_side_encryption_configuration" "type" {
  bucket = aws_s3_bucket.type.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}


resource "aws_s3_bucket_ownership_controls" "type" {
  bucket = aws_s3_bucket.type.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
