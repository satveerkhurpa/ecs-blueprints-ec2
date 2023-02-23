provider "aws" {
  region = local.region
}

data "aws_caller_identity" "current" {}

locals {
  name   = "ecsdemo-backend"
  region = var.aws_region

  container_port             = var.container_port
  container_name             = var.container_name
  image                      = "581611100341.dkr.ecr.us-west-2.amazonaws.com/ecsdemo:latest"
  ec2_capacity_provider_name = var.cp_provider_name

  tags = {
    Blueprint = local.name
  }


  tag_val_vpc            = var.vpc_tag_value == "" ? var.core_stack_name : var.vpc_tag_value
  tag_val_private_subnet = var.private_subnets_tag_value == "" ? "${var.core_stack_name}-private-" : var.private_subnets_tag_value
  tag_val_public_subnet  = var.public_subnets_tag_value == "" ? "${var.core_stack_name}-public-" : var.public_subnets_tag_value
}

################################################################################
# ECS Blueprint
################################################################################

# module "container_image_ecr" {
#   source  = "terraform-aws-modules/ecr/aws"
#   version = "~> 1.4"

#   repository_name = local.container_name
#   # repository_force_delete           = true
#   create_lifecycle_policy     = false
#   repository_read_access_arns = [one(data.aws_iam_roles.ecs_core_infra_exec_role.arns)]
#   # repository_read_write_access_arns = [module.codepipeline_ci_cd.codepipeline_role_arn]

#   tags = local.tags
# }

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

resource "aws_service_discovery_service" "this" {
  name = local.name

  dns_config {
    namespace_id = data.aws_service_discovery_dns_namespace.sd_namespace.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

module "ecs_service_definition" {
  source = "../../modules/ecs-service"

  name           = local.name
  desired_count  = var.desired_count
  ecs_cluster_id = data.aws_ecs_cluster.core_infra.cluster_name
  cp_name        = local.ec2_capacity_provider_name
  # cp_strategy_base       = var.cp_strategy_base
  # cp_strategy_ec2_weight = var.cp_strategy_ec2_weight

  security_groups = [module.service_task_security_group.security_group_id]
  subnets         = data.aws_subnets.private.ids

  service_registry_list = [{
    registry_arn = aws_service_discovery_service.this.arn
  }]
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

################################################################################
# CodePipeline and CodeBuild for CI/CD
################################################################################

# module "codepipeline_s3_bucket" {
#   source  = "terraform-aws-modules/s3-bucket/aws"
#   version = "~> 3.0"

#   bucket = "codepipeline-${local.region}-${random_id.this.hex}"
#   acl    = "private"

#   # For example only - please re-evaluate for your environment
#   force_destroy = true

#   attach_deny_insecure_transport_policy = true
#   attach_require_latest_tls_policy      = true

#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true

#   server_side_encryption_configuration = {
#     rule = {
#       apply_server_side_encryption_by_default = {
#         sse_algorithm = "AES256"
#       }
#     }
#   }

#   tags = local.tags
# }

# resource "aws_sns_topic" "codestar_notification" {
#   name = local.name

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid      = "WriteAccess"
#         Effect   = "Allow"
#         Action   = "sns:Publish"
#         Resource = "arn:aws:sns:${local.region}:${data.aws_caller_identity.current.account_id}:${local.name}"
#         Principal = {
#           Service = "codestar-notifications.amazonaws.com"
#         }
#       },
#     ]
#   })

#   tags = local.tags
# }

# module "codebuild_ci" {
#   source = "../../modules/codebuild"

#   name           = module.ecs_service_definition.name
#   service_role   = module.codebuild_ci.codebuild_role_arn
#   buildspec_path = "./application-code/ecsdemo-nodejs/templates/buildspec.yml"
#   s3_bucket      = module.codepipeline_s3_bucket

#   environment = {
#     privileged_mode = true
#     environment_variables = [
#       {
#         name  = "REPO_URL"
#         value = module.container_image_ecr.repository_url
#         }, {
#         name  = "TASK_DEFINITION_FAMILY"
#         value = module.ecs_service_definition.task_definition_family
#         }, {
#         name  = "CONTAINER_NAME"
#         value = local.container_name
#         }, {
#         name  = "SERVICE_PORT"
#         value = local.container_port
#         }, {
#         name  = "FOLDER_PATH"
#         value = "./application-code/ecsdemo-nodejs/."
#         }, {
#         name  = "ECS_EXEC_ROLE_ARN"
#         value = one(data.aws_iam_roles.ecs_core_infra_exec_role.arns)
#       },
#     ]
#   }

#   create_iam_role = true
#   iam_role_name   = "${module.ecs_service_definition.name}-codebuild"
#   ecr_repository  = module.container_image_ecr.repository_arn

#   tags = local.tags
# }

# module "codepipeline_ci_cd" {
#   source = "../../modules/codepipeline"

#   name         = "pipeline-${module.ecs_service_definition.name}"
#   service_role = module.codepipeline_ci_cd.codepipeline_role_arn
#   s3_bucket    = module.codepipeline_s3_bucket
#   sns_topic    = aws_sns_topic.codestar_notification.arn

#   stage = [{
#     name = "Source"
#     action = [{
#       name             = "Source"
#       category         = "Source"
#       owner            = "ThirdParty"
#       provider         = "GitHub"
#       version          = "1"
#       input_artifacts  = []
#       output_artifacts = ["SourceArtifact"]
#       configuration = {
#         OAuthToken           = data.aws_secretsmanager_secret_version.github_token.secret_string
#         Owner                = var.repository_owner
#         Repo                 = var.repository_name
#         Branch               = var.repository_branch
#         PollForSourceChanges = true
#       }
#     }],
#     }, {
#     name = "Build"
#     action = [{
#       name             = "Build_app"
#       category         = "Build"
#       owner            = "AWS"
#       provider         = "CodeBuild"
#       version          = "1"
#       input_artifacts  = ["SourceArtifact"]
#       output_artifacts = ["BuildArtifact_app"]
#       configuration = {
#         ProjectName = module.codebuild_ci.project_id
#       }
#     }],
#     }, {
#     name = "Deploy"
#     action = [{
#       name            = "Deploy_app"
#       category        = "Deploy"
#       owner           = "AWS"
#       provider        = "ECS"
#       version         = "1"
#       input_artifacts = ["BuildArtifact_app"]
#       configuration = {
#         ClusterName = data.aws_ecs_cluster.core_infra.cluster_name
#         ServiceName = module.ecs_service_definition.name
#         FileName    = "imagedefinition.json"
#       }
#     }],
#   }]

#   create_iam_role = true
#   iam_role_name   = "${module.ecs_service_definition.name}-pipeline"

#   tags = local.tags
# }

################################################################################
# Supporting Resources
################################################################################

# resource "random_id" "this" {
#   byte_length = "2"
# }

# data "aws_secretsmanager_secret" "github_token" {
#   name = var.github_token_secret_name
# }

# data "aws_secretsmanager_secret_version" "github_token" {
#   secret_id = data.aws_secretsmanager_secret.github_token.id
# }

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

data "aws_service_discovery_dns_namespace" "sd_namespace" {
  name = "${var.namespace}.${data.aws_ecs_cluster.core_infra.cluster_name}.local"
  type = "DNS_PRIVATE"
}