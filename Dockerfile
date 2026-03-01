# Dockerfile
FROM ruby:4.0.1

# Install system dependencies
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential libpq-dev nodejs && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

WORKDIR /rails

# Set production environment
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test"

# Install gems
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy application code
COPY . .

# Precompile assets (Tailwind builds your final CSS file here!)
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

EXPOSE 3000

# Start Puma directly (NO foreman, NO bin/dev)
CMD ["./bin/rails", "server"]