FROM php:8.4-fpm-alpine

# Install system dependencies
RUN apk add --no-cache \
    bash \
    curl \
    git \
    unzip \
    zip \
    libpng-dev \
    libjpeg-turbo-dev \
    libwebp-dev \
    freetype-dev \
    libzip-dev \
    icu-dev \
    oniguruma-dev \
    libxml2-dev \
    linux-headers \
    $PHPIZE_DEPS

# Configure and install PHP extensions required by Laravel
RUN docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
        --with-webp \
    && docker-php-ext-install -j$(nproc) \
        pdo \
        pdo_mysql \
        mbstring \
        exif \
        pcntl \
        bcmath \
        gd \
        zip \
        intl \
        xml \
        opcache

# Install Redis extension via PECL
RUN pecl install redis \
    && docker-php-ext-enable redis

# Clean up build deps to keep image small
RUN apk del $PHPIZE_DEPS \
    && rm -rf /tmp/* /var/cache/apk/*

# Install Composer (official method)
COPY --from=composer:2.8 /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www/html

# Create non-root user matching typical host UID
RUN addgroup -g 1000 laravel \
    && adduser -u 1000 -G laravel -s /bin/bash -D laravel

# Copy custom PHP config
COPY php.ini /usr/local/etc/php/conf.d/custom.ini

USER laravel
