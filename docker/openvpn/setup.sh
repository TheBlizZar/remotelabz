#!/bin/bash
# =============================================================================
# RemoteLabz – OpenVPN Container Setup
# =============================================================================
set -e

CA_PASS="${CA_PASS:-R3mot3!abz-0penVPN-CA2020}"   
PEM_PASS="${PEM_PASS:-R3mot3!abz-0penVPN-CA2020}" 
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

step "1/4 — EasyRSA PKI & CA"

cd "$EASYRSA_DIR"

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

sed -i "s/RANDFILE/#RANDFILE/g" openssl-easyrsa.cnf 2>/dev/null || true

# Init PKI
if [ ! -d pki ]; then
    log "Initializing PKI..."
    ./easyrsa init-pki
fi

if [ ! -f pki/ca.crt ]; then
    log "Building CA (CN: RemoteLabz-VPNServer-CA)..."

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

    log "CA built"
else
    warn "CA already exists — skipping"
fi

step "2/4 — Server Certificate (${SERVER_NAME})"

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

    log "Server certificate signed"
else
    warn "Server certificate already exists — skipping"
fi

step "3/4 — Installing Certificates & Generating Keys"

log "Copying certificates to ${OPENVPN_DIR}..."
cp pki/issued/${SERVER_NAME}.crt "${OPENVPN_DIR}/"
cp pki/private/${SERVER_NAME}.key "${OPENVPN_DIR}/"
cp pki/ca.crt                     "${OPENVPN_DIR}/"
cp pki/private/ca.key             "${OPENVPN_DIR}/"

if [ ! -f ta.key ]; then
    log "Generating TLS auth key (ta.key)..."
    openvpn --genkey secret ta.key
fi
cp ta.key "${OPENVPN_DIR}/"

if [ ! -f dh2048.pem ]; then
    log "Generating Diffie-Hellman parameters (this takes a while)..."
    openssl dhparam -out dh2048.pem 2048
fi
cp dh2048.pem "${OPENVPN_DIR}/"

chmod 600 "${OPENVPN_DIR}/"*.key "${OPENVPN_DIR}/ca.key"
chmod 644 "${OPENVPN_DIR}/"*.crt "${OPENVPN_DIR}/ta.key" "${OPENVPN_DIR}/dh2048.pem"

log "Certificates installed"

step "4/4 — IP Forwarding & OpenVPN"

echo 1 > /proc/sys/net/ipv4/ip_forward 2>/dev/null \
    || warn "Could not set ip_forward (may already be set by host)"

iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -j MASQUERADE 2>/dev/null \
    || warn "iptables MASQUERADE rule failed — add --cap-add=NET_ADMIN to compose"

log "Starting OpenVPN server..."
exec openvpn --config "${OPENVPN_DIR}/server.conf"
