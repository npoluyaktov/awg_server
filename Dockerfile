FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    AWG_SERVER_PORT=51820 \
    AWG_EXTERNAL_IP=127.0.0.1 \
    AWG_INTERNAL_SUBNET=10.8.0.0/16

# Установка зависимостей для сборки
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    gnupg \
    iptables \
    net-tools \
    iproute2 \
    qrencode \
    ca-certificates \
    build-essential \
    linux-headers-generic \
    git \
    && rm -rf /var/lib/apt/lists/*

# Клонирование и сборка AmneziaWG
RUN git clone https://github.com/amnezia-vpn/amnezia-wg.git /tmp/amnezia-wg \
    && cd /tmp/amnezia-wg/src \
    && make \
    && make install \
    && rm -rf /tmp/amnezia-wg

# Создание симлинков для совместимости (awg-quick -> wg-quick)
RUN ln -s $(which wg) $(which wg 2>/dev/null | sed 's/wg$/awg/') || true \
    && ln -s $(which wg-quick) $(which wg-quick | sed 's/wg-quick$/awg-quick/') || true

# Создание рабочих директорий
RUN mkdir -p /opt/amnezia/awg /etc/wireguard

# Копирование скрипта запуска
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE ${AWG_SERVER_PORT}/udp

VOLUME ["/opt/amnezia/awg", "/etc/wireguard"]

ENTRYPOINT ["/entrypoint.sh"]
