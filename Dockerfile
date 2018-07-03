FROM alpine:3.7

ENV JEMALLOC_VER="5.1.0"
ENV RUBY_VER="2.4.4"
ENV NODE_VER="6.14.3"
ENV MASTO_HASH="2a1089839db64ceb2e9f9d3d62217da3812d3ad0"

SHELL ["ash","-c"]

# Add the mastodon user and update the base image
RUN addgroup mastodon && \
    mkdir -p /opt/mastodon && \
    adduser -D -h /opt/mastodon -G mastodon mastodon && \
    echo "mastodon:`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 24 | mkpasswd -m sha256`" | chpasswd && \
    apk -U --no-cache upgrade

# Build JEMALLOC
RUN apk --no-cache --virtual deps add \
      autoconf gcc g++ make && \
    cd ~ && \
    wget https://github.com/jemalloc/jemalloc/archive/$JEMALLOC_VER.tar.gz && \
    tar xf $JEMALLOC_VER.tar.gz && \
    cd jemalloc-$JEMALLOC_VER && \
    ./autogen.sh && \
    ./configure --prefix=/opt/jemalloc && \
    make -j$(nproc) && \
    make install_bin install_include install_lib && \
    apk --purge del deps && \
    rm -rf ~/*

# Build and install ruby lang
COPY ./*.patch /root/
RUN apk --no-cache --virtual deps add \
      gcc g++ make linux-headers zlib-dev libressl-dev \
      gdbm-dev db-dev readline-dev dpkg dpkg-dev && \
    cd ~ && \
    wget https://cache.ruby-lang.org/pub/ruby/2.4/ruby-$RUBY_VER.tar.gz && \
    tar xf ruby-$RUBY_VER.tar.gz && \
    cd ruby-$RUBY_VER && \
    ac_cv_func_isnan=yes ac_cv_func_isinf=yes \
      ./configure --prefix=/opt/ruby \
        --build="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
        --disable-install-doc \
        --with-jemalloc=/opt/jemalloc/ \
        --enable-shared && \
    make -j$(nproc) && \
    make install && \
    rm -rf /opt/ruby/share && \
    rm -rf ~/* && \
    apk --purge del deps

# Build and install NODEJS
RUN apk --no-cache --virtual deps add \
      python make gcc g++ linux-headers && \
    apk add libstdc++ && \
    cd ~ && \
    wget https://nodejs.org/download/release/v$NODE_VER/node-v$NODE_VER.tar.xz && \
    tar xf node-v$NODE_VER.tar.xz && \
    cd node-v$NODE_VER && \
    ./configure --prefix=/opt/nodejs && \
    make -j$(nproc) && \
    make install && \
    rm -rf ~/* && \
    apk --purge del deps

# Set the proper PATH
ENV PATH="${PATH}:/opt/nodejs/bin:/opt/ruby/bin"

# Install masto deps
RUN npm install -g yarn && \
    gem install bundler && \
    apk --no-cache --virtual deps add \
      git gcc g++ make zlib-dev icu-dev \
      postgresql-dev libidn-dev protobuf-dev \
      python

USER mastodon

# Build and install Masto
RUN cd ~ && \
    git clone https://github.com/tootsuite/mastodon && \
    cd mastodon && \
    git checkout $MASTO_HASH && \
    bundle install -j$(nproc) --deployment --without development test && \
    yarn install --pure-lockfile && \
    rm -rf ~/.cache && \
    rm -rf ~/mastodon/.git

USER root

# System Cleanup and runtime dep installation
RUN apk --purge del deps && \
    apk --no-cache add ca-certificates \
      ffmpeg file imagemagick icu-libs \
      tzdata libidn protobuf libpq

USER mastodon
