# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile is designed for production, not development.
#
# Build:
#   docker build -t audit_orve .
#
# Run:
#   docker run -d \
#     -p 80:80 \
#     -e RAILS_MASTER_KEY=<value from config/master.key> \
#     --name audit_orve \
#     audit_orve

ARG RUBY_VERSION=3.4.10

FROM docker.io/library/ruby:${RUBY_VERSION}-slim AS base

# Rails application directory
WORKDIR /rails

# Runtime operating-system dependencies.
#
# libvips is required because Active Storage uses:
#   config.active_storage.variant_processor = :vips
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl \
      libjemalloc2 \
      libvips \
      postgresql-client && \
    ln -sf \
      /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 \
      /usr/local/lib/libjemalloc.so && \
    rm -rf \
      /var/lib/apt/lists/* \
      /var/cache/apt/archives/*

# Production configuration
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

# =========================================================
# Build stage
# =========================================================

FROM base AS build

# Dependencies required only while building gems and assets.
# libvips is inherited from the base stage and is not
# installed a second time here.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      git \
      libpq-dev \
      libyaml-dev \
      pkg-config && \
    rm -rf \
      /var/lib/apt/lists/* \
      /var/cache/apt/archives/*

# Install application gems
COPY vendor/* ./vendor/
COPY Gemfile Gemfile.lock ./

RUN bundle install && \
    rm -rf \
      ~/.bundle/ \
      "${BUNDLE_PATH}"/ruby/*/cache \
      "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile -j 1 --gemfile

# Fail the image build when libvips is unavailable or older
# than the minimum secure version required by Active Storage.
RUN bundle exec ruby -rvips -e \
    'puts "libvips: #{Vips.version_string}"; \
     puts "ruby-vips: #{Vips::VERSION}"; \
     abort "libvips debe ser 8.13 o superior" unless Vips.at_least_libvips?(8, 13)'

# Copy application source
COPY . .

# Precompile Ruby application code
RUN bundle exec bootsnap precompile -j 1 app/ lib/

# Precompile assets without requiring production secrets.
# These database values are build-only placeholders.
RUN DB_HOST=127.0.0.1 \
    DB_PORT=5432 \
    DB_USERNAME=postgres \
    DB_PASSWORD=build_only \
    PRIMARY_DATABASE_NAME=audit_orve_production \
    CACHE_DATABASE_NAME=audit_orve_production_cache \
    QUEUE_DATABASE_NAME=audit_orve_production_queue \
    CABLE_DATABASE_NAME=audit_orve_production_cable \
    AUDIT_DATABASE_NAME=auditpr-2026 \
    SECRET_KEY_BASE_DUMMY=1 \
    ./bin/rails assets:precompile

# =========================================================
# Final production image
# =========================================================

FROM base

# Run the application as a non-root user
RUN groupadd --system --gid 1000 rails && \
    useradd \
      --uid 1000 \
      --gid 1000 \
      --create-home \
      --shell /bin/bash \
      rails

USER 1000:1000

# Copy installed gems and compiled application
COPY --chown=rails:rails \
  --from=build \
  "${BUNDLE_PATH}" \
  "${BUNDLE_PATH}"

COPY --chown=rails:rails \
  --from=build \
  /rails \
  /rails

# Prepare databases and application startup
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 80

# Start Rails through Thruster
CMD ["./bin/thrust", "./bin/rails", "server"]