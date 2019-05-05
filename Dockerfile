FROM sirboops/nodejs:8.16.0 as node
FROM sirboops/ruby:2.6.3 as ruby
FROM ubuntu:18.04

# Use bash for the shell
SHELL ["bash", "-c"]

# Install Node
COPY --from=node /opt/node /opt/node

# Install jemalloc & ruby
COPY --from=ruby /opt/jemalloc /opt/jemalloc
COPY --from=ruby /opt/ruby /opt/ruby
RUN ln -s /opt/jemalloc/lib/* /usr/lib/

# Add more PATHs to the PATH
ENV PATH="${PATH}:/opt/ruby/bin:/opt/node/bin:/opt/mastodon/bin"

# Create the mastodon user
RUN apt update && \
	echo "Etc/UTC" > /etc/localtime && \
	apt -y dist-upgrade && \
	apt install -y whois && \
	addgroup --gid 991 mastodon && \
	useradd -m -u 991 -g 991 -d /opt/mastodon mastodon && \
	echo "mastodon:`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 24 | mkpasswd -s -m sha-256`" | chpasswd

RUN apt -y install git libicu-dev libidn11-dev \
		libpq-dev libprotobuf-dev protobuf-compiler \
		libyaml-0-2 && \
	npm install -g yarn && \
	gem install bundler && \
	rm -rf /opt/mastodon && \
	mkdir -p /opt/mastodon && \
	chown mastodon:mastodon /opt/mastodon && \
	ln -s /opt/mastodon /mastodon

USER mastodon

ENV MASTO_HASH="2508370f44272719c24bd8639f1b58bd24d01be2"

RUN	cd ~ && \
	git clone https://github.com/tootsuite/mastodon.git . && \
	git checkout $MASTO_HASH && \
	rm -rf .git && \
	bundle install -j$(nproc) --deployment --without development test && \
	yarn install --pure-lockfile

USER root

RUN apt -y remove git libicu-dev libidn11-dev \
		libpq-dev libprotobuf-dev protobuf-compiler && \
	apt -y autoremove

# Install masto runtime deps
RUN apt -y --no-install-recommends install \
	  libssl1.1 libpq5 imagemagick ffmpeg \
	  libicu60 libprotobuf10 libidn11 \
	  file ca-certificates tzdata libreadline7 && \
	apt -y install gcc

# Clean up more dirs
RUN rm -rf /var/cache && \
	rm -rf /var/apt

# Add tini
ENV TINI_VERSION="0.18.0"
ENV TINI_SUM="12d20136605531b09a2c2dac02ccee85e1b874eb322ef6baf7561cd93f93c855"
ADD https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini /tini
RUN echo "$TINI_SUM tini" | sha256sum -c -
RUN chmod +x /tini

# Run masto services in prod mode
ENV RAILS_ENV="production"
ENV NODE_ENV="production"

# Tell rails to serve static files
ENV RAILS_SERVE_STATIC_FILES="true"

# Set the run user
USER mastodon

# Precompile assets
RUN cd ~ && \
	OTP_SECRET=precompile_placeholder SECRET_KEY_BASE=precompile_placeholder rails assets:precompile && \
	yarn cache clean

# Set the work dir and the container entry point
WORKDIR /opt/mastodon
ENTRYPOINT ["/tini", "--"]
