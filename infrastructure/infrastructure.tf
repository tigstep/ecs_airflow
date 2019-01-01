#############################################################
# Infrastructure variables to be read from variables.tfvars
#############################################################

variable "region" {}
variable "shared_credentials_file" {}
variable "profile" {}
variable "vpc_cidr_block" {}

#############################################################
# Defining the provider
#############################################################

provider "aws" {
  region                  = "${var.region}"
  shared_credentials_file = "${var.shared_credentials_file}"
  profile                 = "${var.profile}"
}

##############################################################
# Defining VPC
##############################################################

resource "aws_vpc" "ecs_vpc" {
  cidr_block              = "${var.vpc_cidr_block}"
  tags {
    Name                  = "ecs_vpc"
  }
}