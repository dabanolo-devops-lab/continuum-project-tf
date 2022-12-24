provider "aws" {
  region = "us-east-1"
}

data "aws_ssm_parameter" "google_credentials" {
  name = "/production/gcp/service_key"
}

provider "google" {
  project     = "chat-app-371723"
  region      = "us-east1"
  zone        = "us-east1-b"
  credentials = data.aws_ssm_parameter.google_credentials.value
}