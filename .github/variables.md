# GitHub Variables and Secrets Setup

## Required Secrets
These should be added to GitHub Secrets (Settings > Secrets and variables > Actions > Secrets):

```yaml
# DigitalOcean
DO_TOKEN: "your-digitalocean-api-token"

# Database
POSTGRES_PASSWORD: "your-database-password"

# Redis
REDIS_PASSWORD: "your-redis-password"

# SMTP
SMTP_PASSWORD: "your-smtp-password"

# Application
SECRET_KEY_BASE: "your-rails-secret-key-base"

# Docker Registry
DOCKER_PASSWORD: "your-docker-registry-password"
```

## Required Variables
These should be added to GitHub Variables (Settings > Secrets and variables > Actions > Variables):

```yaml
# DigitalOcean
DO_REGION: "fra1"  # Frankfurt, closest to Kuwait

# Database
POSTGRES_USER: "chatwoot"
POSTGRES_HOST: "your-do-db-host"
POSTGRES_PORT: "5432"
POSTGRES_DB: "chatwoot"

# SMTP
SMTP_USERNAME: "your-smtp-username"

# Application
DOMAIN: "wavai.com"
ENVIRONMENT: "production"

# Docker Registry
DOCKER_REGISTRY: "your-docker-registry-url"
DOCKER_USERNAME: "your-docker-registry-username"
```

## How to Set Up

1. Go to your GitHub repository
2. Click on "Settings"
3. Click on "Secrets and variables" > "Actions"
4. Add each secret and variable with its corresponding value

## Important Notes

1. **Secrets** are encrypted and can only be accessed during workflow runs
2. **Variables** are not encrypted and should not contain sensitive information
3. All sensitive information should be stored as **Secrets**
4. Make sure to use strong, unique passwords for each service
5. The `SECRET_KEY_BASE` can be generated using:
   ```bash
   rails secret
   ```
6. The `DO_TOKEN` can be obtained from DigitalOcean dashboard
7. Database credentials will be provided by DigitalOcean when you create the managed database
8. Docker registry credentials depend on your chosen registry (e.g., Docker Hub, DigitalOcean Container Registry) 