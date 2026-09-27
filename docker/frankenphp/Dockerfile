ARG PHP_VERSION=8.4
FROM dunglas/frankenphp:1-php${PHP_VERSION}-alpine

RUN apk add --no-cache bash curl git unzip zip

COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/
RUN install-php-extensions gd pdo_mysql exif pcntl bcmath zip intl redis

COPY --from=composer:2.8 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

RUN addgroup -g 1000 laravel \
    && adduser -u 1000 -G laravel -s /bin/bash -D laravel

COPY php.ini /usr/local/etc/php/conf.d/custom.ini

USER laravel
