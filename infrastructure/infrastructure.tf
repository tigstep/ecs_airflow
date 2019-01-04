#############################################################
# Infrastructure variables to be read from variables.tfvars
#############################################################

variable "region" {}
variable "shared_credentials_file" {}
variable "profile" {}
variable "vpc_cidr_block" {}
variable "subnet_cidr_block" {}

data "aws_availability_zones" "subnet_azs" {}

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
    Name                  = "ecs_airflow_vpc"
  }
}

##############################################################
# Defining a subnet for ECS cluster
##############################################################

resource "aws_subnet" "ecs_subnet" {
  vpc_id                  = "${aws_vpc.ecs_vpc.id}"
  cidr_block              = "${var.subnet_cidr_block}"
  availability_zone       = "${data.aws_availability_zones.subnet_azs.names[0]}"
  tags {
    Name                  = "ecs_airflow_subnet"
  }
}

##############################################################
# Defining an internet gateway
##############################################################

resource "aws_internet_gateway" "ecs_ig" {
  vpc_id = "${aws_vpc.ecs_vpc.id}"
  tags {
    Name = "ecs_airflow_ig"
  }
}

##############################################################
# Defining a public route table
##############################################################

resource "aws_route_table" "public_route_table" {
  vpc_id = "${aws_vpc.ecs_vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.ecs_ig.id}"
  }
  tags {
    Name = "ecs_airflow_rt"
  }
}