FROM php:8.4-apache

RUN apt-get update && apt-get install -y \
    git \
    unzip \
    zip \
    curl \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    librabbitmq-dev \
    libssh2-1-dev \
    libzip-dev \
    libicu-dev \
    libapache2-mod-shib \
    && rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd pdo_mysql zip intl bcmath opcache \
    && pecl install amqp ssh2-1.4.1 \
    && docker-php-ext-enable amqp ssh2

RUN a2enmod rewrite headers remoteip ssl shib

COPY config/apache/100-remotelabz.conf /etc/apache2/sites-available/
COPY config/apache/200-remotelabz-ssl.conf /etc/apache2/sites-available/

RUN a2dissite 000-default default-ssl && \
    a2ensite 100-remotelabz 200-remotelabz-ssl

RUN echo "memory_limit = 512M" > /usr/local/etc/php/conf.d/memory-limit.ini

ENV APACHE_DOCUMENT_ROOT /opt/remotelabz/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf \
    && sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g yarn configurable-http-proxy@5.0.1

COPY --from=composer:2.8.6 /usr/bin/composer /usr/bin/composer

WORKDIR /opt/remotelabz

COPY docker/front/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["entrypoint.sh"]

CMD ["apache2-foreground"]