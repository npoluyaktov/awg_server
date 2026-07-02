#!/bin/bash
set -e

echo "============================================"
echo "  AmneziaWG-Go Docker Container"
echo "============================================"

# Настройка сети
sysctl -w net.ipv4.ip_forward=1 2>/dev/null || true
sysctl -w net.ipv6.conf.all.forwarding=1 2>/dev/null || true

# Проверка модуля ядра
if [ ! -e /dev/net/tun ]; then
    echo "[WARN] /dev/net/tun not found, creating..."
    mkdir -p /dev/net
    mknod /dev/net/tun c 10 200 2>/dev/null || true
fi

# Функция проверки существующих конфигов
check_existing_config() {
    if [ -f /etc/wireguard/wg0.conf ]; then
        return 0
    fi
    return 1
}

# Функция создания конфига
create_config() {
    echo "[INFO] Generating new AmneziaWG configuration..."
    
    # Генерация ключей
    SERVER_PRIVATE=$(awg genkey)
    SERVER_PUBLIC=$(echo "$SERVER_PRIVATE" | awg pubkey)
    CLIENT_PRIVATE=$(awg genkey)
    CLIENT_PUBLIC=$(echo "$CLIENT_PRIVATE" | awg pubkey)
    CLIENT_PSK=$(awg genpsk)
    
    # Сохранение ключей
    mkdir -p /opt/amnezia/awg
    echo "$SERVER_PRIVATE" > /opt/amnezia/awg/server_private.key
    echo "$SERVER_PUBLIC" > /opt/amnezia/awg/server_public.key
    echo "$CLIENT_PRIVATE" > /opt/amnezia/awg/client_private.key
    echo "$CLIENT_PUBLIC" > /opt/amnezia/awg/client_public.key
    echo "$CLIENT_PSK" > /opt/amnezia/awg/client_preshared.key
    
    # Параметры
    SERVER_PORT="${AWG_SERVER_PORT:-51820}"
    EXTERNAL_IP="${AWG_EXTERNAL_IP:-127.0.0.1}"
    JUNK_PACKET_COUNT="${AWG_JUNK_PACKET_COUNT:-0}"
    JUNK_PACKET_MIN_SIZE="${AWG_JUNK_PACKET_MIN_SIZE:-40}"
    JUNK_PACKET_MAX_SIZE="${AWG_JUNK_PACKET_MAX_SIZE:-60}"
    INIT_PACKET_JUNK="${AWG_INIT_PACKET_JUNK:-0}"
    RESPONSE_PACKET_JUNK="${AWG_RESPONSE_PACKET_JUNK:-0}"
    
    SERVER_IP="10.8.1.1/24"
    CLIENT_IP="10.8.1.2/24"
    
    echo "[INFO] Creating server config..."
    cat > /etc/wireguard/wg0.conf << EOF
[Interface]
PrivateKey = $SERVER_PRIVATE
Address = $SERVER_IP
ListenPort = $SERVER_PORT
Jc = $JUNK_PACKET_COUNT
Jmin = $JUNK_PACKET_MIN_SIZE
Jmax = $JUNK_PACKET_MAX_SIZE
S1 = $INIT_PACKET_JUNK
S2 = $RESPONSE_PACKET_JUNK
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
MTU = 1420

[Peer]
PublicKey = $CLIENT_PUBLIC
PresharedKey = $CLIENT_PSK
AllowedIPs = $CLIENT_IP/32
EOF

    echo "[INFO] Creating client config..."
    cat > /opt/amnezia/awg/vpn_client_1.conf << EOF
[Interface]
PrivateKey = $CLIENT_PRIVATE
Address = $CLIENT_IP
DNS = 1.1.1.1, 8.8.8.8
Jc = $JUNK_PACKET_COUNT
Jmin = $JUNK_PACKET_MIN_SIZE
Jmax = $JUNK_PACKET_MAX_SIZE
S1 = $INIT_PACKET_JUNK
S2 = $RESPONSE_PACKET_JUNK
MTU = 1420

[Peer]
PublicKey = $SERVER_PUBLIC
PresharedKey = $CLIENT_PSK
Endpoint = $EXTERNAL_IP:$SERVER_PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

    echo "[OK] Config created!"
}

# Основная логика
if check_existing_config; then
    echo "[INFO] Found existing config, starting AmneziaWG..."
else
    create_config
fi

# Запуск AmneziaWG-Go
echo "[INFO] Starting AmneziaWG-Go interface..."
amneziawg-go wg0

# Показываем информацию
echo ""
echo "============================================"
echo "  ✅ AmneziaWG-Go is running!"
echo "============================================"
echo ""
echo "Interface info:"
awg show wg0
echo ""
echo "📁 Client config: /opt/amnezia/awg/vpn_client_1.conf"
echo ""
echo "QR Code:"
qrencode -t ansiutf8 < /opt/amnezia/awg/vpn_client_1.conf
echo ""
echo "============================================"

# Удержание контейнера
tail -f /dev/null
