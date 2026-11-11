variable "instance_type" {
  default     = "t3.micro"
  type        = string
  description = "instance type to be provisioned"
}


variable "data_volume_size" {
  default     = "10"
  type        = number
  description = "size of the extra data volume in GiB"
}
