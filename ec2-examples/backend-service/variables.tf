variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "task_cpu" {
  description = "The task vCPU size"
  type        = number
}

variable "task_memory" {
  description = "The task memory size"
  type        = string
}

variable "desired_count" {
  description = "The number of task replicas for service"
  type        = number
  default     = 1
}

variable "container_name" {
  description = "The container name to use in service task definition"
  type        = string
  default     = "ecsdemo-frontend"
}

variable "container_port" {
  description = "The container port to serve traffic"
  type        = number
  default     = 3000
}

variable "container_protocol" {
  description = "The container traffic protocol"
  type        = string
  default     = "HTTP"
}

variable "cp_provider_name" {
  description = "Name of the EC2 capacity provider"
  type        = string
}

variable "cp_strategy_base" {
  description = "Base number of tasks to create on Fargate on-demand"
  type        = number
  default     = 0
}

variable "cp_strategy_ec2_weight" {
  description = "Relative number of tasks to put in Fargate"
  type        = number
  default     = 1
}

variable "core_stack_name" {
  description = "The name of core infrastructure stack that you created using core-infra module"
  type        = string
}

variable "vpc_tag_key" {
  description = "The tag key of the VPC and subnets"
  type        = string
  default     = "Name"
}

variable "vpc_tag_value" {
  # if left blank then {core_stack_name} will be used
  description = "The tag value of the VPC and subnets"
  type        = string
  default     = ""
}

variable "private_subnets_tag_value" {
  # if left blank then {core_stack_name}-private- will be used
  description = "The value tag of the private subnets"
  type        = string
  default     = ""
}

variable "ecs_cluster_name" {
  # if left blank then {core_stack_name} will be used
  description = "The ID of the ECS cluster"
  type        = string
  default     = ""
}

variable "ecs_task_execution_role_name" {
  # if left blank then {core_stack_name}-execution will be used
  description = "The ARN of the task execution role"
  type        = string
  default     = ""
}

variable "container_image" {
  description = "Container image from ECR/Container registry"
  type        = string
}