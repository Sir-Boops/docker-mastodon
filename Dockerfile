FROM alpine:3.8

# Use ash for the shell
SHELL ["ash","-c"]

# Add the mastodon user and update the base image
RUN addgroup -g 991 mastodon && \
    mkdir -p /opt/mastodon && \
    adduser -u 991 -S -D -h /opt/mastodon -G mastodon mastodon && \
    apk -U --no-cache upgrade

# Build and install NODEJS
ENV NODE_VER="8.15.0"
RUN apk --no-cache --virtual deps add \
      python make gcc g++ linux-headers && \
    apk add libstdc++ && \
    cd ~ && \
    wget https://nodejs.org/download/release/v$NODE_VER/node-v$NODE_VER.tar.xz && \
    tar xf node-v$NODE_VER.tar.xz && \
    cd node-v$NODE_VER && \
    ./configure --prefix=/opt/node && \
    make -j$(nproc) > /dev/null && \
    make install && \
    rm -rf ~/*

# Build and install ruby lang
ENV RUBY_VER="2.6.0"
RUN apk --no-cache --virtual deps add \
      gcc g++ make linux-headers zlib-dev libressl-dev \
      gdbm-dev db-dev readline-dev dpkg dpkg-dev patch && \
    cd ~ && \
    wget https://cache.ruby-lang.org/pub/ruby/${RUBY_VER%.*}/ruby-$RUBY_VER.tar.gz && \
    tar xf ruby-$RUBY_VER.tar.gz && \
    cd ruby-$RUBY_VER && \
	wget -O 'thread-stack-fix.patch' 'https://bugs.ruby-lang.org/attachments/download/7081/0001-thread_pthread.c-make-get_main_stack-portable-on-lin.patch' && \
	patch -p1 -i thread-stack-fix.patch && \
    ac_cv_func_isnan=yes ac_cv_func_isinf=yes \
      ./configure --prefix=/opt/ruby \
        --build="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
        --disable-install-doc \
        --with-jemalloc=/opt/jemalloc/ \
        --enable-shared && \
    make -j$(nproc) > /dev/null && \
    make install && \
    rm -rf /opt/ruby/share && \
    rm -rf ~/*

# Set the proper PATH
ENV PATH="${PATH}:/opt/node/bin:/opt/ruby/bin"

# Install masto deps
RUN npm install -g yarn && \
    gem install bundler && \
    apk --no-cache --virtual deps add \
      git gcc g++ make zlib-dev icu-dev \
      postgresql-dev libidn-dev protobuf-dev \
      python

USER mastodon

# Build and install Masto
ENV MASTO_HASH="bc3a6dd597ab926cba74924bd44372613872b4f5"
RUN cd ~ && \
    git clone https://github.com/tootsuite/mastodon . && \
    git checkout $MASTO_HASH && \
    bundle install -j$(nproc) --deployment --without development test && \
    yarn install --pure-lockfile && \
    rm -rf ~/.cache && \
    rm -rf ~/mastodon/.git

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
