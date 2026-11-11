variable "aws_bucket_name" {
  default     = "bootstrap124"
  type        = string
  description = "description"
}

variable "aws_region" {
  default     = "eu-central-1"
  type        = string
  description = "region to provision the s3 bucket"
}

variable "aws_profile_name" {
  default     = "Kloud-Messiah"
  type        = string
  description = "profile to provision the s3 bucket"
}
