FROM ubuntu:22.04

LABEL maintainer="RemoteLabz"
LABEL description="OpenVPN"

ENV DEBIAN_FRONTEND=noninteractive

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

WORKDIR /root
RUN wget -q https://github.com/OpenVPN/easy-rsa/releases/download/v3.0.8/EasyRSA-3.0.8.tgz \
    && tar -xzf EasyRSA-3.0.8.tgz \
    && ln -s EasyRSA-3.0.8 EasyRSA \
    && rm EasyRSA-3.0.8.tgz

RUN mkdir -p /etc/openvpn/server \
             /etc/openvpn/client \
             /var/log/openvpn

COPY server.conf    /etc/openvpn/server/server.conf
COPY setup.sh       /root/setup.sh
COPY make-client.sh /usr/local/bin/make-client.sh

RUN chmod +x /root/setup.sh /usr/local/bin/make-client.sh

EXPOSE 1194/udp

ENTRYPOINT ["/root/setup.sh"]
