FROM ubuntu:18.04 as build-dep

# Use bash for the shell
SHELL ["bash", "-c"]

# Install Node
ENV NODE_VER="6.14.3"
RUN apt update && \
    echo "Etc/UTC" > /etc/localtime && \
    apt -y dist-upgrade && \
    apt -y install wget make gcc g++ python && \
    cd ~ && \
    wget https://nodejs.org/download/release/v$NODE_VER/node-v$NODE_VER.tar.gz && \
    tar xf node-v$NODE_VER.tar.gz && \
    cd node-v$NODE_VER && \
    ./configure --prefix=/opt/node && \
    make -j$(nproc) && \
    make install

# Install jemalloc
ENV JEMALLOC_VER="5.1.0"
RUN apt -y install autoconf && \
    cd ~ && \
    wget https://github.com/jemalloc/jemalloc/archive/$JEMALLOC_VER.tar.gz && \
    tar xf $JEMALLOC_VER.tar.gz && \
    cd jemalloc-$JEMALLOC_VER && \
    ./autogen.sh && \
    ./configure --prefix=/opt/jemalloc && \
    make -j$(nproc) && \
    make install_bin install_include install_lib

# Install ruby
ENV RUBY_VER="2.5.1"
RUN apt -y install zlib1g-dev libssl-dev \
      libgdbm-dev libdb-dev libreadline-dev && \
    cd ~ && \
    wget https://cache.ruby-lang.org/pub/ruby/${RUBY_VER%.*}/ruby-$RUBY_VER.tar.gz && \
    tar xf ruby-$RUBY_VER.tar.gz && \
    cd ruby-$RUBY_VER && \
    ./configure --prefix=/opt/ruby \
      --with-shared \
      --disable-install-doc && \
    make -j$(nproc) && \
    make install

ENV PATH="${PATH}:/opt/ruby/bin:/opt/node/bin"

RUN npm install -g yarn && \
    gem install bundler

ENV MASTO_HASH="7ac5151b74510aa82b07e349373bd442176e1e94"
RUN apt -y install git libicu-dev libidn11-dev \
    libpq-dev libprotobuf-dev protobuf-compiler && \
    git clone https://github.com/tootsuite/mastodon /opt/mastodon && \
    cd /opt/mastodon && \
    git checkout $MASTO_HASH && \
    bundle install -j$(nproc) --deployment --without development test && \
    yarn install --pure-lockfile && \
    rm -rf .git

FROM ubuntu:18.04

COPY --from=build-dep /opt/node /opt/node
COPY --from=build-dep /opt/jemalloc /opt/jemalloc
COPY --from=build-dep /opt/ruby /opt/ruby

ENV PATH="${PATH}:/opt/ruby/bin:/opt/node/bin:/opt/mastodon/bin"
ENV TINI_VERSION="0.18.0"

# Create the mastodon user
RUN apt update && \
    echo "Etc/UTC" > /etc/localtime && \
    apt -y dist-upgrade && \
    apt install -y whois && \
    useradd -m -d /opt/mastodon mastodon && \
    echo "mastodon:`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 24 | mkpasswd -s -m sha-256`" | chpasswd

COPY --from=build-dep --chown=1000:1000 /opt/mastodon /opt/mastodon

RUN apt -y --no-install-recommends install \
      libssl1.1 libpq5 imagemagick ffmpeg \
      libicu60 libprotobuf10 libidn11 \
      file ca-certificates tzdata && \
    ln -s /opt/mastodon /mastodon && \
    gem install bundler

# Clean up more dirs
RUN rm -rf /var/cache && \
    rm -rf /var/apt

# Add tini
ENV TINI_SUM="12d20136605531b09a2c2dac02ccee85e1b874eb322ef6baf7561cd93f93c855"
ADD https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini /tini
RUN echo "$TINI_SUM tini" | sha256sum -c -
RUN chmod +x /tini

USER mastodon
WORKDIR /opt/mastodon
ENTRYPOINT ["/tini", "--"]
