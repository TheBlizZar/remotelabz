FROM ubuntu:22.04

LABEL maintainer="RemoteLabz"
LABEL description="OpenVPN server with EasyRSA 3.0.8 — mirrors install.sh setup_openvpn() + install_ssl()"

ENV DEBIAN_FRONTEND=noninteractive

# ── System packages ──────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y \
        openvpn \
        openssl \
        wget \
        tar \
        expect \
        iproute2 \
        iptables \
        net-tools \
        procps \
    && rm -rf /var/lib/apt/lists/*

# ── EasyRSA 3.0.8 (same version as install.sh) ───────────────────────────────
WORKDIR /root
RUN wget -q https://github.com/OpenVPN/easy-rsa/releases/download/v3.0.8/EasyRSA-3.0.8.tgz \
    && tar -xzf EasyRSA-3.0.8.tgz \
    && ln -s EasyRSA-3.0.8 EasyRSA \
    && rm EasyRSA-3.0.8.tgz

# ── Directories expected by make-client.sh ───────────────────────────────────
RUN mkdir -p /etc/openvpn/server \
             /etc/openvpn/client \
             /var/log/openvpn

# ── Copy configs & scripts ───────────────────────────────────────────────────
COPY server.conf    /etc/openvpn/server/server.conf
COPY setup.sh       /root/setup.sh
COPY make-client.sh /usr/local/bin/make-client.sh

RUN chmod +x /root/setup.sh /usr/local/bin/make-client.sh

# ── tun device & forwarding ──────────────────────────────────────────────────
# Requires: --cap-add=NET_ADMIN --device=/dev/net/tun (set in compose)

EXPOSE 1194/udp

ENTRYPOINT ["/root/setup.sh"]
