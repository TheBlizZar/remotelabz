#!/bin/bash
# =============================================================================
# RemoteLabz – OpenVPN Container Setup
# Mirrors setup_openvpn() + install_ssl() from install.sh
# Non-interactive: passphrases come from environment variables.
# =============================================================================
set -e

# ── Configurable via docker-compose environment ───────────────────────────────
CA_PASS="${CA_PASS:-R3mot3!abz-0penVPN-CA2020}"      # CA key passphrase (docs default)
PEM_PASS="${PEM_PASS:-R3mot3!abz-0penVPN-CA2020}"     # PEM passphrase (same default)
PUBLIC_ADDRESS="${PUBLIC_ADDRESS:-127.0.0.1}"
SERVER_NAME="RemoteLabz-VPNServer"
EASYRSA_DIR="/root/EasyRSA"
OPENVPN_DIR="/etc/openvpn/server"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[SETUP]${NC} $1"; }
step() { echo -e "${CYAN}══════════════════════════════════════${NC}"; echo -e "${CYAN}  $1${NC}"; echo -e "${CYAN}══════════════════════════════════════${NC}"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $1"; }

# =============================================================================
# STEP 1 – EasyRSA PKI & CA
# =============================================================================
step "1/4 — EasyRSA PKI & CA"

cd "$EASYRSA_DIR"

# Write vars (identical to install.sh)
cat > vars << EOF
set_var EASYRSA_BATCH           "yes"
set_var EASYRSA_REQ_CN         "RemoteLabz-VPNServer-CA"
set_var EASYRSA_REQ_COUNTRY    "FR"
set_var EASYRSA_REQ_PROVINCE   "Grand-Est"
set_var EASYRSA_REQ_CITY       "Reims"
set_var EASYRSA_REQ_ORG        "RemoteLabz"
set_var EASYRSA_REQ_EMAIL      "contact@remotelabz.com"
set_var EASYRSA_REQ_OU         "RemoteLabz-VPNServer"
set_var EASYRSA_ALGO           "ec"
set_var EASYRSA_DIGEST         "sha512"
set_var EASYRSA_CURVE          secp384r1
set_var EASYRSA_CA_EXPIRE      1825
set_var EASYRSA_CERT_EXPIRE    1825
EOF

# Patch openssl config (same as install.sh)
sed -i "s/RANDFILE/#RANDFILE/g" openssl-easyrsa.cnf 2>/dev/null || true

# Init PKI
if [ ! -d pki ]; then
    log "Initializing PKI..."
    ./easyrsa init-pki
fi

# Build CA (non-interactive via expect, mirrors install.sh expect block)
if [ ! -f pki/ca.crt ]; then
    log "Building CA (CN: RemoteLabz-VPNServer-CA)..."

    # install.sh swaps CN to RemoteLabz-VPNServer for the server cert; CA keeps the -CA suffix
    expect << EXPECT_EOF
spawn ./easyrsa build-ca
expect "Enter New CA Key Passphrase:"
send "${CA_PASS}\r"
expect "Re-Enter New CA Key Passphrase:"
send "${CA_PASS}\r"
expect "Enter PEM pass phrase:"
send "${PEM_PASS}\r"
expect "Verifying - Enter PEM pass phrase:"
send "${PEM_PASS}\r"
expect eof
EXPECT_EOF

    log "CA built ✅"
else
    warn "CA already exists — skipping"
fi

# =============================================================================
# STEP 2 – Server certificate
# =============================================================================
step "2/4 — Server Certificate (${SERVER_NAME})"

# Switch CN to server name (mirrors install.sh: cp vars → vars-ca then sed)
cp vars vars-ca
sed -i "s/RemoteLabz-VPNServer-CA/RemoteLabz-VPNServer/g" vars

if [ ! -f "pki/issued/${SERVER_NAME}.crt" ]; then
    log "Generating server request (no passphrase on key)..."
    ./easyrsa gen-req "$SERVER_NAME" nopass

    log "Signing server certificate..."
    expect << EXPECT_EOF
spawn ./easyrsa sign-req server ${SERVER_NAME}
expect "Enter pass phrase for"
send "${PEM_PASS}\r"
expect eof
EXPECT_EOF

    log "Server certificate signed ✅"
else
    warn "Server certificate already exists — skipping"
fi

# =============================================================================
# STEP 3 – Install certs + generate ta.key & DH
# =============================================================================
step "3/4 — Installing Certificates & Generating Keys"

log "Copying certificates to ${OPENVPN_DIR}..."
cp pki/issued/${SERVER_NAME}.crt "${OPENVPN_DIR}/"
cp pki/private/${SERVER_NAME}.key "${OPENVPN_DIR}/"
cp pki/ca.crt                     "${OPENVPN_DIR}/"
cp pki/private/ca.key             "${OPENVPN_DIR}/"

# TLS auth key
if [ ! -f ta.key ]; then
    log "Generating TLS auth key (ta.key)..."
    openvpn --genkey secret ta.key
fi
cp ta.key "${OPENVPN_DIR}/"

# DH params (2048-bit, matches install.sh)
if [ ! -f dh2048.pem ]; then
    log "Generating Diffie-Hellman parameters (this takes a while)..."
    openssl dhparam -out dh2048.pem 2048
fi
cp dh2048.pem "${OPENVPN_DIR}/"

# Permissions (mirrors install.sh: chown www-data but in container we use nobody)
chmod 600 "${OPENVPN_DIR}/"*.key "${OPENVPN_DIR}/ca.key"
chmod 644 "${OPENVPN_DIR}/"*.crt "${OPENVPN_DIR}/ta.key" "${OPENVPN_DIR}/dh2048.pem"

log "Certificates installed ✅"

# =============================================================================
# STEP 4 – Enable IP forwarding & start OpenVPN
# =============================================================================
step "4/4 — IP Forwarding & OpenVPN"

# Enable IP forwarding (sysctl may be read-only in container; /proc/sys write is the fallback)
echo 1 > /proc/sys/net/ipv4/ip_forward 2>/dev/null \
    || warn "Could not set ip_forward (may already be set by host)"

# NAT rule so VPN clients can reach the outside
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -j MASQUERADE 2>/dev/null \
    || warn "iptables MASQUERADE rule failed — add --cap-add=NET_ADMIN to compose"

log "Starting OpenVPN server..."
exec openvpn --config "${OPENVPN_DIR}/server.conf"
