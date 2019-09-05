FROM ubuntu:14.04
MAINTAINER Derek Bourgeois <derek@ibourgeois.com>

# set some environment variables
ENV APP_NAME app
ENV APP_EMAIL app@laraedit.com
ENV APP_DOMAIN app.dev
ENV DEBIAN_FRONTEND noninteractive

RUN rm /bin/sh && ln -s /bin/bash /bin/sh

# upgrade the container
RUN apt-get update && \
    apt-get upgrade -y

# install some prerequisites
RUN apt-get install -y software-properties-common curl build-essential \
    dos2unix gcc git libmcrypt4 libpcre3-dev memcached make python2.7-dev \
    python-pip re2c unattended-upgrades whois vim libnotify-bin nano wget \
    debconf-utils pkg-config autoconf zip

# add some repositories
RUN apt-add-repository ppa:nginx/stable -y && \
    apt-get update

# set the locale
RUN echo "LC_ALL=zh_CN.UTF-8" >> /etc/default/locale  && \
    locale-gen zh_CN.UTF-8  && \
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    
# setup bash
COPY .bash_aliases /root

# install nginx
RUN apt-get install -y --force-yes nginx
COPY homestead /etc/nginx/sites-available/
RUN rm -rf /etc/nginx/sites-available/default && \
    rm -rf /etc/nginx/sites-enabled/default && \
    ln -fs /etc/nginx/sites-available/homestead /etc/nginx/sites-enabled/homestead && \
    sed -i -e"s/keepalive_timeout\s*65/keepalive_timeout 2/" /etc/nginx/nginx.conf && \
    sed -i -e"s/keepalive_timeout 2/keepalive_timeout 2;\n\tclient_max_body_size 100m/" /etc/nginx/nginx.conf && \
    echo "daemon off;" >> /etc/nginx/nginx.conf && \
    mkdir -p /var/www/html/app && \
    usermod -u 1000 www-data && \
    chown -R www-data.www-data /var/www/html/ && \
    sed -i -e"s/worker_processes  1/worker_processes 5/" /etc/nginx/nginx.conf

VOLUME ["/var/www/html/app"]
VOLUME ["/var/cache/nginx"]
VOLUME ["/var/log/nginx"]

#install source php
COPY redis-3.1.2.tgz /
COPY php-beast-master.zip /
RUN wget http://am1.php.net/distributions/php-7.1.31.tar.gz \
    && apt-get install -y build-essential bison re2c pkg-config libxml2-dev libbz2-dev libssl-dev libcurl4-openssl-dev libjpeg-dev libpng12-dev libfreetype6-dev libgmp-dev libreadline6-dev libxslt1-dev libzip-dev \
    && tar zxvf php-7.1.31.tar.gz \
    && cd php-7.1.31 \
    && ./configure --prefix=/usr/local/php \
        --with-curl \
        --with-freetype-dir \
        --with-gd \
        --with-gettext \
        --with-iconv-dir \
        --with-kerberos \
        --with-libdir=lib64 \
        --with-libxml-dir \
        --with-mysqli \
        --with-openssl \
        --with-pcre-regex \
        --with-pdo-mysql \
        --with-pdo-sqlite \
        --with-pear \
        --with-png-dir \
        --with-xmlrpc \
        --with-xsl \
        --with-zlib \
        --enable-fpm \
        --enable-bcmath \
        --enable-libxml \
        --enable-inline-optimization \
        --enable-gd-native-ttf \
        --enable-mbregex \
        --enable-mbstring \
        --enable-opcache \
        --enable-pcntl \
        --enable-shmop \
        --enable-soap \
        --enable-sockets \
        --enable-sysvsem \
        --enable-xml \
        --enable-zip \
    &&  make \
    &&  make install \
    &&  echo "export PATH=/usr/local/php/bin:$PATH" >> /etc/profile \
#    &&  source /etc/profile \
    &&  ln -s /usr/local/php/bin/* /usr/local/bin/ \
    &&  cp php.ini-development /usr/local/php/lib/php.ini \
    &&  cp /usr/local/php/etc/php-fpm.conf.default /usr/local/php/etc/php-fpm.conf \
    &&  cp /usr/local/php/etc/php-fpm.d/www.conf.default /usr/local/php/etc/php-fpm.d/www.conf \
    &&  sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /usr/local/php/lib/php.ini && \
    sed -i "s/display_errors = .*/display_errors = On/" /usr/local/php/lib/php.ini && \
    sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /usr/local/php/lib/php.ini && \
    sed -i "s/upload_max_filesize = .*/upload_max_filesize = 100M/" /usr/local/php/lib/php.ini && \
    sed -i "s/post_max_size = .*/post_max_size = 100M/" /usr/local/php/lib/php.ini && \
    sed -i "s/;date.timezone.*/date.timezone = UTC/" /usr/local/php/lib/php.ini && \
    sed -i "s/;pid/pid/" /usr/local/php/etc/php-fpm.conf && \
    sed -i "s/;daemonize = yes/daemonize = no/" /usr/local/php/etc/php-fpm.conf && \
    sed -i "s/;error_log/error_log/" /usr/local/php/etc/php-fpm.conf && \
    sed -i "s/user = nobody/user = www-data/" /usr/local/php/etc/php-fpm.d/www.conf && \
    sed -i "s/group = nobody/group = www-data/" /usr/local/php/etc/php-fpm.d/www.conf && \
    mkdir -p /run/php/ && chown -Rf www-data.www-data /run/php \
    && chown -R www-data:www-data /usr/local/php/var/ \
    && cd / \
    && tar zxf redis-3.1.2.tgz redis-3.1.2 \
    && cd redis-3.1.2 \
    && /usr/local/php/bin/phpize \
    && ./configure --with-php-config=/usr/local/php/bin/php-config \
    && make \
    && make install \
    && echo 'extension=redis.so' >> /usr/local/php/lib/php.ini \
    && cd / \
    && touch /var/log/beast.log \
    && chown -R www-data:www-data /var/log/beast.log \
    && chmod 777 /var/log/beast.log \
    && unzip php-beast-master.zip \
    && cd php-beast-master \
    && /usr/local/php/bin/phpize \
    && ./configure --with-php-config=/usr/local/php/bin/php-config \
    && make \
    && make install \
    && echo 'extension=beast.so' >> /usr/local/php/lib/php.ini \
    && echo 'beast.log_file = /var/log/beast.log' >> /usr/local/php/lib/php.ini

COPY fastcgi_params /etc/nginx/
# install php
#RUN apt-get install -y --force-yes php7.1-fpm php7.1-cli php7.1-dev php7.1-gd \
#    php-apcu php7.1-curl php7.1-mcrypt php7.1-imap php7.1-mysql php7.1-readline php-xdebug php-common \
#    php7.1-mbstring php7.1-xml php7.1-zip php-mongodb
#RUN sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/7.1/cli/php.ini && \
#    sed -i "s/display_errors = .*/display_errors = On/" /etc/php/7.1/cli/php.ini && \
#    sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php/7.1/cli/php.ini && \
#    sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/7.1/fpm/php.ini && \
#    sed -i "s/display_errors = .*/display_errors = On/" /etc/php/7.1/fpm/php.ini && \
#    sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/7.1/fpm/php.ini && \
#    sed -i "s/upload_max_filesize = .*/upload_max_filesize = 100M/" /etc/php/7.1/fpm/php.ini && \
#    sed -i "s/post_max_size = .*/post_max_size = 100M/" /etc/php/7.1/fpm/php.ini && \
#    sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php/7.1/fpm/php.ini && \
#    sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php/7.1/fpm/php-fpm.conf && \
#    sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" /etc/php/7.1/fpm/pool.d/www.conf && \
#    sed -i -e "s/pm.max_children = 5/pm.max_children = 9/g" /etc/php/7.1/fpm/pool.d/www.conf && \
#    sed -i -e "s/pm.start_servers = 2/pm.start_servers = 3/g" /etc/php/7.1/fpm/pool.d/www.conf && \
#    sed -i -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 2/g" /etc/php/7.1/fpm/pool.d/www.conf && \
#    sed -i -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 4/g" /etc/php/7.1/fpm/pool.d/www.conf && \
#    sed -i -e "s/pm.max_requests = 500/pm.max_requests = 200/g" /etc/php/7.1/fpm/pool.d/www.conf && \
#    sed -i -e "s/;listen.mode = 0660/listen.mode = 0750/g" /etc/php/7.1/fpm/pool.d/www.conf && \
#    find /etc/php/7.1/cli/conf.d/ -name "*.ini" -exec sed -i -re 's/^(\s*)#(.*)/\1;\2/g' {} \;
#COPY fastcgi_params /etc/nginx/
#RUN phpenmod mcrypt && \
#    mkdir -p /run/php/ && chown -Rf www-data.www-data /run/php

# install composer
RUN curl -sS https://getcomposer.org/installer | /usr/local/php/bin/php && \
    mv composer.phar /usr/local/bin/composer && \
    printf "\nPATH=\"~/.composer/vendor/bin:\$PATH\"\n" | tee -a ~/.bashrc

#install laravel installer
#RUN /bin/bash -c "composer config -g repo.packagist composer https://packagist.phpcomposer.com" \
#    && /bin/bash -c "composer global require laravel/installer"


# install supervisor
RUN apt-get install -y supervisor && \
    mkdir -p /var/log/supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
VOLUME ["/var/log/supervisor"]

# clean up our mess
RUN apt-get remove --purge -y software-properties-common && \
    apt-get autoremove -y && \
    apt-get clean && \
    apt-get autoclean && \
    echo -n > /var/lib/apt/extended_states && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /usr/share/man/?? && \
    rm -rf /usr/share/man/??_* && \
    rm -rf /php-7.1.31* && \
    rm -rf /php-beast-master* && \
    rm -rf /redis-3.1.2*

# expose ports
EXPOSE 80 443

# set container entrypoints
ENTRYPOINT ["/bin/bash","-c"]
CMD ["/usr/bin/supervisord"]

