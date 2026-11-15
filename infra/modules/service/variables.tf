variable "name" { type = string }
variable "image" { type = string }
variable "cluster_arn" { type = string }
variable "execution_role_arn" { type = string }
variable "subnet_ids" { type = list(string) }
variable "security_group_id" { type = string }
variable "desired_count" { type = number }
variable "region" { type = string }
variable "environment" { type = map(string) }
variable "secrets" { type = list(object({ name = string, valueFrom = string })) }
variable "container_port" {
  type     = number
  default  = null
  nullable = true
}
variable "target_group_arn" {
  type     = string
  default  = null
  nullable = true
}
