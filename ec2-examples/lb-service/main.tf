provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

locals {

  # this will get the name of the local directory
  # name   = basename(path.cwd)
  name                       = var.service_name
  image                      = var.container_image
  ec2_capacity_provider_name = var.cp_provider_name

  tags = {
    Blueprint = local.name
  }

  tag_val_vpc            = var.vpc_tag_value
  tag_val_private_subnet = var.private_subnets_tag_value
  tag_val_public_subnet  = var.public_subnets_tag_value

}

################################################################################
# Data Sources from ecs-blueprint-infra
################################################################################

data "aws_vpc" "vpc" {
  filter {
    name   = "tag:${var.vpc_tag_key}"
    values = [local.tag_val_vpc]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "tag:${var.vpc_tag_key}"
    values = ["${local.tag_val_private_subnet}*"]
  }
}

data "aws_subnet" "private_cidr" {
  for_each = toset(data.aws_subnets.private.ids)
  id       = each.value
}

data "aws_subnets" "public" {
  filter {
    name   = "tag:${var.vpc_tag_key}"
    values = ["${local.tag_val_public_subnet}*"]
  }
}

data "aws_ecs_cluster" "core_infra" {
  cluster_name = var.ecs_cluster_name == "" ? var.core_stack_name : var.ecs_cluster_name
}

data "aws_iam_role" "ecs_core_infra_exec_role" {
  name = var.ecs_task_execution_role_name == "" ? "${var.core_stack_name}-execution" : var.ecs_task_execution_role_name
}

################################################################################
# ECS Blueprint
################################################################################

module "service_alb_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "${local.name}-alb-sg"
  description = "Security group for client application"
  vpc_id      = data.aws_vpc.vpc.id

  ingress_rules       = ["http-80-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]

  egress_rules       = ["all-all"]
  egress_cidr_blocks = [for s in data.aws_subnet.private_cidr : s.cidr_block]

  tags = local.tags
}

module "service_alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 7.0"

  name = "${local.name}-alb"

  load_balancer_type = "application"

  vpc_id          = data.aws_vpc.vpc.id
  subnets         = data.aws_subnets.public.ids
  security_groups = [module.service_alb_security_group.security_group_id]

  http_tcp_listeners = [
    {
      port               = var.listener_port
      protocol           = var.listener_protocol
      target_group_index = 0
    },
  ]

  target_groups = [
    {
      name             = "${local.name}-tg"
      backend_protocol = var.container_protocol
      backend_port     = var.container_port
      target_type      = "ip"
      health_check = {
        path    = var.health_check_path
        port    = var.container_port
        matcher = var.health_check_matcher
      }
    },
  ]

  tags = local.tags
}


module "service_task_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "${local.name}-task-sg"
  description = "Security group for service task"
  vpc_id      = data.aws_vpc.vpc.id

  ingress_with_source_security_group_id = [
    {
      from_port                = var.container_port
      to_port                  = var.container_port
      protocol                 = "tcp"
      source_security_group_id = module.service_alb_security_group.security_group_id
    },
  ]

  egress_rules = ["all-all"]

  tags = local.tags
}

module "ecs_service_definition" {
  source                 = "../../modules/ecs-service"
  name                   = local.name
  desired_count          = var.desired_count
  ecs_cluster_id         = data.aws_ecs_cluster.core_infra.cluster_name
  cp_name                = local.ec2_capacity_provider_name
  cp_strategy_base       = var.cp_strategy_base
  cp_strategy_ec2_weight = var.cp_strategy_ec2_weight

  security_groups = [module.service_task_security_group.security_group_id]
  subnets         = data.aws_subnets.private.ids

  load_balancers = [{
    target_group_arn = element(module.service_alb.target_group_arns, 0)
  }]


  deployment_controller = "ECS"

  # Task Definition
  attach_task_role_policy       = false
  container_name                = var.container_name
  container_port                = var.container_port
  cpu                           = var.task_cpu
  memory                        = var.task_memory
  image                         = local.image
  sidecar_container_definitions = var.sidecar_container_definitions
  execution_role_arn            = data.aws_iam_role.ecs_core_infra_exec_role.arn

  tags = local.tags

  # enable_scheduled_autoscaling            = var.enable_scheduled_autoscaling
  # scheduled_autoscaling_timezone          = var.scheduled_autoscaling_timezone
  # scheduled_autoscaling_up_time           = var.scheduled_autoscaling_up_time
  # scheduled_autoscaling_down_time         = var.scheduled_autoscaling_down_time
  # scheduled_autoscaling_up_min_capacity   = var.scheduled_autoscaling_up_min_capacity
  # scheduled_autoscaling_up_max_capacity   = var.scheduled_autoscaling_up_max_capacity
  # scheduled_autoscaling_down_min_capacity = var.scheduled_autoscaling_down_min_capacity
  # scheduled_autoscaling_down_max_capacity = var.scheduled_autoscaling_down_max_capacity
}


################################################################################
# Supporting Resources
################################################################################

resource "random_id" "this" {
  byte_length = "2"
}