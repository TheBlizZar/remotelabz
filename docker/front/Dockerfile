# Utilisation de l'image officielle PHP 8.4 avec Apache
FROM php:8.4-apache

# Installation des dépendances système requises par RemoteLabz
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

# Configuration et installation des extensions PHP
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd pdo_mysql zip intl bcmath opcache \
    && pecl install amqp ssh2-1.4.1 \
    && docker-php-ext-enable amqp ssh2

# Activation des modules Apache
RUN a2enmod rewrite headers remoteip ssl shib

# Copie et activation de ta propre configuration Apache
COPY config/apache/100-remotelabz.conf /etc/apache2/sites-available/
COPY config/apache/200-remotelabz-ssl.conf /etc/apache2/sites-available/

RUN a2dissite 000-default default-ssl && \
    a2ensite 100-remotelabz 200-remotelabz-ssl

# Augmentation de la mémoire PHP pour Symfony
RUN echo "memory_limit = 512M" > /usr/local/etc/php/conf.d/memory-limit.ini

# Changement du DocumentRoot pour pointer sur le dossier public de Symfony
ENV APACHE_DOCUMENT_ROOT /opt/remotelabz/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf \
    && sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

# Installation de Node.js (v20) et des outils NPM globaux
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g yarn configurable-http-proxy@5.0.1

# Installation de Composer
COPY --from=composer:2.8.6 /usr/bin/composer /usr/bin/composer

# Définition du répertoire de travail
WORKDIR /opt/remotelabz

# Copie de l'entrypoint
COPY docker/front/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["entrypoint.sh"]

# Commande par défaut (démarrage d'Apache en mode foreground)
CMD ["apache2-foreground"]