#############################################################
# Infrastructure variables to be read from variables.tfvars
#############################################################

variable "region" {}
variable "shared_credentials_file" {}
variable "profile" {}
variable "vpc_cidr_block" {}
variable "subnet_cidr_block_1" {}
variable "subnet_cidr_block_2" {}

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
  enable_dns_support      = true
  enable_dns_hostnames    = true
  tags {
    Name                  = "ecs_airflow_vpc"
  }
}

##############################################################
# Defining subnets for ECS cluster
##############################################################

resource "aws_subnet" "ecs_subnet_1" {
  vpc_id                  = "${aws_vpc.ecs_vpc.id}"
  cidr_block              = "${var.subnet_cidr_block_1}"
  availability_zone       = "${data.aws_availability_zones.subnet_azs.names[0]}"
  tags {
    Name                  = "ecs_airflow_subnet"
  }
}

resource "aws_subnet" "ecs_subnet_2" {
  vpc_id                  = "${aws_vpc.ecs_vpc.id}"
  cidr_block              = "${var.subnet_cidr_block_2}"
  availability_zone       = "${data.aws_availability_zones.subnet_azs.names[1]}"
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

##############################################################
# Associate Subnets with the Route Table
##############################################################

resource "aws_route_table_association" "subnet_route_association_1" {
  subnet_id      = "${aws_subnet.ecs_subnet_1.id}"
  route_table_id = "${aws_route_table.public_route_table.id}"
}

resource "aws_route_table_association" "subnet_route_association_2" {
  subnet_id      = "${aws_subnet.ecs_subnet_2.id}"
  route_table_id = "${aws_route_table.public_route_table.id}"
}

##############################################################
# Defining a Security Group
##############################################################

resource "aws_security_group" "ecs_security_group" {
  name = "ecs-security-group"
  description = "A security group to be used by ecs instances"
  vpc_id = "${aws_vpc.ecs_vpc.id}"

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 0
    to_port = 0
    protocol = "tcp"
    cidr_blocks = ["${var.subnet_cidr_block_1}", "${var.subnet_cidr_block_2}"]
  }

  ingress {
    from_port = 2049
    to_port = 2049
    protocol = "tcp"
    cidr_blocks = ["${var.subnet_cidr_block_1}", "${var.subnet_cidr_block_2}"]
  }

  egress {
    from_port = "0"
    to_port = "0"
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "ecs_airflow_security_group"
  }
}