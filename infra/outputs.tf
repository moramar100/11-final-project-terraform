output "vote_url" {
  description = "Public URL for casting votes"
  value       = "http://${aws_lb.app.dns_name}"
}

output "result_url" {
  description = "Public URL for live results"
  value       = "http://${aws_lb.app.dns_name}:8080"
}

output "redis_endpoint" {
  description = "ElastiCache Redis endpoint"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
}

output "db_endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.app.address
}
