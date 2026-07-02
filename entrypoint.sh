#!/bin/bash
set -e

echo "============================================"
echo "  AmneziaWG-Go + AmneziaWG-Tools Docker"
echo "============================================"

# Проверка бинарников
echo "[CHECK] Verifying binaries..."
for bin in amneziawg-go awg awg-quick; do
    if command -v $bin &> /dev/null; then
        echo "  ✅ $bin: $($bin --version 2>&1 || echo 'installed')"
    else
        echo "  ❌ $bin not found!"
        exit 1
    fi
done

# Настройка сети
sysctl -w net.ipv4.ip_forward=1 2>/dev/null || true
sysctl -w net.ipv6.conf.all.forwarding=1 2>/dev/null || true

# Устройство TUN
if [ ! -e /dev/net/tun ]; then
    echo "[INFO] Creating /dev/net/tun..."
    mkdir -p /dev/net
    mknod /dev/net/tun c 10 200 2>/dev/null || true
    chmod 600 /dev/net/tun
fi

# Переменные маскировки с дефолтами
export Jc="${AWG_JUNK_PACKET_COUNT:-10}"
export Jmin="${AWG_JUNK_PACKET_MIN_SIZE:-50}"
export Jmax="${AWG_JUNK_PACKET_MAX_SIZE:-1000}"
export S1="${AWG_INIT_PACKET_JUNK:-15}"
export S2="${AWG_RESPONSE_PACKET_JUNK:-15}"
export H1="${AWG_INIT_PACKET_MAGIC_HEADER:-1}"
export H2="${AWG_RESPONSE_PACKET_MAGIC_HEADER:-2}"
export H3="${AWG_UNDERLOAD_PACKET_MAGIC_HEADER:-3}"
export H4="${AWG_TRANSPORT_PACKET_MAGIC_HEADER:-4}"

SERVER_PORT="${AWG_SERVER_PORT:-51820}"
EXTERNAL_IP="${AWG_EXTERNAL_IP:-127.0.0.1}"

# Функция создания конфигов
create_configs() {
    echo "[INFO] Generating new AmneziaWG keys and configs..."
    
    # Генерация ключей (используем awg из tools)
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
    
    SERVER_IP="10.8.1.1/24"
    CLIENT_IP="10.8.1.2/24"
    
    echo "[INFO] Creating server config /etc/wireguard/wg0.conf..."
    cat > /etc/wireguard/wg0.conf << EOF
[Interface]
PrivateKey = $SERVER_PRIVATE
Address = $SERVER_IP
ListenPort = $SERVER_PORT
Jc = $Jc
Jmin = $Jmin
Jmax = $Jmax
S1 = $S1
S2 = $S2
H1 = $H1
H2 = $H2
H3 = $H3
H4 = $H4
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
Jc = $Jc
Jmin = $Jmin
Jmax = $Jmax
S1 = $S1
S2 = $S2
H1 = $H1
H2 = $H2
H3 = $H3
H4 = $H4
MTU = 1420

[Peer]
PublicKey = $SERVER_PUBLIC
PresharedKey = $CLIENT_PSK
Endpoint = $EXTERNAL_IP:$SERVER_PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

    echo "[OK] Configs created!"
}

# Основной процесс
if [ -f /etc/wireguard/wg0.conf ]; then
    echo "[INFO] Found existing config, starting..."
else
    create_configs
fi

# Запуск интерфейса
echo "[INFO] Starting AmneziaWG interface wg0..."
awg-quick up wg0 || {
    echo "[ERROR] Failed to start wg0!"
    echo "[DEBUG] Trying to show interface status..."
    awg show 2>&1 || true
    exit 1
}

# Проверка
echo ""
echo "============================================"
echo "  ✅ AmneziaWG is running!"
echo "============================================"
echo ""
echo "[INFO] Interface status:"
awg show wg0
echo ""
echo "📁 Client config: /opt/amnezia/awg/vpn_client_1.conf"
echo ""
echo "📱 QR Code:"
qrencode -t ansiutf8 < /opt/amnezia/awg/vpn_client_1.conf
echo ""
echo "============================================"
echo "  Container will keep running..."
echo "  Use 'docker compose exec amneziawg-go awg show' for status"
echo "============================================"

# Держим контейнер
tail -f /dev/null
