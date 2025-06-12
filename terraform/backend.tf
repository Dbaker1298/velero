terraform {
  backend "s3" {
    bucket = "minio-tf-state"
    # encrypt                     = true
    key                         = "stagingdcim/terraform.tfstate"
    region                      = "us-east-1"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    use_path_style              = true

    endpoints = {
      s3 = "http://192.168.1.30:30080"
    }
  }
}