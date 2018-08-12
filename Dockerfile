FROM alpine:3.7 as build-dep

# Use bash for the shell
SHELL ["ash", "-c"]

# Install Node
ENV NODE_VER="6.14.3"
RUN apk -U upgrade && \
	apk add make gcc g++ python linux-headers && \
	cd ~ && \
	wget https://nodejs.org/download/release/v$NODE_VER/node-v$NODE_VER.tar.gz && \
	tar xf node-v$NODE_VER.tar.gz && \
	cd node-v$NODE_VER && \
	./configure --prefix=/opt/node && \
	make -j$(nproc) && \
	make install

# Install jemalloc
ENV JE_VER="5.1.0"
RUN apk add autoconf && \
	cd ~ && \
	 wget https://github.com/jemalloc/jemalloc/archive/$JE_VER.tar.gz && \
	tar xf $JE_VER.tar.gz && \
	cd jemalloc-$JE_VER && \
	./autogen.sh && \
	./configure --prefix=/opt/jemalloc \
	--disable-fill --disable-stats && \
	make -j$(nproc) && \
	make install_bin install_include install_lib

# Install ruby
ENV RUBY_VER="2.5.1"
RUN apk add zlib-dev libressl-dev \
		gdbm-dev db-dev readline-dev dpkg dpkg-dev && \
	cd ~ && \
	wget https://cache.ruby-lang.org/pub/ruby/${RUBY_VER%.*}/ruby-$RUBY_VER.tar.gz && \
	tar xf ruby-$RUBY_VER.tar.gz && \
	cd ruby-$RUBY_VER && \
	./configure --prefix=/opt/ruby \
		--build="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
		--with-jemalloc=/opt/jemalloc \
		--enable-shared \
		--disable-install-doc && \
	make -j$(nproc) && \
	make install

# Install Mastodon
ENV PATH="${PATH}:/opt/ruby/bin:/opt/node/bin"

RUN npm install -g yarn && \
	gem install bundler

ENV MASTO_HASH="7ac5151b74510aa82b07e349373bd442176e1e94"
RUN apk del libressl-dev && \
	apk add git icu-dev libidn-dev \
	postgresql-dev protobuf-dev && \
	git clone https://github.com/tootsuite/mastodon /opt/mastodon && \
	cd /opt/mastodon && \
	git checkout $MASTO_HASH && \
	bundle install -j$(nproc) --deployment --without development test && \
	yarn install --pure-lockfile && \
	rm -rf .git
	
