#############################################################
# Resource variables to be read from variables.tfvars
#############################################################

variable "ecs_cluster" {}
variable "public_key" {}
variable "ecs_key_pair_name" {}
variable "max_instance_size" {}
variable "min_instance_size" {}
variable "desired_capacity" {}

#############################################################
# Defining Application Load Balancer
#############################################################

resource "aws_alb" "ecs_load_balancer" {
  name                = "ecs-load-balancer"
  security_groups     = ["${aws_security_group.ecs_security_group.id}"]
  subnets             = ["${aws_subnet.ecs_subnet_1.id}", "${aws_subnet.ecs_subnet_2.id}"]

  tags {
    Name = "ecs_airflow_load_balancer"
  }
}

#############################################################
# Defining a Target Group
#############################################################

resource "aws_alb_target_group" "ecs_target_group" {
  name                = "ecs-target-group"
  port                = "80"
  protocol            = "HTTP"
  vpc_id              = "${aws_vpc.ecs_vpc.id}"

  health_check {
    healthy_threshold   = "5"
    unhealthy_threshold = "2"
    interval            = "30"
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = "5"
  }

  tags {
    Name = "ecs_airflow_target_group"
  }
}

#############################################################
# Defining a Listener
#############################################################

resource "aws_alb_listener" "alb_listener" {
  load_balancer_arn = "${aws_alb.ecs_load_balancer.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.ecs_target_group.arn}"
    type             = "forward"
  }
}

#############################################################
# Creating a key_pair
#############################################################

#resource "aws_key_pair" "ecs_key_pair" {
#  key_name   = "${var.ecs_key_pair_name}"
#public_key = "${var.public_key}"
#}

#############################################################
# Defining a Launch Configuration
#############################################################

resource "aws_launch_configuration" "ecs_launch_configuration" {
  name                        = "ecs-launch-configuration"
  image_id                    = "ami-0285183bbef6224bd"
  instance_type               = "t2.micro"
  iam_instance_profile        = "${aws_iam_instance_profile.ecs_instance_profile.id}"

  root_block_device {
    volume_type = "standard"
    volume_size = 8
    delete_on_termination = true
  }

  lifecycle {
    create_before_destroy = true
  }

  security_groups             = ["${aws_security_group.ecs_security_group.id}"]
  associate_public_ip_address = "true"
  key_name                    = "${var.ecs_key_pair_name}"
  user_data                   = <<EOF
#!/bin/bash
echo ECS_CLUSTER=${var.ecs_cluster} >> /etc/ecs/ecs.config
EOF
}

#############################################################
# Defining an Autoscaling Group
#############################################################

resource "aws_autoscaling_group" "ecs_autoscaling_group" {
  name                        = "ecs-autoscaling-group"
  max_size                    = "${var.max_instance_size}"
  min_size                    = "${var.min_instance_size}"
  desired_capacity            = "${var.desired_capacity}"
  vpc_zone_identifier         = ["${aws_subnet.ecs_subnet_1.id}", "${aws_subnet.ecs_subnet_2.id}"]
  launch_configuration        = "${aws_launch_configuration.ecs_launch_configuration.name}"
  health_check_type           = "ELB"
}

#############################################################
# Defining the ECS Cluster
#############################################################

resource "aws_ecs_cluster" "ecs_cluster" {
  name = "${var.ecs_cluster}"
}

#############################################################
# Defining the ECS Task
#############################################################

data "aws_ecs_task_definition" "wordpress" {
  task_definition = "${aws_ecs_task_definition.wordpress.family}"
}

resource "aws_ecs_task_definition" "wordpress" {
  family                = "hello_world"
  container_definitions = "${file("task_definitions/wordpress.json")}"
}

#############################################################
# Defining the ECS Service
#############################################################

resource "aws_ecs_service" "ecs_airflow_service" {
name            = "ecs-airflow-service"
iam_role        = "${aws_iam_role.ecs_service_role.name}"
cluster         = "${aws_ecs_cluster.ecs_cluster.id}"
task_definition = "${aws_ecs_task_definition.wordpress.family}:${max("${aws_ecs_task_definition.wordpress.revision}", "${data.aws_ecs_task_definition.wordpress.revision}")}"
desired_count   = 2

load_balancer {
target_group_arn  = "${aws_alb_target_group.ecs_target_group.arn}"
container_port    = 80
container_name    = "wordpress"
}
}