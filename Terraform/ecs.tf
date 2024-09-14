provider "aws" {
  region = "us-east-1" # Change to your region
}

# Create ECS cluster
resource "aws_ecs_cluster" "vprofilestaging" {
  name = "vprofilestaging"
}

# Create an ECS task definition
resource "aws_ecs_task_definition" "vprofilestaging_task" {
  family                   = "vprofilestaging-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  memory                   = "2048" # 2 GB RAM
  cpu                      = "1024" # 1 GB CPU
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  container_definitions = jsonencode([{
      name      = "vprofile-app"
      image     = "211125570623.dkr.ecr.us-east-1.amazonaws.com/vprofileappimg" # Replace with your ECR repository
      essential = true
      memory    = 2048
      cpu       = 1024
      portMappings = [{
        containerPort = 8080
        hostPort      = 8080
        protocol      = "tcp"
      }]
  }])
}

# Create Security Group for Load Balancer
resource "aws_security_group" "lb_sg" {
  name        = "vprofilestaging-lb-sg"
  description = "Security group for load balancer"
  vpc_id      = "vpc-0d0e6a4336759405d" # Replace with your VPC ID

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # Allows all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create Security Group for ECS service
resource "aws_security_group" "ecs_sg" {
  name        = "vprofilestaging-ecs-sg"
  description = "Security group for ECS service"
  vpc_id      = "vpc-0d0e6a4336759405d" # Replace with your VPC ID

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    security_groups = [aws_security_group.lb_sg.id]  # Allow traffic from the load balancer security group
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # Allows all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create the ECS service
resource "aws_ecs_service" "vprofilestaging_service" {
  name            = "vprofilestaging-service"
  cluster         = aws_ecs_cluster.vprofilestaging.id
  task_definition = aws_ecs_task_definition.vprofilestaging_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  load_balancer {
    target_group_arn = aws_lb_target_group.vprofilestaging_target_group.arn
    container_name   = "vprofile-app"
    container_port   = 8080
  }

  network_configuration {
    subnets          = ["subnet-0c1048568e84db447", "subnet-0507610f8da69bac2", "subnet-082501165db7449ff"] # Replace with your subnet IDs
    security_groups  = [aws_security_group.ecs_sg.id]  # Use the ECS service security group
    assign_public_ip = true
  }

  depends_on = [aws_lb_listener.vprofilestaging_listener]
}

# Create Target Group for the Load Balancer
resource "aws_lb_target_group" "vprofilestaging_target_group" {
  name        = "vprofilestaging-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = "vpc-0d0e6a4336759405d" # Replace with your VPC ID
  target_type = "ip"

  health_check {
    port                = "8080"
    protocol            = "HTTP"
    path                = "/login"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

# Create Load Balancer
resource "aws_lb" "vprofilestaging_lb" {
  name               = "vprofilestaging-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]  # Use the Load Balancer security group
  subnets            = ["subnet-0c1048568e84db447", "subnet-0507610f8da69bac2", "subnet-082501165db7449ff"] # Replace with your subnet IDs
}

# Create Load Balancer Listener
resource "aws_lb_listener" "vprofilestaging_listener" {
  load_balancer_arn = aws_lb.vprofilestaging_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.vprofilestaging_target_group.arn
  }
}

# IAM role for ECS task execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.vprofilestaging_lb.dns_name
}
