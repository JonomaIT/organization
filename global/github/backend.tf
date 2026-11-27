terraform {
  backend "s3" {
    use_lockfile = true # native S3 state locking (Terraform >= 1.10)
  }
}
