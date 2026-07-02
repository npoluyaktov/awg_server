FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    AWG_SERVER_PORT=51820 \
    AWG_EXTERNAL_IP=127.0.0.1 \
    AWG_INTERNAL_SUBNET=10.8.0.0/16

# Установка необходимых пакетов
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    gnupg \
    iptables \
    net-tools \
    iproute2 \
    qrencode \
    wireguard-tools \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Установка AmneziaWG
RUN curl -fsSL https://raw.githubusercontent.com/amnezia-vpn/amnezia.org/master/script/awg-install.sh | bash

# Создание рабочих директорий
RUN mkdir -p /opt/amnezia/awg /etc/wireguard

# Копирование скрипта запуска
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE ${AWG_SERVER_PORT}/udp

VOLUME ["/opt/amnezia/awg", "/etc/wireguard"]

ENTRYPOINT ["/entrypoint.sh"]