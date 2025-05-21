FROM ruby:3.3.3

# Set Node and PNPM versions
ARG NODE_VERSION="23.7.0"
ARG PNPM_VERSION="10.2.0"
ENV NODE_VERSION=${NODE_VERSION}
ENV PNPM_VERSION=${PNPM_VERSION}
ENV BUNDLER_VERSION=2.5.11

# Install system dependencies
RUN apt-get update -qq && \
    apt-get install -y build-essential libpq-dev nodejs npm git curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install pnpm
RUN npm install -g pnpm@${PNPM_VERSION}

# Set working directory
WORKDIR /app

# Copy package files
COPY package.json pnpm-lock.yaml ./

# Install Node.js dependencies
RUN pnpm install

# Copy Gemfile and install Ruby dependencies
COPY Gemfile Gemfile.lock ./
RUN gem install bundler:${BUNDLER_VERSION} && bundle install

# Copy the rest of the application
COPY . .

# Set environment variables
ENV RAILS_ENV=production
ENV NODE_ENV=production
ENV RAILS_SERVE_STATIC_FILES=true
ENV EXECJS_RUNTIME=Node

# Create necessary directories
RUN mkdir -p tmp/cache tmp/pids tmp/sockets log

# Precompile assets
RUN bundle exec rails assets:precompile

# Set permissions
RUN chmod +x docker/entrypoints/rails.sh

# Expose port
EXPOSE 3000

# Start the Rails server
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3000"]