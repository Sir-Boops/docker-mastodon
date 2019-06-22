FROM sirboops/nodejs:8.16.0-alpine as node
FROM sirboops/ruby:2.6.3-alpine as ruby
FROM alpine:3.9

# Use ash for the shell
SHELL ["ash","-c"]

# Add the mastodon user and update the base image
RUN addgroup -g 991 mastodon && \
    mkdir -p /opt/mastodon && \
    adduser -u 991 -S -D -h /opt/mastodon -G mastodon mastodon && \
    apk -U --no-cache upgrade

# Install nodejs
COPY --from=node /opt/node/ /opt/node/
RUN apk add libstdc++

# Install Ruby
COPY --from=ruby /opt/ruby/ /opt/ruby/

# Set the proper PATH
ENV PATH="${PATH}:/opt/node/bin:/opt/ruby/bin"

# Install masto deps
RUN	apk add libressl2.7-libssl && \
	apk --no-cache --virtual deps add \
      git gcc g++ make zlib-dev icu-dev \
      postgresql-dev libidn-dev protobuf-dev \
      python && \
	npm install -g yarn && \
	gem install bundler

# Switch to masto user
USER mastodon

# Build and install Masto
ENV MASTO_HASH="66ac1bd063882f5a2f828c1c702089e37f36f217"
RUN cd ~ && \
    git clone https://github.com/tootsuite/mastodon . && \
    git checkout $MASTO_HASH && \
    bundle install -j$(nproc) --deployment --without development test && \
    yarn install --pure-lockfile && \
    rm -rf .git

# Switch back to root user
USER root

# Set final path
ENV PATH="${PATH}:/opt/node/bin:/opt/ruby/bin:/opt/mastodon/bin"

# Add tini
ENV TINI_VERSION="0.18.0"
ENV TINI_SUM="0dfef32df25ea1d677c20f338325fcd0c1d8f9828bfeac9a7a981b8c80b210f8"
ADD https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini-muslc-amd64 /tini
RUN echo "$TINI_SUM  tini" | sha256sum -c -
RUN chmod +x /tini

# System Cleanup and runtime dep installation
RUN apk --no-cache add ca-certificates \
      ffmpeg file imagemagick icu-libs \
      tzdata libidn protobuf libpq && \
	apk --purge del deps && \
	ln -s /opt/mastodon /mastodon

# Set Container options
ENV RAILS_ENV="production"
ENV NODE_ENV="production"
ENV RAILS_SERVE_STATIC_FILES="true"
WORKDIR /opt/mastodon
ENTRYPOINT ["/tini", "--"]

# Set run user
USER mastodon

# Precompile assets
RUN cd ~ && \
	OTP_SECRET=precompile_placeholder SECRET_KEY_BASE=precompile_placeholder bundle exec rails assets:precompile && \
	yarn cache clean
