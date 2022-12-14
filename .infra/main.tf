provider "aws" {
  region = "sa-east-1"
  shared_credentials_files = ["../.aws/credentials"]
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.31"
    }
  }

  required_version = ">= 1.2.9"
}

resource "aws_internet_gateway" "this" {
  vpc_id = module.bruno_campos_vpc.vpc_id

  tags = {
    Name = "Internet-Gateway"
  }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_az_a.id
  depends_on    = [aws_internet_gateway.this]

  tags = {
    Name = "Gateway-NAT"
  }
}

resource "aws_eip" "nat" {
  vpc = true
  depends_on = [aws_internet_gateway.this]

  tags = {
    Name = "Elastic"
  }
}
/* Subnet config */
resource "aws_subnet" "public_az_a" {
  vpc_id                  = module.bruno_campos_vpc.vpc_id
  cidr_block              = "10.30.0.0/24"
  availability_zone       = "sa-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "Pub-AZ-A"
  }
}

resource "aws_subnet" "public_az_c" {
  vpc_id                  = module.bruno_campos_vpc.vpc_id
  cidr_block              = "10.30.1.0/24"
  availability_zone       = "sa-east-1c"
  map_public_ip_on_launch = true

  tags = {
    Name = "Pub-AZ-C"
  }
}

resource "aws_subnet" "private_az_a" {
  vpc_id            = module.bruno_campos_vpc.vpc_id
  cidr_block        = "10.30.2.0/24"
  availability_zone = "sa-east-1a"

  tags = {
    Name = "Priv-AZ-A"
  }
}

resource "aws_subnet" "private_az_c" {
  vpc_id            = module.bruno_campos_vpc.vpc_id
  cidr_block        = "10.30.3.0/24"
  availability_zone = "sa-east-1c"

  tags = {
    Name = "Priv-AZ-C"
  }
}

resource "aws_subnet" "db_az_a" {
  vpc_id            = module.bruno_campos_vpc.vpc_id
  cidr_block        = "10.30.4.0/24"
  availability_zone = "sa-east-1a"

  tags = {
    Name = "Db-AZ-A"
  }
}

resource "aws_subnet" "db_az_c" {
  vpc_id            = module.bruno_campos_vpc.vpc_id
  cidr_block        = "10.30.5.0/24"
  availability_zone = "sa-east-1c"

  tags = {
    Name = "Db-AZ-C"
  }
}

/* Private route table config */
resource "aws_route_table" "private" {
  vpc_id = module.bruno_campos_vpc.vpc_id

  route {
    nat_gateway_id = aws_nat_gateway.this.id
    cidr_block = "0.0.0.0/0"
  }

  tags = {
    Name = "Private"
  }
}

resource "aws_route_table_association" "private_az_a" {
  subnet_id      = aws_subnet.private_az_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_az_c" {
  subnet_id      = aws_subnet.private_az_c.id
  route_table_id = aws_route_table.private.id
}

/* Public route table config */
resource "aws_default_route_table" "public" {
  default_route_table_id = module.bruno_campos_vpc.default_route_table_id

  route {
    gateway_id = aws_internet_gateway.this.id
    cidr_block = "0.0.0.0/0"
  }

  tags = {
    Name = "Public"
  }
}

resource "aws_route_table_association" "public_az_a" {
  subnet_id      = aws_subnet.public_az_a.id
  route_table_id = aws_default_route_table.public.id
}

resource "aws_route_table_association" "public_az_c" {
  subnet_id      = aws_subnet.public_az_c.id
  route_table_id = aws_default_route_table.public.id
}

/* VPC */
module "bruno_campos_vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name   = "Bruno-VPC"
  cidr   = "10.30.0.0/16"
  
  enable_dns_hostnames = true

  tags = {
    Name = "Bruno-VPC"
    Terraform = "true"
    Environment = "dev"
  }
}
/* Security Groups */
resource "aws_security_group" "web_server" {
  name        = "Inbound traffic"
  description = "Inbound traffic"
  vpc_id      = module.bruno_campos_vpc.vpc_id

    ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["177.18.133.112/32"]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    security_groups = [aws_security_group.load_balancer.id]
  }

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    security_groups = [aws_security_group.load_balancer.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "Ec2 Instace Security Group"
  }
}

resource "aws_security_group" "database" {
  name        = "Msysql"
  description = "Msysql"
  vpc_id      = module.bruno_campos_vpc.vpc_id

  ingress {
    description      = "MYSQL/Aurora"
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    security_groups  = [aws_security_group.web_server.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "RDS Security Group"
  }
}

resource "aws_security_group" "load_balancer" {
  name        = "Load balancer rules"
  description = "Load balancer rules"
  vpc_id      = module.bruno_campos_vpc.vpc_id

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Load balancer security group"
  }
}

resource "aws_security_group_rule" "egress_lb_instance_http" {
  security_group_id        = aws_security_group.load_balancer.id
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  type                     = "egress"
  source_security_group_id = aws_security_group.web_server.id
}

resource "aws_security_group_rule" "egress_lb_instance_https" {
  security_group_id        = aws_security_group.load_balancer.id
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  type                     = "egress"
  source_security_group_id = aws_security_group.web_server.id
}

/* EC2 */
resource "aws_instance" "base_image" {
  ami                         = "ami-08ae71fd7f1449df1"
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.web_server.id]
  monitoring                  = true
  subnet_id                   = aws_subnet.public_az_a.id
  availability_zone           = "sa-east-1a"
  associate_public_ip_address = true
  key_name                    = "wordpress-boilerplate"

  tags = {
    Name = "web-server"
  }
}

resource "aws_ami_from_instance" "custom_ami" {
  name               = "custom_ami"
  source_instance_id = aws_instance.base_image.id
  depends_on = [
    module.rds_database,
    aws_elb.wordpress_elb,
    local_file.tf_ansible_vars,
    null_resource.provisioner
  ]
}

resource "null_resource" "provisioner" {
  depends_on = [
    local_file.tf_ansible_vars
  ]
  provisioner "remote-exec" {
    inline = ["echo 'Configurando Wordpress'"]

    connection {
      type = "ssh"
      user = "ubuntu"
      private_key = file("../.aws/wordpress-boilerplate.pem")
      host = aws_instance.base_image.public_ip
    }
  }

  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i ${aws_instance.base_image.public_ip}, --private-key \"../.aws/wordpress-boilerplate.pem\" \"../.ansi/wordpress.yml\""
  }
}

resource "aws_launch_template" "this" {
  name_prefix   = "asg_launch_template"
  image_id = aws_ami_from_instance.custom_ami.id
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.web_server.id]
  key_name = "wordpress-boilerplate"
}

resource "aws_autoscaling_group" "this" {
  launch_template {
    id = aws_launch_template.this.id
    version = "$Latest"
  }

  name                = "asg"
  vpc_zone_identifier = [aws_subnet.private_az_a.id, aws_subnet.private_az_c.id]

  min_size             = 2
  max_size             = 4
  desired_capacity     = 2
  termination_policies = ["OldestInstance"]

  health_check_type         = "ELB"
  health_check_grace_period = 90    # Seconds

  lifecycle {
    # see notes in https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_attachment
    ignore_changes = [desired_capacity, load_balancers, target_group_arns]
  }
}

resource "aws_autoscaling_policy" "http" {
  count = 1
  name = "auto_scalling_policy"
  adjustment_type = "ChangeInCapacity"
  policy_type = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 80.0
  }

  autoscaling_group_name = aws_autoscaling_group.this.name
}

resource "aws_autoscaling_attachment" "asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.this.id
  elb                    = aws_elb.wordpress_elb.id
}

resource "aws_key_pair" "wordpress-boilerplate" {
  key_name   = "wordpress-boilerplate"
  public_key = file("../.aws/wordpress-boilerplate.pub")
}

module "rds_database" {
  source  = "terraform-aws-modules/rds/aws"
  identifier = "rds-database"

  engine            = "mysql"
  engine_version    = "5.7.38"
  instance_class    = "db.t2.micro"
  allocated_storage = 20
  storage_encrypted = false

  db_name  = var.db_name
  username = var.username
  password = var.password
  port     = "3306"
  multi_az = true

  vpc_security_group_ids = [aws_security_group.database.id]
  create_random_password = false

  skip_final_snapshot = true
  create_db_subnet_group = true
  subnet_ids = [aws_subnet.db_az_a.id, aws_subnet.db_az_c.id]

  # DB parameter group
  family = "mysql5.7"

  # DB option group
  major_engine_version = "5.7"

  parameters = [
    {
      name = "character_set_client"
      value = "utf8mb4"
    },
    {
      name = "character_set_server"
      value = "utf8mb4"
    }
  ]
}

resource "local_file" "tf_ansible_vars" {
  content = <<-DOC
    db_name: "${var.db_name}"
    db_user: "${var.username}"
    db_pass: "${var.password}"
    db_host: "${module.rds_database.db_instance_endpoint}"
    lb_dns: "${aws_elb.wordpress_elb.dns_name}"
  DOC
  filename = "../.ansi/defaults/tf_ansible_vars.yml"

  depends_on = [
    module.rds_database,
    aws_elb.wordpress_elb
  ]
}

resource "aws_elb" "wordpress_elb" {
  name               = "wordpress-elb"
  subnets            = [aws_subnet.public_az_a.id, aws_subnet.public_az_c.id]
  security_groups    = [aws_security_group.load_balancer.id]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  listener {
    instance_port      = 443
    instance_protocol  = "tcp"
    lb_port            = 443
    lb_protocol        = "tcp"
  }
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/info.php"
    interval            = 30
  }

  instances                   = [aws_instance.base_image.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name = "wordpress_elb"
  }
}