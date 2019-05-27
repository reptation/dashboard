provider "aws" {

#  access_key = "${var.aws_access_key}"
# use AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY env vars
#  secret_key = "${var.aws_secret_key}"
  region     = "us-east-1"
}

resource "aws_vpc" "main" {
    cidr_block = "10.0.0.0/16"
    
    tags = {
        Name = "us-east-1-vpc-1"
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
  }
}


resource "aws_subnet" "dash1" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Dash3"
  }
}

resource "aws_subnet" "dash2" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "Dash2"
  }
}

resource "aws_subnet" "dash3" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "10.0.3.0/24"
  availability_zone = "us-east-1c"

  tags = {
    Name = "Dash3"
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
  }
}


resource "aws_s3_bucket" "rescale-dash" {
  bucket = "rescale-dash-b313ed6f5258"
  acl    = "private"

  tags = {
    Name        = "Dashboard Logs"
    Environment = "Prod"
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
  instance_type = "t2.microao"
  security_groups = ["${aws_security_group.lb_sg_1.id}", "${aws_security_group.lb_sg_2.id}"]
}

#module "ec2_cluster" {
#  source                 = "terraform-aws-modules/ec2-instance/aws"
#  version                = "1.21.0"
#
#  name                   = "rescale-dashboard-prod"
#  instance_count         = 3
## pre-baked AMI in us-east-1
#  ami                    = "${data.aws_ami.dashboard.id}"
##  ami                    = "ami-0014b1e550cfc2062"
#  instance_type          = "t2.micro"
##  key_name               = "user1"
#  monitoring             = true
#  vpc_security_group_ids = ["${aws_security_group.lb_sg_1.id}", "${aws_security_group.lb_sg_2.id}"]
#  subnet_ids              = ["${aws_subnet.dash1.id}", "${aws_subnet.dash2.id}","${aws_subnet.dash3.id}"]
#
#  tags = {
#    Terraform = "true"
#    Environment = "prod"
#  }
#}
