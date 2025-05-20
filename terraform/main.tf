terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

# Kubernetes cluster
resource "digitalocean_kubernetes_cluster" "chatwoot" {
  name    = "chatwoot-cluster"
  region  = var.region
  version = "1.27.4-do.0"

  node_pool {
    name       = "default-pool"
    size       = "s-2vcpu-4gb"
    node_count = 3
    auto_scale = true
    min_nodes  = 2
    max_nodes  = 5
  }
}

# Managed PostgreSQL database
resource "digitalocean_database_cluster" "postgres" {
  name       = "chatwoot-db"
  engine     = "pg"
  version    = "16"
  size       = "db-s-1vcpu-1gb"
  region     = var.region
  node_count = 1
}

# Managed Redis database
resource "digitalocean_database_cluster" "redis" {
  name       = "chatwoot-redis"
  engine     = "redis"
  version    = "7"
  size       = "db-s-1vcpu-1gb"
  region     = var.region
  node_count = 1
}

# Database user
resource "digitalocean_database_user" "postgres" {
  cluster_id = digitalocean_database_cluster.postgres.id
  name       = "chatwoot"
}

# Database database
resource "digitalocean_database_db" "postgres" {
  cluster_id = digitalocean_database_cluster.postgres.id
  name       = "chatwoot"
}

# Firewall rules
resource "digitalocean_firewall" "k8s" {
  name = "chatwoot-k8s-firewall"

  droplet_ids = [digitalocean_kubernetes_cluster.chatwoot.node_pool[0].nodes[0].droplet_id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = ["0.0.0.0/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0"]
  }

  outbound_rule {
    protocol              = "tcp"
    port_range           = "1-65535"
    destination_addresses = ["0.0.0.0/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range           = "1-65535"
    destination_addresses = ["0.0.0.0/0"]
  }
} 