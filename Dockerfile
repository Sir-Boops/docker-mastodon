FROM ubuntu:16.04

ENV MASTO_HASH="5ea643b27908b14bd89ff068fc87e446e8cbcd32"
ENV RUBY_VER="2.5.1"

# Create the mastodon user
RUN apt update && \
    apt install -y whois && \
    useradd -m -d /opt/mastodon mastodon && \
    echo "mastodon:`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 24 | mkpasswd -s -m sha-256`" | chpasswd

# Setup the base system
RUN apt update && \
    apt -y dist-upgrade && \
    apt -y install curl wget && \
    curl -sL https://deb.nodesource.com/setup_6.x | bash - && \
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list && \
    apt update && \
    apt -y install imagemagick ffmpeg libpq-dev libxml2-dev libxslt1-dev \
        file git-core g++ libprotobuf-dev protobuf-compiler pkg-config nodejs \
        gcc autoconf bison build-essential libssl-dev libyaml-dev \
        libreadline6-dev zlib1g-dev libncurses5-dev libffi-dev libgdbm3 \
        libgdbm-dev redis-tools postgresql-contrib yarn libidn11-dev libicu-dev libjemalloc-dev

# Install ruby and build mastodon and all deps for the user
USER mastodon
RUN git clone https://github.com/rbenv/rbenv.git ~/.rbenv && \
    cd ~/.rbenv && \
    src/configure && \
    make -C src && \
    cd ~ && \
    echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bash_profile && \
    echo 'eval "$(rbenv init -)"' >> ~/.bash_profile && \
    export PATH="$HOME/.rbenv/bin:$PATH" && \
    rbenv init - && \
    git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build && \
    RUBY_CONFIGURE_OPTS="--with-jemalloc" rbenv install $RUBY_VER && \
    rbenv global $RUBY_VER && \
    export PATH="$HOME/.rbenv/versions/$RUBY_VER/bin:$PATH" && \
    echo PATH="$HOME/.rbenv/versions/$RUBY_VER/bin:$PATH" >> ~/.bash_profile && \
    git clone https://github.com/tootsuite/mastodon && \
    cd mastodon && \
    echo "Rails.application.config.session_store :cookie_store, key: '_mastodon_session', secure: (ENV['LOCAL_HTTPS'] == 'false')" \
    > config/initializers/session_store.rb && \
    sed -i 's/config.action_controller.perform_caching = true/config.action_controller.perform_caching = false/' config/environments/production.rb && \
    git checkout $MASTO_HASH && \
    gem install bundler && \
    bundle install -j$(nproc) --deployment --without development test && \
    yarn install --pure-lockfile
