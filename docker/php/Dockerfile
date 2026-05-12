FROM php:8.4-fpm-alpine

# Install system deps + PHP extensions + PECL redis in one layer
# so build deps are removed before the layer is committed (smaller image)
RUN apk add --no-cache \
        bash curl git unzip zip \
        libpng-dev libjpeg-turbo-dev libwebp-dev freetype-dev \
        libzip-dev icu-dev oniguruma-dev libxml2-dev \
    && apk add --no-cache --virtual .build-deps \
        linux-headers $PHPIZE_DEPS \
    && docker-php-ext-configure gd \
        --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j$(nproc) \
        pdo pdo_mysql mbstring exif pcntl bcmath gd zip intl xml opcache \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apk del .build-deps \
    && rm -rf /tmp/* /var/cache/apk/*

# Install Composer (official method — no extra image needed)
COPY --from=composer:2.8 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Non-root user matching typical host UID
RUN addgroup -g 1000 laravel \
    && adduser -u 1000 -G laravel -s /bin/bash -D laravel

COPY php.ini /usr/local/etc/php/conf.d/custom.ini

USER laravel
