output "ecs_cluster_name" {
  description = "The name of the ECS cluster and the name of the core stack"
  value       = local.name
}

output "ecs_cluster_id" {
  description = "The ID of the ECS cluster"
  value       = module.ecs.cluster_id
}

output "ecs_task_execution_role_name" {
  description = "The ARN of the task execution role"
  value       = aws_iam_role.execution.name
}

output "ecs_task_execution_role_arn" {
  description = "The ARN of the task execution role"
  value       = aws_iam_role.execution.arn
}

output "cp_name" {
  description = "EC2 Capacity Provider Name"
  value       = module.ecs.autoscaling_capacity_providers
}
