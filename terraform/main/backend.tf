terraform {
  backend "s3" {
    key          = "main/terraform.tfstate"
    region       = "ap-southeast-2"
    use_lockfile = true
    encrypt      = true
  }
}