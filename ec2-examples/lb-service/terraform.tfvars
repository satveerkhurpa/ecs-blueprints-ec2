aws_region                = "us-west-2"
core_stack_name           = "hazeltree-ecs-infra"
service_name              = "nginx-svc"
backend_svc_endpoint      = "http://ecsdemo.default.ecs-blueprint-infra.local"
desired_count             = 3
task_cpu                  = 256
task_memory               = 512
container_name            = "nginx"
cp_provider_name          = "cp-one"
container_image           = "<account_id>.dkr.ecr.us-west-2.amazonaws.com/nginx:latest"
container_port            = 80
vpc_tag_key               = "Name"
vpc_tag_value             = "hazeltree-vpc"
private_subnets_tag_value = "hazeltree-subnet-private"
public_subnets_tag_value  = "hazeltree-subnet-public"

# To set scheduled autoscaling, it will trigger scale up at 10 min past the hr and scale down at 20 min past the hr
# enable_scheduled_autoscaling = true
# scheduled_autoscaling_up_time = "cron(0 10 * ? * *)"
# scheduled_autoscaling_down_time = "cron(0 20 * ? * *)"
