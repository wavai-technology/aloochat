output "kubeconfig" {
  value     = digitalocean_kubernetes_cluster.chatwoot.kube_config[0].raw_config
  sensitive = true
}

# PostgreSQL outputs
output "postgres_host" {
  value = digitalocean_database_cluster.postgres.host
}

output "postgres_port" {
  value = digitalocean_database_cluster.postgres.port
}

output "postgres_database" {
  value = digitalocean_database_db.postgres.name
}

output "postgres_user" {
  value = digitalocean_database_user.postgres.name
}

output "postgres_password" {
  value     = digitalocean_database_user.postgres.password
  sensitive = true
}

# Redis outputs
output "redis_host" {
  value = digitalocean_database_cluster.redis.host
}

output "redis_port" {
  value = digitalocean_database_cluster.redis.port
}

output "redis_password" {
  value     = digitalocean_database_cluster.redis.password
  sensitive = true
} 