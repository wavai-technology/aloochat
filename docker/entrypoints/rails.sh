#!/bin/sh

set -x

# Remove a potentially pre-existing server.pid for Rails.
rm -rf /app/tmp/pids/server.pid
rm -rf /app/tmp/cache/*

echo "Waiting for postgres to become ready...."

# Let DATABASE_URL env take presedence over individual connection params.
# This is done to avoid printing the DATABASE_URL in the logs
$(docker/entrypoints/helpers/pg_database_url.rb)

# Check if pg_isready is available
if command -v pg_isready > /dev/null; then
  PG_READY="pg_isready -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USERNAME"
  
  until $PG_READY
  do
    echo "Waiting for PostgreSQL to be ready..."
    sleep 2;
  done
else
  # If pg_isready is not available, use a simple connection test with timeout
  echo "pg_isready command not found, using alternative connection test"
  
  # Wait for database to be ready with a timeout
  MAX_TRIES=30
  TRIES=0
  
  while [ $TRIES -lt $MAX_TRIES ]; do
    # Try to connect using the Rails database connection
    if bundle exec rails runner 'ActiveRecord::Base.connection.execute("SELECT 1")' > /dev/null 2>&1; then
      echo "Database connection successful"
      break
    else
      echo "Waiting for database connection... (attempt $((TRIES+1))/$MAX_TRIES)"
      TRIES=$((TRIES+1))
      sleep 2
    fi
  done
  
  if [ $TRIES -eq $MAX_TRIES ]; then
    echo "Warning: Could not connect to database after $MAX_TRIES attempts, but continuing anyway"
  fi
fi

echo "Database ready to accept connections."

#install missing gems for local dev as we are using base image compiled for production
bundle install

BUNDLE="bundle check"

until $BUNDLE
do
  sleep 2;
done

# Prepare and migrate the database
echo "Preparing and migrating the database..."
if [ "$RAILS_ENV" = "development" ]; then
  bundle exec rails db:chatwoot_prepare || echo "Warning: Database preparation failed, but continuing..."
else
  # In production, we want to run migrations but not reset the database
  bundle exec rails db:migrate || echo "Warning: Database migration failed, but continuing..."
fi

# Execute the main process of the container
exec "$@"
