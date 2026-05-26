#!/bin/bash -e
# =============================================================================
# RemoteLabz – OpenVPN Client Certificate Generator
# Adapted from bin/openvpn-client/make-client.sh for container use.
# Paths point to the container's /etc/openvpn/server directory.
# Usage: make-client.sh <login> <password> <validity_days>
# =============================================================================

KEY_COUNTRY="FR"
KEY_PROVINCE="MARNE"
KEY_CITY="Reims"
KEY_ORG="master-reseaux-telecom.fr"
KEY_EMAIL="admin@domaine.org"
KEY_ALGO="rsa"
KEY_LENGTH=4096
KEY_CN="RemoteLabz-VPNServer"

# ── Public address used in the .ovpn remote directive ─────────────────────────
# Override at runtime:  PUBLIC_ADDRESS=1.2.3.4 make-client.sh login pass 365
VPN_REMOTE="${PUBLIC_ADDRESS:-127.0.0.1}"
VPN_PORT="${VPN_PORT:-1194}"

LOGIN="$1"
PASSWORD="$2"
VALIDITY="$3"

CERT_CLIENT_DIR="/etc/openvpn/client"
CACERT="/etc/openvpn/server/ca.crt"
CAKEY="/etc/openvpn/server/ca.key"
SERVCERT="/etc/openvpn/server/${KEY_CN}.crt"
SERVKEY="/etc/openvpn/server/${KEY_CN}.key"
TAKEY="/etc/openvpn/server/ta.key"

usage() {
    echo "Usage: $0 <login> <password> <certificate_validity_days>"
    exit 1
}

[ $# -ne 3 ] && usage
[ ! -d "$CERT_CLIENT_DIR" ] && mkdir -p "$CERT_CLIENT_DIR"

if [ -f "${CERT_CLIENT_DIR}/${LOGIN}.key" ]; then
    echo "❌ Client '${LOGIN}' already exists — choose another name."
    exit 2
fi

echo "🔑 Generating client certificate for: ${LOGIN}"

# Store credentials (mirrors original script)
printf '%s\n%s\n' "$LOGIN" "$PASSWORD" > "${CERT_CLIENT_DIR}/${LOGIN}.txt"

# Generate private key + certificate request
openssl req \
    -out    "${CERT_CLIENT_DIR}/${LOGIN}.req" \
    -new \
    -newkey "${KEY_ALGO}:${KEY_LENGTH}" \
    -nodes \
    -keyout "${CERT_CLIENT_DIR}/${LOGIN}.key" \
    -subj   "/C=${KEY_COUNTRY}/ST=${KEY_PROVINCE}/L=${KEY_CITY}/O=${KEY_ORG}/CN=${KEY_CN}"

# Sign with CA
openssl x509 \
    -req \
    -days   "$VALIDITY" \
    -in     "${CERT_CLIENT_DIR}/${LOGIN}.req" \
    -out    "${CERT_CLIENT_DIR}/${LOGIN}.crt" \
    -CA     "$CACERT" \
    -CAkey  "$CAKEY" \
    -CAcreateserial

# Build .ovpn profile
OVPN_OUT="${CERT_CLIENT_DIR}/${LOGIN}.ovpn"

cat > "$OVPN_OUT" << EOF
client
dev tun
dev-type tun
tun-mtu 1500
cipher AES-256-GCM
remote ${VPN_REMOTE}
port ${VPN_PORT}
proto udp
resolv-retry infinite
key-direction 1
nobind
persist-key
persist-tun
verb 1
keepalive 5 30
comp-lzo
<ca>
EOF

cat "$CACERT"                       >> "$OVPN_OUT"
echo "</ca>"                        >> "$OVPN_OUT"
echo "<cert>"                       >> "$OVPN_OUT"
cat "${CERT_CLIENT_DIR}/${LOGIN}.crt" >> "$OVPN_OUT"
echo "</cert>"                      >> "$OVPN_OUT"
echo "<key>"                        >> "$OVPN_OUT"
cat "${CERT_CLIENT_DIR}/${LOGIN}.key" >> "$OVPN_OUT"
echo "</key>"                       >> "$OVPN_OUT"
echo "<tls-auth>"                   >> "$OVPN_OUT"
cat "$TAKEY"                        >> "$OVPN_OUT"
echo "</tls-auth>"                  >> "$OVPN_OUT"

chmod 600 "${CERT_CLIENT_DIR}/${LOGIN}.key" "${CERT_CLIENT_DIR}/${LOGIN}.ovpn"

echo "✅ Client profile ready: ${OVPN_OUT}"
echo "   Copy it to the client machine and import into OpenVPN."
