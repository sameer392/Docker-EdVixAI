FROM php:8.4-fpm

# Install system dependencies and Supervisor
RUN apt-get update && apt-get install -y \
    supervisor \
    libzip-dev \
    zip \
    unzip \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libonig-dev \
    libxml2-dev \
    libicu-dev \
    curl \
    git \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        pdo_mysql \
        mysqli \
        zip \
        exif \
        pcntl \
        bcmath \
        gd \
        intl \
        opcache \
        soap \
        fileinfo \
        mbstring \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Optional: Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Custom PHP settings
COPY php-custom.ini /usr/local/etc/php/conf.d/99-custom.ini

# Supervisor
COPY supervisor/supervisord.conf /etc/supervisor/supervisord.conf
COPY supervisor/conf.d/ /etc/supervisor/conf.d/

WORKDIR /var/www

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
