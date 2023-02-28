variable "core_stack_name" {
  description = "The name of Core Infrastructure stack, feel free to rename it. Used for cluster and VPC names."
  type        = string
  default     = "ecs-blueprint-infra"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}
variable "instance_type" {
  type        = string
  description = "ECS Container Instance Instance Type"
  default     = "c6a.2xlarge"
}

variable "asg_name" {
  type        = string
  description = "Name of the AutoScaling Group"
  default     = "ecs_blueprint_asg"
}

variable "desired_capacity" {
  type        = number
  description = "Desire Capacity Of AutoScalingGroup"
  default     = 1
}

variable "max_size" {
  type        = number
  description = "Maximum Size Of AutoScalingGroup"
  default     = 4
}

variable "min_size" {
  type        = number
  description = "Minimum Size Of AutoScalingGroup"
  default     = 1
}

variable "launch_name" {
  type        = string
  description = "Name of the Launch Template"
  default     = "ecs-blueprint-launch_template"
}
variable "volume_size" {
  type    = string
  default = 30
}

variable "instance_initiated_shutdown_behavior" {
  type        = string
  description = "Shutdown behavioure on instance"
  default     = "terminate"
}

variable "volume_type" {
  type        = string
  description = "Volume type to be used"
  default     = "gp2"
}

variable "capcitiy-provider_name" {
  type        = string
  description = "Name of capacity provider"
  default     = "capacity-provide-blue-print"
}

####### VPC details

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

variable "public_subnets_tag_value" {
  # if left blank then {core_stack_name}-public- will be used
  description = "The value tag of the public subnets"
  type        = string
  default     = ""
}

variable "private_subnets_tag_value" {
  # if left blank then {core_stack_name}-private- will be used
  description = "The value tag of the private subnets"
  type        = string
  default     = ""
}
