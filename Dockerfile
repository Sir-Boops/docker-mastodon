FROM ubuntu:16.04

ENV MASTO_VER="2.3.3"
ENV RUBY_VER="2.5.0"

RUN apt update && \
    apt -y install whois && \
    useradd -m -d /opt/mastodon mastodon && \
    echo "mastodon:`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 24 | mkpasswd -s -m sha-256`" | chpasswd

RUN apt update && \
    apt -y install curl wget && \
    curl -sL https://deb.nodesource.com/setup_6.x | bash - && \
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list && \
    apt update && \
    apt -y install imagemagick ffmpeg libpq-dev libxml2-dev libxslt1-dev \
        file git-core g++ libprotobuf-dev protobuf-compiler pkg-config nodejs \
        gcc autoconf bison build-essential libssl-dev libyaml-dev \
        libreadline6-dev zlib1g-dev libncurses5-dev libffi-dev libgdbm3 \
        libgdbm-dev nginx redis-server redis-tools postgresql postgresql-contrib \
        letsencrypt yarn libidn11-dev libicu-dev

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
    rbenv install $RUBY_VER && \
    rbenv global $RUBY_VER && \
    export PATH="$HOME/.rbenv/versions/$RUBY_VER/bin:$PATH" && \
    wget https://github.com/tootsuite/mastodon/archive/v$MASTO_VER.tar.gz && \
    tar xf v$MASTO_VER.tar.gz && \
    wget https://git.sergal.org/Sir-Boops/mastodon-patches/raw/branch/master/patchset.diff && \
    patch -s -p0 < patchset.diff && \
    mv mastodon-2.3.3 mastodon && \
    rm v$MASTO_VER.tar.gz && \
    cd mastodon && \
    gem install bundler && \
    bundle install -j$(nproc) --deployment --without development test && \
    yarn install --pure-lockfile

