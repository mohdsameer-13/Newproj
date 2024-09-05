terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.65.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1a"
}

resource "aws_vpc" "medusa_vpc" {
  cidr_block = var.cidr
}
resource "aws_subnet" "medusa_subnet" {
  vpc_id     = aws_vpc.medusa_vpc.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true
}
resource "aws_internet_gateway" "medusa_igw" {
  vpc_id = aws_vpc.medusa_vpc.id
}
resource "aws_route_table" "medusa_route_table" {
  vpc_id = aws_vpc.medusa_vpc.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.medusa_igw.id
  }
}
resource "aws_ecs_cluster" "medusa_cluster" {
  name = "medusa-cluster"
}
resource "aws_ecs_task_definition" "medusa_task" {
  family                = "medusa-task"
  container_definitions = jsonencode([
    {
      name  = "medusa"
      image = "your-docker-image"
      memory = 512
      cpu    = 256
      essential = true
      portMappings = [{
        containerPort = 80
        hostPort      = 80
      }]
    }
  ])
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = "512"
  cpu                      = "256"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
}
resource "aws_ecs_service" "medusa_service" {
  name            = "medusa-service"
  cluster         = aws_ecs_cluster.medusa_cluster.id
  task_definition = aws_ecs_task_definition.medusa_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets         = [aws_subnet.medusa_subnet.id]
    security_groups = [aws_security_group.medusa_sg.id]
  }
}
resource "aws_security_group" "medusa_sg" {
  vpc_id = aws_vpc.medusa_vpc.id
  ingress {
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
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_instance" "web_server" {
  ami = "ami-0e86e20dae9224db8"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.medusa_sg.id]
  subnet_id = aws_subnet.medusa_subnet.id
}
