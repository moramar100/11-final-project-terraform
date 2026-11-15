data "aws_region" "current" {}

resource "aws_ecs_cluster" "app" {
  name = "${local.name}-cluster"
}

locals {
  common_db_environment = {
    DB_HOST = aws_db_instance.app.address
    DB_PORT = tostring(aws_db_instance.app.port)
    DB_USER = aws_db_instance.app.username
    DB_NAME = aws_db_instance.app.db_name
    DB_SSL  = "true"
  }
  db_secret         = [{ name = "DB_PASSWORD", valueFrom = aws_secretsmanager_secret.db_password.arn }]
  redis_environment = { REDIS_HOST = aws_elasticache_cluster.redis.cache_nodes[0].address }
}

module "vote" {
  source             = "./modules/service"
  name               = "${local.name}-vote"
  image              = "${data.aws_ecr_repository.service["vote"].repository_url}:${var.image_tag}"
  cluster_arn        = aws_ecs_cluster.app.arn
  execution_role_arn = aws_iam_role.task_execution.arn
  subnet_ids         = [for subnet in aws_subnet.public : subnet.id]
  security_group_id  = aws_security_group.ecs.id
  desired_count      = var.desired_count
  region             = data.aws_region.current.name
  environment        = merge(local.redis_environment, { OPTION_A = var.option_a, OPTION_B = var.option_b })
  secrets            = []
  container_port     = 80
  target_group_arn   = aws_lb_target_group.vote.arn
  depends_on         = [aws_lb_listener.vote, aws_iam_role_policy.read_db_secret]
}

module "result" {
  source             = "./modules/service"
  name               = "${local.name}-result"
  image              = "${data.aws_ecr_repository.service["result"].repository_url}:${var.image_tag}"
  cluster_arn        = aws_ecs_cluster.app.arn
  execution_role_arn = aws_iam_role.task_execution.arn
  subnet_ids         = [for subnet in aws_subnet.public : subnet.id]
  security_group_id  = aws_security_group.ecs.id
  desired_count      = var.desired_count
  region             = data.aws_region.current.name
  environment        = local.common_db_environment
  secrets            = local.db_secret
  container_port     = 80
  target_group_arn   = aws_lb_target_group.result.arn
  depends_on         = [aws_lb_listener.result, aws_iam_role_policy.read_db_secret]
}

module "worker" {
  source             = "./modules/service"
  name               = "${local.name}-worker"
  image              = "${data.aws_ecr_repository.service["worker"].repository_url}:${var.image_tag}"
  cluster_arn        = aws_ecs_cluster.app.arn
  execution_role_arn = aws_iam_role.task_execution.arn
  subnet_ids         = [for subnet in aws_subnet.public : subnet.id]
  security_group_id  = aws_security_group.ecs.id
  desired_count      = var.desired_count
  region             = data.aws_region.current.name
  environment        = merge(local.common_db_environment, local.redis_environment)
  secrets            = local.db_secret
  container_port     = null
  target_group_arn   = null
  depends_on         = [aws_iam_role_policy.read_db_secret]
}
