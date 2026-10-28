# Документация по образу: https://hub.docker.com/_/composer
FROM composer:lts AS composer-prod
WORKDIR /app
RUN --mount=type=bind,source=./app/private/composer.json,target=composer.json \
    --mount=type=bind,source=./app/private/composer.lock,target=composer.lock \
    --mount=type=cache,target=/tmp/cache \
    composer install --no-dev --no-interaction

# Документация по образу: https://hub.docker.com/_/composer
FROM composer:lts AS composer-dev
WORKDIR /app
RUN --mount=type=bind,source=./app/private/composer.json,target=composer.json \
    --mount=type=bind,source=./app/private/composer.lock,target=composer.lock \
    --mount=type=cache,target=/tmp/cache \
    composer install --no-interaction

# Документация по образу: https://github.com/docker-library/docs/tree/master/php
FROM php:8.5-apache-trixie AS base

# Если pecl нормально заработает, можно будет устанавливать через него. Пример:
# pecl install --configureoptions 'enable-memcached-json="yes" enable-memcached-igbinary="yes" enable-memcached-msgpack="yes"' memcached
RUN --mount=type=bind,source=exts/igbinary-3.2.17RC1.tar.gz,target=/tmp/igbinary-3.2.17RC1.tar.gz \
--mount=type=bind,source=exts/msgpack-php-3.0.1.tar.gz,target=/tmp/msgpack-php-3.0.1.tar.gz \
--mount=type=bind,source=exts/php-memcached-3.4.0.tar.gz,target=/tmp/php-memcached-3.4.0.tar.gz \
--mount=type=bind,source=exts/imagick-3.8.1.tar.gz,target=/tmp/imagick-3.8.1.tar.gz \
<<EOF
    apt-get update

    # Установка gd
    apt-get install -y --no-install-recommends \
        libgd-dev \
        libfreetype-dev \
        libjpeg-dev \
        libpng-dev \
        libwebp-dev
    docker-php-ext-configure gd --with-external-gd --with-freetype --with-jpeg --with-webp
    docker-php-ext-install -j$(nproc) gd

    # Установка intl
    apt-get install -y --no-install-recommends \
        libicu-dev
    docker-php-ext-configure intl
    docker-php-ext-install -j$(nproc) intl

    # Установка igbinary
    mkdir -p /tmp/install_tmp
    tar -xf /tmp/igbinary-3.2.17RC1.tar.gz -C /tmp/install_tmp --strip-components=1
    docker-php-ext-configure /tmp/install_tmp CFLAGS="-O2" --enable-igbinary
    docker-php-ext-install -j$(nproc) /tmp/install_tmp
    rm -r /tmp/install_tmp
	docker-php-ext-enable igbinary

    # Установка msgpack
    mkdir -p /tmp/install_tmp
    tar -xf /tmp/msgpack-php-3.0.1.tar.gz -C /tmp/install_tmp --strip-components=1
    docker-php-ext-configure /tmp/install_tmp --with-php-config=php-config
    docker-php-ext-install -j$(nproc) /tmp/install_tmp
    rm -r /tmp/install_tmp
    docker-php-ext-enable msgpack

    # Установка memcached
    apt-get install -y --no-install-recommends \
        libmemcached-dev \
        libssl-dev \
        zlib1g-dev
    mkdir -p /tmp/install_tmp
    tar -xf /tmp/php-memcached-3.4.0.tar.gz -C /tmp/install_tmp --strip-components=1
    docker-php-ext-configure /tmp/install_tmp \
        --enable-memcached-json \
        --enable-memcached-igbinary \
        --enable-memcached-msgpack
    docker-php-ext-install -j$(nproc) /tmp/install_tmp
    rm -r /tmp/install_tmp
    docker-php-ext-enable memcached

    # Установка mysqli
    docker-php-ext-configure mysqli
    docker-php-ext-install -j$(nproc) mysqli

    # Установка pdo_mysql
    docker-php-ext-configure pdo_mysql
    docker-php-ext-install -j$(nproc) pdo_mysql

    # Установка imagick
    apt-get install -y --no-install-recommends \
        libmagickwand-dev
    mkdir -p /tmp/install_tmp
    tar -xf /tmp/imagick-3.8.1.tar.gz -C /tmp/install_tmp --strip-components=1
    sed -i 's/@PACKAGE_VERSION@/3.8.1/g' /tmp/install_tmp/php_imagick.h
    docker-php-ext-configure /tmp/install_tmp
    docker-php-ext-install -j$(nproc) /tmp/install_tmp
    rm -r /tmp/install_tmp
    docker-php-ext-enable imagick

    # Установка zip
    apt-get install -y --no-install-recommends \
        libzip-dev
    docker-php-ext-configure zip
    docker-php-ext-install -j$(nproc) zip

    # Установка bz2
    docker-php-ext-configure bz2
    docker-php-ext-install -j$(nproc) bz2

    # Очистка
    apt-get clean
    rm -rf /var/lib/apt/lists/*
EOF

COPY /misc/apache2.conf /etc/apache2/apache2.conf
COPY /misc/000-default.conf /etc/apache2/sites-available/000-default.conf
RUN a2enmod rewrite

FROM base AS development

RUN --mount=type=bind,source=exts/xdebug-3.5.3.tar.gz,target=/tmp/xdebug-3.5.3.tar.gz \
<<EOF
    # Установка xdebug
    mkdir -p /tmp/install_tmp
    tar -xf /tmp/xdebug-3.5.3.tar.gz -C /tmp/install_tmp --strip-components=1
    docker-php-ext-configure /tmp/install_tmp
    docker-php-ext-install -j$(nproc) /tmp/install_tmp
    rm -r /tmp/install_tmp
    docker-php-ext-enable xdebug
EOF

# Скрипт и каталог для сборки отправленных локально email
COPY --chmod=755 ./misc/fakesendmail.sh /tmp/mails/fakesendmail.sh
RUN mkdir -p /tmp/mails/new
RUN chown www-data:www-data /tmp/mails/new
RUN echo "0" > /tmp/mails/num
RUN chown www-data:www-data /tmp/mails/num
VOLUME ["/tmp/mails/new"]

COPY ./misc/php.ini-development $PHP_INI_DIR/php.ini
COPY --from=composer-dev --chown=www-data app/vendor/ /var/www/html/private/vendor
COPY --chown=www-data ./app /var/www/html

USER www-data

FROM base AS production

COPY ./misc/php.ini-production $PHP_INI_DIR/php.ini
COPY --from=composer-prod --chown=www-data app/vendor/ /var/www/html/private/vendor
COPY --chown=www-data ./app /var/www/html
USER www-data
