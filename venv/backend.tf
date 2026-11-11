terraform {
    backend "s3" {
      bucket       = "bootstrap"
      key          = "ec2/terraform.tfstate"
      region       = "eu-central-1"
      encrypt      = true
      use_lockfile = true
    }
    
}

# terraform {
#   cloud {
#     organization = "your-org"
#     workspaces {
#       name = "ec2-prod"
#     }
#   }
# }
