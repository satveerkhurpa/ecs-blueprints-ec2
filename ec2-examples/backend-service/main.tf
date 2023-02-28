provider "aws" {
  region = local.region
}

data "aws_caller_identity" "current" {}

locals {
  name   = "ecsdemo-backend"
  region = var.aws_region

  container_port             = var.container_port
  container_name             = var.container_name
  image                      = var.container_image
  ec2_capacity_provider_name = var.cp_provider_name

  tags = {
    Blueprint = local.name
  }


  tag_val_vpc            = var.vpc_tag_value
  tag_val_private_subnet = var.private_subnets_tag_value
}

################################################################################
# ECS Blueprint
################################################################################
module "service_task_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "${local.name}-task-sg"
  description = "Security group for service task"
  vpc_id      = data.aws_vpc.vpc.id

  ingress_cidr_blocks = [data.aws_vpc.vpc.cidr_block]
  egress_rules        = ["all-all"]
  ingress_with_cidr_blocks = [
    {
      from_port   = local.container_port
      to_port     = local.container_port
      protocol    = "tcp"
      description = "User-service ports"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  tags = local.tags
}

module "ecs_service_definition" {
  source = "../../modules/ecs-service"

  name           = local.name
  desired_count  = var.desired_count
  ecs_cluster_id = data.aws_ecs_cluster.core_infra.cluster_name
  cp_name        = local.ec2_capacity_provider_name

  security_groups = [module.service_task_security_group.security_group_id]
  subnets         = data.aws_subnets.private.ids

  deployment_controller = "ECS"

  # Task Definition
  attach_task_role_policy = false
  container_name          = local.container_name
  container_port          = local.container_port
  cpu                     = var.task_cpu
  memory                  = var.task_memory
  image                   = local.image
  # sidecar_container_definitions = var.sidecar_container_definitions
  execution_role_arn = data.aws_iam_role.ecs_core_infra_exec_role.arn

  tags = local.tags
}

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

data "aws_ecs_cluster" "core_infra" {
  cluster_name = var.ecs_cluster_name == "" ? var.core_stack_name : var.ecs_cluster_name
}

data "aws_iam_role" "ecs_core_infra_exec_role" {
  name = var.ecs_task_execution_role_name == "" ? "${var.core_stack_name}-execution" : var.ecs_task_execution_role_name
}

