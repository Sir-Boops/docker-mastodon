FROM ubuntu:18.04

ENV MASTO_HASH="0979d4275a387556fa040247330a4ed0e7f89602"
ENV RUBY_VER="2.5.1"
ENV NODE_VER="6.14.2"

# Use bash for the shell
SHELL ["bash", "-c"]

# Create the mastodon user
RUN apt update && \
    apt install -y whois && \
    useradd -m -d /opt/mastodon mastodon && \
    echo "mastodon:`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 24 | mkpasswd -s -m sha-256`" | chpasswd

# Setup the base system
RUN apt update && \
    apt -y dist-upgrade && \
    apt -y install curl gnupg2 && \
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list && \
    echo "Etc/UTC" > /etc/localtime && \
    apt update && \
    apt install --no-install-recommends yarn && \
    apt -y install imagemagick ffmpeg libpq-dev libxml2-dev libxslt1-dev \
        file git-core g++ libprotobuf-dev protobuf-compiler pkg-config \
        gcc autoconf bison build-essential libssl-dev libyaml-dev \
        libreadline6-dev zlib1g-dev libncurses5-dev libffi-dev libgdbm5 \
        libgdbm-dev redis-tools postgresql-contrib libidn11-dev libicu-dev \
        libjemalloc-dev python

# Install ruby,node and build mastodon and all deps for the user
USER mastodon
RUN git clone https://github.com/rbenv/rbenv.git ~/.rbenv && \
    cd ~/.rbenv && \
    src/configure && \
    make -C src && \
    cd ~ && \
    echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bash_profile && \
    echo 'eval "$(rbenv init -)"' >> ~/.bash_profile && \
    curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.11/install.sh | bash && \
    echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.bash_profile && \
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ~/.bash_profile && \
    source ~/.bash_profile && \
    nvm install $NODE_VER && \
    nvm use $NODE_VER && \
    git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build && \
    RUBY_CONFIGURE_OPTS="--with-jemalloc" rbenv install $RUBY_VER && \
    rbenv global $RUBY_VER && \
    export PATH="$HOME/.rbenv/versions/$RUBY_VER/bin:$PATH" && \
    echo PATH="$HOME/.rbenv/versions/$RUBY_VER/bin:$PATH" >> ~/.bash_profile && \
    git clone https://github.com/tootsuite/mastodon && \
    cd mastodon && \
    git checkout $MASTO_HASH && \
    echo "Rails.application.config.session_store :cookie_store, key: '_mastodon_session', secure: (ENV['LOCAL_HTTPS'] == 'false')" \
    > config/initializers/session_store.rb && \
    gem install bundler && \
    bundle install -j$(nproc) --deployment --without development test && \
    yarn install --pure-lockfile
