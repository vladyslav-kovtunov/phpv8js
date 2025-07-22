FROM composer:latest AS composer
FROM php:8.4-fpm

ARG PROJECT_ROOT='/app'
ENV PROJECT_ROOT=${PROJECT_ROOT}
WORKDIR ${PROJECT_ROOT}

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
     build-essential \
     cron \
     curl \
     git \
     iproute2 \
     gnupg2 \
     libyaml-dev \
     libxml2-dev \
     libzip-dev \
     libonig-dev \
     libpng-dev \
     libjpeg-dev \
     libfreetype6-dev \
     zlib1g-dev \
     netcat-openbsd \
     unzip \
     procps \
     mariadb-client \
     libv8-dev \
     pkg-config \
     autoconf \
     automake \
     libtool \
     ca-certificates && \
    rm -rf /var/lib/apt/lists/*

COPY --from=composer /usr/bin/composer /usr/local/bin/composer

RUN git config --global --add safe.directory /app

RUN docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install mysqli pdo pdo_mysql sockets mbstring zip opcache gd

RUN cd /tmp && \
    git clone https://github.com/php/pecl-file_formats-yaml.git yaml && \
    cd yaml && \
    phpize && \
    ./configure && \
    make && \
    make install && \
    echo "extension=yaml.so" > /usr/local/etc/php/conf.d/ext-yaml.ini && \
    cd /tmp && \
    git clone https://github.com/phpredis/phpredis.git redis && \
    cd redis && \
    phpize && \
    ./configure && \
    make && \
    make install && \
    echo "extension=redis.so" > /usr/local/etc/php/conf.d/ext-redis.ini && \
    cd / && \
    rm -rf /tmp/yaml /tmp/redis

RUN cd /tmp && \
    git clone https://github.com/phpv8/v8js.git && \
    cd v8js && \
    phpize && \
    ./configure --with-v8js && \
    make && \
    make install && \
    echo "extension=v8js.so" > /usr/local/etc/php/conf.d/ext-v8js.ini && \
    cd / && \
    rm -rf /tmp/v8js

COPY docker/app/php/conf.d/opcache.ini ${PHP_INI_DIR}/conf.d/opcache.ini
COPY docker/app/php/conf.d/docker-fpm.ini ${PHP_INI_DIR}/conf.d/docker-fpm.ini
RUN echo "memory_limit=2048M" > ${PHP_INI_DIR}/conf.d/memory-limit.ini

ARG WITH_XDEBUG=false
RUN if [ ${WITH_XDEBUG} = true ] ; then \
        pecl install xdebug; \
        docker-php-ext-enable xdebug; \
        echo "error_reporting = E_ALL" >> ${PHP_INI_DIR}/conf.d/docker-php-ext-xdebug.ini; \
        echo "display_startup_errors = On" >> ${PHP_INI_DIR}/conf.d/docker-php-ext-xdebug.ini; \
        echo "display_errors = On" >> ${PHP_INI_DIR}/conf.d/docker-php-ext-xdebug.ini; \
        echo "xdebug.idekey=PHPSTORM" >> ${PHP_INI_DIR}/conf.d/docker-php-ext-xdebug.ini; \
        echo "xdebug.start_with_request=yes" >> ${PHP_INI_DIR}/conf.d/docker-php-ext-xdebug.ini; \
        echo "xdebug.client_host=host.docker.internal" >> ${PHP_INI_DIR}/conf.d/docker-php-ext-xdebug.ini; \
        echo "xdebug.mode=debug" >> ${PHP_INI_DIR}/conf.d/docker-php-ext-xdebug.ini; \
        echo "xdebug.log = /tmp/xdebug_remote.log" >> ${PHP_INI_DIR}/conf.d/docker-php-ext-xdebug.ini; \
    fi ;

COPY . ${PROJECT_ROOT}

COPY docker/app/entrypoint.sh /entrypoint.sh
RUN chmod 777 /entrypoint.sh && \
    chmod -R 777 bootstrap storage 2>/dev/null || true

RUN docker-php-source delete && \
    apt-get purge -y autoconf automake libtool && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /tmp/* /var/cache/* /var/lib/apt/lists/*

ENTRYPOINT ["/entrypoint.sh"]
