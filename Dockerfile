FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    AWG_SERVER_PORT=51820 \
    AWG_EXTERNAL_IP=127.0.0.1 \
    AWG_INTERNAL_SUBNET=10.8.0.0/16

# Установка необходимых пакетов
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    iptables \
    net-tools \
    iproute2 \
    qrencode \
    ca-certificates \
    wireguard-tools \
    && rm -rf /var/lib/apt/lists/*

# Скачивание готовых бинарников AmneziaWG с GitHub Releases
RUN mkdir -p /tmp/awg && \
    cd /tmp/awg && \
    wget -q https://github.com/amnezia-vpn/amneziawg-linux/releases/download/v1.0.4/amneziawg-linux-amd64.tar.gz && \
    tar -xzf amneziawg-linux-amd64.tar.gz && \
    cp awg /usr/bin/awg && \
    cp awg-quick /usr/bin/awg-quick && \
    chmod +x /usr/bin/awg /usr/bin/awg-quick && \
    rm -rf /tmp/awg

# Создание рабочих директорий
RUN mkdir -p /opt/amnezia/awg /etc/wireguard

# Копирование скрипта запуска
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE ${AWG_SERVER_PORT}/udp

VOLUME ["/opt/amnezia/awg", "/etc/wireguard"]

ENTRYPOINT ["/entrypoint.sh"]
