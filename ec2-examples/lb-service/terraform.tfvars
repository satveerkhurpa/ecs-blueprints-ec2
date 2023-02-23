# You should update the below variables

# aws_region from the core-infra example
aws_region = "us-west-2"


# #The AWS Secrets Manager secret name containing the plaintext Github access token
# github_token_secret_name = "ecs-github-token"
# repository_owner         = "satveerkhurpa"

# It is optional to change the below variables
# core_stack_name is also same as ecs_cluster_name from core-infra
core_stack_name      = "ecs-blueprint-infra"
service_name         = "nginx-svc"
namespace            = "default"
backend_svc_endpoint = "http://ecsdemo.default.ecs-blueprint-infra.local"
desired_count        = 3
task_cpu             = 256
task_memory          = 512
container_name       = "nginx"
cp_provider_name     = "cp-one"

#Don't change the container port as it is specific to this app example

container_port = 80

# To set scheduled autoscaling, it will trigger scale up at 10 min past the hr and scale down at 20 min past the hr
# enable_scheduled_autoscaling = true
# scheduled_autoscaling_up_time = "cron(0 10 * ? * *)"
# scheduled_autoscaling_down_time = "cron(0 20 * ? * *)"
