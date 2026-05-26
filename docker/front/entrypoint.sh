#!/bin/bash
set -e

echo "🚀 Démarrage de l'initialisation du Front RemoteLabz..."

git config --global --add safe.directory /opt/remotelabz

export COMPOSER_MEMORY_LIMIT=-1

echo "Installation de Composer..."
composer install --no-interaction --optimize-autoloader

echo "Installation de Yarn..."
yarn install

echo "Yarn build..."
yarn build

echo "Mise à jour du schéma de base de données..."
php bin/console doctrine:schema:update --force --no-interaction || true

echo "Ajustement des permissions..."
chown -R www-data:www-data var/ public/ || true

echo "Vérification des certificats HTTPS..."

if [ ! -f /etc/apache2/RemoteLabz-WebServer.crt ]; then
    echo "Génération d'un certificat SSL auto-signé..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/apache2/RemoteLabz-WebServer.key \
        -out /etc/apache2/RemoteLabz-WebServer.crt \
        -subj "/C=FR/O=RemoteLabz/CN=${PUBLIC_ADDRESS:-192.168.186.3}"
fi

echo "Initialisation terminée."

exec "$@"