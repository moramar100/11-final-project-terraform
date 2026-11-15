data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  subnet_layout = {
    for idx, az in slice(data.aws_availability_zones.available.names, 0, 2) : az => {
      index        = idx
      public_cidr  = cidrsubnet(var.vpc_cidr, 8, idx)
      private_cidr = cidrsubnet(var.vpc_cidr, 8, idx + 10)
    }
  }
}

resource "aws_vpc" "app" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${local.name}-vpc" }
}

resource "aws_internet_gateway" "app" {
  vpc_id = aws_vpc.app.id
  tags   = { Name = "${local.name}-igw" }
}

resource "aws_subnet" "public" {
  for_each                = local.subnet_layout
  vpc_id                  = aws_vpc.app.id
  availability_zone       = each.key
  cidr_block              = each.value.public_cidr
  map_public_ip_on_launch = true
  tags                    = { Name = "${local.name}-public-${each.key}" }
}

resource "aws_subnet" "private" {
  for_each                = local.subnet_layout
  vpc_id                  = aws_vpc.app.id
  availability_zone       = each.key
  cidr_block              = each.value.private_cidr
  map_public_ip_on_launch = false
  tags                    = { Name = "${local.name}-private-${each.key}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.app.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.app.id
  }
  tags = { Name = "${local.name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.app.id
  tags   = { Name = "${local.name}-private-rt" }
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "alb" {
  name        = "${local.name}-alb-sg"
  description = "Public HTTP access to the voting app"
  vpc_id      = aws_vpc.app.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${local.name}-alb-sg" }
}

resource "aws_security_group" "ecs" {
  name        = "${local.name}-ecs-sg"
  description = "App tasks accept HTTP only from the load balancer"
  vpc_id      = aws_vpc.app.id
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${local.name}-ecs-sg" }
}

resource "aws_security_group" "redis" {
  name        = "${local.name}-redis-sg"
  description = "Redis access from app tasks"
  vpc_id      = aws_vpc.app.id
  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }
  tags = { Name = "${local.name}-redis-sg" }
}

resource "aws_security_group" "rds" {
  name        = "${local.name}-rds-sg"
  description = "Postgres access from app tasks"
  vpc_id      = aws_vpc.app.id
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }
  tags = { Name = "${local.name}-rds-sg" }
}

resource "aws_lb" "app" {
  name               = "${local.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [for subnet in aws_subnet.public : subnet.id]
  tags               = { Name = "${local.name}-alb" }
}

resource "aws_lb_target_group" "vote" {
  name        = "${local.name}-vote"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.app.id
  health_check {
    path    = "/healthz"
    matcher = "200"
  }
  tags = { Name = "${local.name}-vote" }
}

resource "aws_lb_target_group" "result" {
  name        = "${local.name}-result"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.app.id
  health_check {
    path    = "/healthz"
    matcher = "200"
  }
  tags = { Name = "${local.name}-result" }
}

resource "aws_lb_listener" "vote" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.vote.arn
  }
}

resource "aws_lb_listener" "result" {
  load_balancer_arn = aws_lb.app.arn
  port              = 8080
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.result.arn
  }
}
