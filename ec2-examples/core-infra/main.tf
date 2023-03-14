provider "aws" {
  region = local.region
}

data "aws_availability_zones" "available" {}
data "aws_region" "current" {}

locals {
  name   = var.core_stack_name
  region = var.aws_region

 user_data = <<-EOT
    #!/bin/bash
    cat <<'EOF' >> /etc/ecs/ecs.config
    ECS_CLUSTER=${local.name}
    ECS_LOGLEVEL=debug
    EOF

    sudo yum update -y
    sudo yum install -y jq aws-cli
    myValue=$(aws secretsmanager get-secret-value --region us-west-2 --secret-id cifs-creds --query SecretString --output text | jq -r .secureuser)
    echo $myValue > /var/log/echoSecret.txt

    username=$(aws secretsmanager get-secret-value --region us-west-2 --secret-id cifs-creds --query SecretString --output text| jq -r '. | keys[]')
    password=$(aws secretsmanager get-secret-value --region us-west-2 --secret-id cifs-creds --query SecretString --output text| jq -r '.[]')

    
  EOT

  tags = {
    Blueprint = local.name
    Team      = "HazelTree"
  }

  task_execution_role_managed_policy_arn = ["arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess",
  "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]

  #Local variables to lookup the vpc details.
  tag_val_vpc            = var.vpc_tag_value == "" ? var.core_stack_name : var.vpc_tag_value
  tag_val_private_subnet = var.private_subnets_tag_value == "" ? "${var.core_stack_name}-private-" : var.private_subnets_tag_value
}

################################################################################
# ECS Blueprint
################################################################################

module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "~> 4.0"

  cluster_name = local.name

  cluster_configuration = {
    execute_command_configuration = {
      logging = "OVERRIDE"
      log_configuration = {
        cloud_watch_log_group_name = aws_cloudwatch_log_group.this.name
      }
    }
  }
  # Autoscaling Based Capacity Provider
  autoscaling_capacity_providers = {
    cp-one = {
      auto_scaling_group_arn         = module.asg.autoscaling_group_arn
      managed_termination_protection = "ENABLED"

      managed_scaling = {
        maximum_scaling_step_size = 100
        minimum_scaling_step_size = 1
        status                    = "ENABLED"
        target_capacity           = 100
      }
    }
  }

  tags = local.tags
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/ecs/${local.name}"
  retention_in_days = 7

  tags = local.tags
}

################################################################################
# Task Execution Role
################################################################################

resource "aws_iam_role" "execution" {
  name               = "${local.name}-execution"
  assume_role_policy = data.aws_iam_policy_document.execution.json
  # managed_policy_arns = local.task_execution_role_managed_policy_arn
  tags = local.tags
}

data "aws_iam_policy_document" "execution" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy_attachment" "execution" {
  count      = length(local.task_execution_role_managed_policy_arn)
  name       = "${local.name}-execution-policy"
  roles      = [aws_iam_role.execution.name]
  policy_arn = local.task_execution_role_managed_policy_arn[count.index]
}


###################
# VPC Data sources
###################

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

################################################################################
# Launch Template Security Group
################################################################################
resource "aws_security_group" "ecs_container-instance_sg" {
  name        = "container_instance_sg"
  description = "Allow http inbound traffic"
  vpc_id      = data.aws_vpc.vpc.id

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.vpc.cidr_block]
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Container Instance Security Group"
  }
}

################################################################################
# Auto Scaling Group with Launch Template
################################################################################
# Fetching AWS AMI
data "aws_ami" "ecs_optimized" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-2.0.20220831-x86_64-ebs"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

module "asg" {
  source = "terraform-aws-modules/autoscaling/aws"
  # Autoscaling group
  name = "${local.name}-asg"

  min_size              = var.min_size
  max_size              = var.max_size
  desired_capacity      = var.desired_capacity
  vpc_zone_identifier   = data.aws_subnets.private.ids
  protect_from_scale_in = true

  # Launch template
  launch_template_name        = "${local.name}-launch_template"
  launch_template_description = "Launch template example"
  update_default_version      = true

  image_id          = data.aws_ami.ecs_optimized.image_id
  instance_type     = var.instance_type
  ebs_optimized     = true
  enable_monitoring = true
  user_data         = base64encode(local.user_data)

  # IAM instance profile
  create_iam_instance_profile = true
  iam_role_name               = "${local.name}-instance-role"
  iam_role_path               = "/"
  iam_role_description        = "IAM role for ECS Container Instance"
  iam_role_tags = {
    CustomIamRole = "Yes"
  }
  iam_role_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role",
    CloudWatchLogsAccess         = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess",
    GetCIFSSecrets               = "arn:aws:iam::506556589049:policy/GetCIFSSecrets" #Read secrets from Secrets Manager
  }

  security_groups = [aws_security_group.ecs_container-instance_sg.id]

  block_device_mappings = [
    {
      # Root volume
      device_name = "/dev/xvda"
      no_device   = 0
      ebs = {
        delete_on_termination = true
        encrypted             = true
        volume_size           = var.volume_size
        volume_type           = var.volume_type
      }
    }
  ]
  tags = local.tags
}