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
        letsencrypt yarn libidn11-dev libicu-dev && \
    su - -s /bin/bash mastodon -c "git clone https://github.com/rbenv/rbenv.git ~/.rbenv" && \
    su - -s /bin/bash mastodon -c "cd ~/.rbenv && src/configure && make -C src" && \
    su - -s /bin/bash mastodon -c 'echo export PATH="$HOME/.rbenv/bin:$PATH" >> ~/.bash_profile' && \
    su - -s /bin/bash mastodon -c 'echo eval "$(rbenv init -)" >> ~/.bash_profile' && \
    su - -s /bin/bash mastodon -c "git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build" && \
    su - -s /bin/bash mastodon -c "rbenv install $RUBY_VER" && \
    su - -s /bin/bash mastodon -c "rbenv global $RUBY_VER" && \
    su - -s /bin/bash mastodon -c "wget https://github.com/tootsuite/mastodon/archive/v$MASTO_VER.tar.gz" && \
    su - -s /bin/bash mastodon -c "tar xf v$MASTO_VER.tar.gz" && \
    su - -s /bin/bash mastodon -c "wget https://git.sergal.org/Sir-Boops/mastodon-patches/raw/branch/master/patchset.diff" && \
    su - -s /bin/bash mastodon -c "patch -s -p0 < patchset.diff" && \
    su - -s /bin/bash mastodon -c "mv mastodon-2.3.3 mastodon && rm v$MASTO_VER.tar.gz" && \
    su - -s /bin/bash mastodon -c "cd mastodon && gem install bundler" && \
    su - -s /bin/bash mastodon -c "cd mastodon && bundle install -j$(nproc) --deployment --without development test" && \
    su - -s /bin/bash mastodon -c "cd mastodon && yarn install --pure-lockfile"

