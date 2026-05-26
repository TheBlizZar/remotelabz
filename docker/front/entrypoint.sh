#!/bin/bash
# On arrête le script si une commande critique échoue
set -e

echo "🚀 Démarrage de l'initialisation du Front RemoteLabz..."

# Dire à Git de faire confiance au dossier
git config --global --add safe.directory /opt/remotelabz

# Donner une mémoire illimitée à Composer
export COMPOSER_MEMORY_LIMIT=-1

# 1. Installation des dépendances PHP
echo "📦 Installation de Composer..."
composer install --no-interaction --optimize-autoloader

# 2. Installation des dépendances Node
echo "📦 Installation de Yarn..."
yarn install

# 3. Compilation des assets (CSS/JS)
echo "🏗️ Compilation des assets (Yarn build)..."
yarn build

# 4. Mise à jour de la base de données
echo "🗄️ Mise à jour du schéma de base de données..."
php bin/console doctrine:schema:update --force --no-interaction || true

# 5. Gestion des permissions
echo "🔐 Ajustement des permissions..."
chown -R www-data:www-data var/ public/ || true

# 6. Configuration HTTPS / SSL
echo "🔒 Vérification des certificats HTTPS..."

# On génère le certificat là où tes fichiers Apache (200-remotelabz-ssl.conf) et ton .env l'attendent
if [ ! -f /etc/apache2/RemoteLabz-WebServer.crt ]; then
    echo "Génération d'un certificat SSL auto-signé..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/apache2/RemoteLabz-WebServer.key \
        -out /etc/apache2/RemoteLabz-WebServer.crt \
        -subj "/C=FR/O=RemoteLabz/CN=${PUBLIC_ADDRESS:-192.168.186.3}"
fi

echo "✅ Initialisation terminée. Démarrage d'Apache !"

# 7. Cette commande lance ce qui est défini dans le CMD du Dockerfile (apache2-foreground)
exec "$@"