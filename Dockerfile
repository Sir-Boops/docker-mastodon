FROM ubuntu:18.04 as build-dep

ENV MASTO_HASH="2a1089839db64ceb2e9f9d3d62217da3812d3ad0"
ENV NODE_VER="6.14.3"
ENV JEMALLOC_VER="5.1.0"
ENV RUBY_VER="2.5.1"

# Use bash for the shell
SHELL ["bash", "-c"]

# Install Node
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

RUN apt -y install autoconf && \
    cd ~ && \
    wget https://github.com/jemalloc/jemalloc/archive/$JEMALLOC_VER.tar.gz && \
    tar xf $JEMALLOC_VER.tar.gz && \
    cd jemalloc-$JEMALLOC_VER && \
    ./autogen.sh && \
    ./configure --prefix=/opt/jemalloc && \
    make -j$(nproc) && \
    make install_bin install_include install_lib

RUN apt -y install zlib1g-dev libssl-dev \
      libgdbm-dev libdb-dev libreadline-dev && \
    cd ~ && \
    wget https://cache.ruby-lang.org/pub/ruby/${RUBY_VER%.*}/ruby-$RUBY_VER.tar.gz && \
    tar xf ruby-$RUBY_VER.tar.gz && \
    cd ruby-$RUBY_VER && \
    ./configure --prefix=/opt/ruby \
      --with-jemalloc=/opt/jemalloc \
      --with-shared \
      --disable-install-doc && \
    make -j$(nproc) && \
    make install

ENV PATH="${PATH}:/opt/ruby/bin:/opt/node/bin"

RUN npm install -g yarn && \
    gem install bundler

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

ENV PATH="${PATH}:/opt/ruby/bin:/opt/node/bin"

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
    gem install bundler
