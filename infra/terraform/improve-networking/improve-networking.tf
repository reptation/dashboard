variable region {}
variable git_branch {}

provider "aws" {

#  access_key = "${var.aws_access_key}"
# use AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY env vars
#  secret_key = "${var.aws_secret_key}"
  region     = "${var.region}"
#  git_branch = "${var.git_branch}"  
}



resource "aws_vpc" "main" {
    cidr_block = "10.0.0.0/16"
    
    tags = {
        Name = "${var.region}-vpc-1-terraform"
        Creator = "terraform"
    }
}

resource "aws_main_route_table_association" "main" {
  vpc_id         = "${aws_vpc.main.id}"
  route_table_id = "${aws_route_table.r.id}"
}

resource "aws_route_table_association" "dash1" {
  route_table_id = "${aws_route_table.r.id}"
  subnet_id = "${aws_subnet.dash1.id}"
}

resource "aws_route_table_association" "dash2" {
  route_table_id = "${aws_route_table.r.id}"
  subnet_id = "${aws_subnet.dash2.id}"
}

resource "aws_route_table_association" "dash3" {
  route_table_id = "${aws_route_table.r.id}"
  subnet_id = "${aws_subnet.dash3.id}"
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"

  tags = {
    Name = "main"
    Creator = "terraform"
  }
}


resource "aws_subnet" "dash1" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "10.0.1.0/24"
  availability_zone = "${var.region}a"

  tags = {
    Name = "Dash1"
    Creator = "terraform"
  }
}

resource "aws_subnet" "dash2" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "10.0.2.0/24"
  availability_zone = "${var.region}b"

  tags = {
    Name = "Dash2"
    Creator = "terraform"
  }
}

resource "aws_subnet" "dash3" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "10.0.3.0/24"
  availability_zone = "${var.region}c"

  tags = {
    Name = "Dash3"
    Creator = "terraform"
  }
}

# f subnet intended to be private (db, etc.)
resource "aws_subnet" "dash4" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "10.0.4.0/24"
  availability_zone = "${var.region}f"

  tags = {
    Name = "Dash4"
    Creator = "terraform"
  }
}

resource "aws_route_table" "r" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  tags = {
    Name = "main"
    Creator = "terraform"
  }
}

resource "aws_default_security_group" "default" {
  vpc_id = "${aws_vpc.main.id}"

  ingress {
    protocol  = -1
    self      = true
    from_port = 0
    to_port   = 0
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "lb_sg_1" {
  name        = "public_tcp_port_80"
  description = "Allow inbound traffic port 80"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    from_port   = "80"
    to_port     = "80"
    protocol    = "tcp"
    # Please restrict your ingress to only necessary IPs and ports.
    # Opening to 0.0.0.0/0 can lead to security vulnerabilities.
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_all"
    Port_Number = "80"
    Creator = "terraform"
  }
}

resource "aws_security_group" "lb_sg_2" {
  name        = "public_tcp_port_5000"
  description = "Allow inbound traffic port 5000"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    from_port   = "5000"
    to_port     = "5000"
    protocol    = "tcp"
    # Please restrict your ingress to only necessary IPs and ports.
    # Opening to 0.0.0.0/0 can lead to security vulnerabilities.
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_all"
    Port_Number = "5000"
    Creator = "terraform"

  }
}


resource "aws_s3_bucket" "rescale-dash" {
  bucket = "rescale-dash-b313ed6f5258"
  acl    = "private"

  tags = {
    Name        = "Dashboard Logs"
    Environment = "Prod"
    Creator     = "terraform"
  }
}

module "alb" {
  source                        = "terraform-aws-modules/alb/aws"
  load_balancer_name            = "dashboard-alb"
  security_groups               = ["${aws_security_group.lb_sg_1.id}", "${aws_security_group.lb_sg_2.id}"]
# TODO: resolve 400 error with S3 logging bucket
  logging_enabled               = false
#  log_bucket_name               = "${aws_s3_bucket.rescale-dash.id}"
#  log_location_prefix           = "my-alb-logs"
# subnet f not on lb
  subnets                       = ["${aws_subnet.dash1.id}", "${aws_subnet.dash2.id}","${aws_subnet.dash3.id}"]
  tags                          = "${map("Environment", "test")}"
  vpc_id                        = "${aws_vpc.main.id}"
# TODO: add ssl 
#  https_listeners               = "${list(map("certificate_arn", "arn:aws:iam::123456789012:server-certificate/test_cert-123456789012", "port", 443))}"
#  https_listeners_count         = "1"
  http_tcp_listeners            = "${list(map("port", "80", "protocol", "HTTP"))}"
  http_tcp_listeners_count      = "1"
  target_groups                 = "${list(map("name", "dash-workers", "backend_protocol", "HTTP", "backend_port", "5000"))}"
  target_groups_count           = "1"
}

data "aws_ami" "dashboard" {
  most_recent = true
  owners = ["self"]
  filter {                       
    name = "name"
    values = ["rescale-dashboard-ami-prod"]
  } 
}


resource "aws_autoscaling_group" "dash-asg" {
  name_prefix          = "dash-alb"
  max_size             = 3
  min_size             = 1
  desired_capacity     = 3
  launch_configuration = "${aws_launch_configuration.dash-lc.name}"
  health_check_type    = "EC2"
  target_group_arns    = ["${module.alb.target_group_arns}"]
  force_delete         = true
  vpc_zone_identifier  = ["${aws_subnet.dash1.id}", "${aws_subnet.dash2.id}","${aws_subnet.dash3.id}"]
#  vpc_zone_identifier  = ["${module.vpc.public_subnets}"]
}

resource "aws_launch_configuration" "dash-lc" {
  name_prefix   = "dash_lc"
  image_id      = "${data.aws_ami.dashboard.id}"
  instance_type = "t2.micro"
  security_groups = ["${aws_security_group.lb_sg_1.id}", "${aws_security_group.lb_sg_2.id}"]
  lifecycle {
    create_before_destroy = true
  }
}

module "db" {
  source = "terraform-aws-modules/rds/aws"
  
  identifier        = "dash-db-${var.git_branch}"
  engine            = "postgresql"
  engine_version    = "11.2"
  instance_class    = "db.t2.micro"
  allocated_storage = 5

  name     = "demodb"
  username = "demouser"
  password = "YourPwdShouldBeLongAndSecure!"
  port     = "5432"

  iam_database_authentication_enabled = true
  vpc_security_group_ids = ["${aws_default_security_group.default.id}"]
  maintenance_window = "Mon:00:00-Mon:03:00"
  backup_window      = "03:00-06:00"

  # disable backups to create DB faster
  backup_retention_period   = 0

  # Enhanced Monitoring - see example for details on how to create the role
  # by yourself, in case you don't want to create it automatically
  monitoring_interval = "30"
  monitoring_role_name = "TerraformRDSMonitoringRole-${var.git_branch}"
  create_monitoring_role = true
  
  tags = {
    Creator       = "terraform"
    Environment = "${var.git_branch}"
  }

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  subnet_ids = ["${aws_subnet.dash4.id}"]

  # DB parameter group
  family = "postgres11.2"

  # DB option group
  major_engine_version = "11.2"

  # Snapshot name upon DB deletion
  final_snapshot_identifier = "demodb"

  # Database Deletion Protection
  deletion_protection = false
}
  

