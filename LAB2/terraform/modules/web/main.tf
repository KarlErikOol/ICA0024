# One web tier: an internet-facing Application Load Balancer in front of an
# auto-scaling group that launches servers from the Lab 1 AMI. The servers
# accept HTTP only from the load balancer and have no SSH access at all.

# --- security groups -------------------------------------------------------

resource "aws_security_group" "alb" {
  name        = "${var.name}-alb"
  description = "HTTP from the internet to the ${var.name} load balancer"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "web" {
  name        = "${var.name}-web"
  description = "HTTP from the ${var.name} load balancer only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP from the load balancer"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Outbound for package updates.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- servers ---------------------------------------------------------------

# The provider's default_tags don't reach instances an ASG launches, so copy
# them into the launch template.
data "aws_default_tags" "this" {}

resource "aws_launch_template" "web" {
  name_prefix            = "${var.name}-"
  image_id               = var.ami_id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.web.id]
  update_default_version = true

  # nginx is baked into the AMI; this only writes a page naming the instance.
  user_data = base64encode(templatefile("${path.module}/user_data.sh.tftpl", {
    env = var.env
  }))

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # IMDSv2 only
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(data.aws_default_tags.this.tags, { Name = "${var.name}-web" })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = merge(data.aws_default_tags.this.tags, { Name = "${var.name}-web" })
  }
}

resource "aws_autoscaling_group" "web" {
  name                = "${var.name}-asg"
  vpc_zone_identifier = var.subnet_ids # one subnet per AZ, so servers spread across AZs
  min_size            = var.min_size
  max_size            = var.max_size
  # desired_capacity is left to AWS (starts at min_size, then the scaling
  # policy moves it), so Terraform doesn't undo scaling on the next apply.

  target_group_arns         = [aws_lb_target_group.web.arn]
  health_check_type         = "ELB" # replace servers the load balancer marks unhealthy
  health_check_grace_period = 60
  min_elb_capacity          = var.min_size # on create, wait until this many pass health checks

  launch_template {
    id      = aws_launch_template.web.id
    version = aws_launch_template.web.latest_version
  }

  # A new AMI or any launch template change replaces the servers a few at a
  # time, keeping at least half of them in service.
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }
}

resource "aws_autoscaling_policy" "cpu" {
  name                   = "${var.name}-cpu-50"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50
  }
}

# --- load balancer ---------------------------------------------------------

resource "aws_lb" "web" {
  name               = "${var.name}-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.subnet_ids
}

resource "aws_lb_target_group" "web" {
  name                 = "${var.name}-tg"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  deregistration_delay = 30

  health_check {
    path                = "/"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
