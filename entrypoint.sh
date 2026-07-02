#!/bin/bash
set -e

# Настройка IP-форвардинга
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
sysctl -p

# Если конфиг уже существует — запускаем с ним
if [ -f /etc/wireguard/wg0.conf ]; then
    echo "Found existing config, starting AWG..."
    awg-quick up wg0
else
    echo "No config found. Generating new AWG configuration..."
    
    # Генерация ключей
    SERVER_PRIVATE_KEY=$(wg genkey)
    SERVER_PUBLIC_KEY=$(echo "$SERVER_PRIVATE_KEY" | wg pubkey)
    CLIENT_PRIVATE_KEY=$(wg genkey)
    CLIENT_PUBLIC_KEY=$(echo "$CLIENT_PRIVATE_KEY" | wg pubkey)
    CLIENT_PRESHARED_KEY=$(wg genpsk)
    
    # Сохранение ключей
    echo "$SERVER_PRIVATE_KEY" > /opt/amnezia/awg/server_private.key
    echo "$SERVER_PUBLIC_KEY" > /opt/amnezia/awg/server_public.key
    echo "$CLIENT_PRIVATE_KEY" > /opt/amnezia/awg/client_private.key
    echo "$CLIENT_PUBLIC_KEY" > /opt/amnezia/awg/client_public.key
    echo "$CLIENT_PRESHARED_KEY" > /opt/amnezia/awg/client_preshared.key
    
    # Определение подсети
    SUBNET="${AWG_INTERNAL_SUBNET:-10.8.0.0/16}"
    SERVER_IP=$(echo "$SUBNET" | sed 's|0\.0/16|1.1/32|')
    CLIENT_IP=$(echo "$SUBNET" | sed 's|0\.0/16|2.2/32|')
    
    # Создание конфига сервера
    cat > /etc/wireguard/wg0.conf << EOF
[Interface]
PrivateKey = $SERVER_PRIVATE_KEY
Address = $SERVER_IP
ListenPort = ${AWG_SERVER_PORT}
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
MTU = 1420

[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
PresharedKey = $CLIENT_PRESHARED_KEY
AllowedIPs = $CLIENT_IP
EOF

    # Создание конфига клиента
    cat > /opt/amnezia/awg/vpn_client_1.conf << EOF
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_IP
DNS = 1.1.1.1, 8.8.8.8
MTU = 1420

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
PresharedKey = $CLIENT_PRESHARED_KEY
Endpoint = ${AWG_EXTERNAL_IP}:${AWG_SERVER_PORT}
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

    # Генерация QR-кода
    qrencode -t ansiutf8 < /opt/amnezia/awg/vpn_client_1.conf
    
    # Запуск AWG
    awg-quick up wg0
fi

# Бесконечный цикл для удержания контейнера
echo "AmneziaWG is running..."
tail -f /dev/null