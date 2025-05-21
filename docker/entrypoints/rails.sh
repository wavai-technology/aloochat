#!/bin/sh

set -x

# Remove a potentially pre-existing server.pid for Rails.
rm -rf /app/tmp/pids/server.pid
rm -rf /app/tmp/cache/*

echo "Waiting for postgres to become ready...."

# Let DATABASE_URL env take presedence over individual connection params.
# This is done to avoid printing the DATABASE_URL in the logs
$(docker/entrypoints/helpers/pg_database_url.rb)
PG_READY="pg_isready -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USERNAME"

until $PG_READY
do
  sleep 2;
done

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
