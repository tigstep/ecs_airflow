#############################################################
# Resource variables to be read from variables.tfvars
#############################################################

variable "ecs_cluster" {}
variable "public_key" {}
variable "ecs_key_pair_name" {}
variable "max_instance_size" {}
variable "min_instance_size" {}
variable "desired_capacity" {}
variable "postgres_name" {}
variable "postgres_username" {}
variable "postgres_password" {}

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
  port                = "8080"
  protocol            = "HTTP"
  vpc_id              = "${aws_vpc.ecs_vpc.id}"

  health_check {
    healthy_threshold   = "5"
    unhealthy_threshold = "2"
    interval            = "30"
    matcher             = "200,302"
    path                = "/"
    port                = "8080"
    protocol            = "HTTP"
    timeout             = "5"
  }
  depends_on            = ["aws_alb.ecs_load_balancer"]
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
  instance_type               = "t2.small"
  iam_instance_profile        = "${aws_iam_instance_profile.ecs_instance_profile.id}"

  root_block_device {
    volume_type = "standard"
    volume_size = 8
    delete_on_termination = true
  }
  depends_on    = [
    "aws_efs_mount_target.ecs_airflow_mt_1"
    , "aws_efs_mount_target.ecs_airflow_mt_2"
]

  lifecycle {
    create_before_destroy = true
  }

  security_groups             = ["${aws_security_group.ecs_security_group.id}"]
  associate_public_ip_address = "true"
  key_name                    = "${var.ecs_key_pair_name}"
  user_data                   = <<EOF
#!/bin/bash
echo ECS_CLUSTER=${var.ecs_cluster} >> /etc/ecs/ecs.config
sudo mkdir efs
sudo yum install -y amazon-efs-utils
echo ${aws_efs_file_system.ecs_airflow_efs.id} >> /efs_id.txt
sudo mount -t efs ${aws_efs_file_system.ecs_airflow_efs.id}:/ efs
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
# Defining a Template File
#############################################################

data "template_file" "task_template" {
  template = "${file("task_definitions/airflow_celery.json.tpl")}"
  depends_on = [
    "aws_elasticache_cluster.ecs_ariflow_redis_cluster"
    , "aws_db_instance.ecs_airflow_rds"
  ],
  vars {
    postgres_user = "${aws_db_instance.ecs_airflow_rds.username}"
    postgres_db = "${aws_db_instance.ecs_airflow_rds.name}"
    postgres_password = "${aws_db_instance.ecs_airflow_rds.password}"
    postgres_host = "${aws_db_instance.ecs_airflow_rds.address}"
    fernet_key = "46BKJoQYlPPOexq0OhDZnIlNepKFf87WFwLbfzqDDho="
    redis_host = "${aws_elasticache_cluster.ecs_ariflow_redis_cluster.cache_nodes.0.address}"
  }
}

#############################################################
# Defining the ECS Task
#############################################################

data "aws_ecs_task_definition" "webserver" {
  depends_on = [ "aws_ecs_task_definition.webserver" ]
  task_definition = "${aws_ecs_task_definition.webserver.family}"
}

resource "aws_ecs_task_definition" "webserver" {
  family                = "ecs_airflow"
  volume {
    name                = "dag_folder"
    host_path           = "/efs"
  }
  container_definitions = "${data.template_file.task_template.rendered}"
}

#############################################################
# Defining the ECS Service
#############################################################

resource "aws_ecs_service" "ecs_airflow_service" {
  name            = "ecs-airflow-service"
  iam_role        = "${aws_iam_role.ecs_service_role.name}"
  cluster         = "${aws_ecs_cluster.ecs_cluster.id}"
  task_definition = "${aws_ecs_task_definition.webserver.family}:${max("${aws_ecs_task_definition.webserver.revision}", "${data.aws_ecs_task_definition.webserver.revision}")}"
  desired_count   = 2

  load_balancer {
    target_group_arn  = "${aws_alb_target_group.ecs_target_group.arn}"
    container_port    = 8080
    container_name    = "webserver"
  }
}

#############################################################
# Defining EFS volume
#############################################################

resource "aws_efs_file_system" "ecs_airflow_efs" {
  tags = {
    Name = "ecs_airflow_efs"
  }
}

#############################################################
# Defining EFS mount targets
#############################################################

resource "aws_efs_mount_target" "ecs_airflow_mt_1" {
  file_system_id  = "${aws_efs_file_system.ecs_airflow_efs.id}"
  subnet_id       = "${aws_subnet.ecs_subnet_1.id}"
  security_groups = ["${aws_security_group.ecs_security_group.id}"]
}

resource "aws_efs_mount_target" "ecs_airflow_mt_2" {
  file_system_id  = "${aws_efs_file_system.ecs_airflow_efs.id}"
  subnet_id       = "${aws_subnet.ecs_subnet_2.id}"
  security_groups = ["${aws_security_group.ecs_security_group.id}"]
}

################################################################
# Creating subnet_group for rds
################################################################

resource "aws_db_subnet_group" "rds_subnet_group" {
  name        = "subnet_group"
  description = "subnet group for RDS"
  subnet_ids  = ["${aws_subnet.ecs_subnet_1.id}", "${aws_subnet.ecs_subnet_2.id}"]
}

################################################################
# Adding an RDS instance
################################################################

resource "aws_db_instance" "ecs_airflow_rds" {
  allocated_storage      = 5
  identifier             = "ecs-airflow"
  storage_type           = "gp2"
  engine                 = "postgres"
  engine_version         = "9.5.4"
  instance_class         = "db.t2.micro"
  name                   = "${var.postgres_name}"
  username               = "${var.postgres_username}"
  password               = "${var.postgres_password}"
  publicly_accessible    = true
  vpc_security_group_ids = ["${aws_security_group.ecs_security_group.id}"]
  db_subnet_group_name   = "${aws_db_subnet_group.rds_subnet_group.id}"
  skip_final_snapshot    = true
  tags {
    name = "ecs_airflow"
  }
}

################################################################
# Creating subnet_group for redis
################################################################

resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name       = "redis-subnet-group"
  subnet_ids = ["${aws_subnet.ecs_subnet_1.id}", "${aws_subnet.ecs_subnet_2.id}"]
}

################################################################
# Adding a Redis Cluster
################################################################

resource "aws_elasticache_cluster" "ecs_ariflow_redis_cluster" {
  cluster_id           = "ecs-airflow-redis"
  engine               = "redis"
  node_type            = "cache.t2.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis5.0"
  engine_version       = "5.0.0"
  port                 = 6379
  subnet_group_name    = "${aws_elasticache_subnet_group.redis_subnet_group.id}"
  security_group_ids   = ["${aws_security_group.ecs_security_group.id}"]
}

#############################################################
# Defining ourputs
#############################################################

output "ecs_airflow_efs_id" {
  value = "${aws_efs_file_system.ecs_airflow_efs.id}"
}

output "ecs_airflow_redis_address" {
  value = "${aws_elasticache_cluster.ecs_ariflow_redis_cluster.cache_nodes.0.address}"
}