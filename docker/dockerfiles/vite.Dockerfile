FROM ruby:3.3.0

# Install system dependencies
RUN apt-get update -qq && \
    apt-get install -y build-essential libpq-dev nodejs npm git curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install pnpm
RUN npm install -g pnpm@10

# Set working directory
WORKDIR /app

# Copy package files
COPY package.json pnpm-lock.yaml ./

# Install Node.js dependencies
RUN pnpm install

# Copy Gemfile and install Ruby dependencies
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy the rest of the application
COPY . .

# Set environment variables
ENV RAILS_ENV=production
ENV NODE_ENV=production
ENV VITE_DEV_SERVER_HOST=0.0.0.0

# Create necessary directories
RUN mkdir -p tmp/cache tmp/pids tmp/sockets log

# Set permissions
RUN chmod +x docker/entrypoints/vite.sh

# Expose port
EXPOSE 3036

# Start the Vite dev server
CMD ["bin/vite", "dev"]
