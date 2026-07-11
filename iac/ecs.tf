# ============================================================
# ecs.tf
# Crea: Cluster ECS, Task Definition, Servicio ECS (Fargate) y Log Group.
# ============================================================

# ── ECS Cluster ───────────────────────────────────────────────
resource "aws_ecs_cluster" "main" {
  name = "${var.project}-cluster-${var.environment}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name        = "${var.project}-cluster-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── CloudWatch Log Group para ECS ─────────────────────────────
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project}-${var.environment}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project}-ecs-logs-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Task Definition ───────────────────────────────────────────
resource "aws_ecs_task_definition" "crud" {
  family                   = "${var.project}-crud-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "crud-backend"
    image     = "${aws_ecr_repository.crud.repository_url}:${var.container_image_tag}"
    essential = true

    portMappings = [{
      containerPort = var.app_port
      protocol      = "tcp"
    }]

    environment = [
      { name = "SPRING_PROFILES_ACTIVE", value = var.environment },
      { name = "SERVER_PORT", value = tostring(var.app_port) }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "crud"
      }
    }
  }])

  tags = {
    Name        = "${var.project}-task-crud-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── ECS Service ───────────────────────────────────────────────
resource "aws_ecs_service" "crud" {
  name            = "${var.project}-crud-service-${var.environment}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.crud.arn
  desired_count   = var.ecs_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.crud.arn
    container_name   = "crud-backend"
    container_port   = var.app_port
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  depends_on = [aws_lb_listener.http]

  tags = {
    Name        = "${var.project}-ecs-service-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}
