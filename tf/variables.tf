# GCP Project Name
variable "gcp-project-name" {
    type = string
    default = "rgreaves-sandbox"
}

# GCP VPC
variable "gcp-vpc" { 
    type = string
    default = "default"
}

# Instance Region
variable "region" { 
    type = string
    default = "us-central1"
}

variable "region-dr" { 
    type = string
    default = "us-west1"
}
# Instance Zone
variable "zone" { 
    type = string
    default = "us-central1-a"
}

# VPC Ranges
variable "vpc-cidr" {
    type = string
    default = "10.0.0.0/8"
  
}