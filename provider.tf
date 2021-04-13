# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Details of the provider and remote state configuration. We would be using an S3 backed tfstate with dynamodb lock
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

provider "aws" {
    region = "eu-west-1"
    profile = "default"
}


terraform {
    backend "s3" {
         bucket= "pico-k8s-terraform-state1"
         key= "terraform/pico-k8s/pico-k8s.tfstate"
         region="eu-west-1"
         encrypt = true
         dynamodb_table = "terraform-state"
      }
}

