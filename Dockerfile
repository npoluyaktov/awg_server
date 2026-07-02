FROM golang:1.22-alpine AS builder-go

# Установка зависимостей для сборки
RUN apk add --no-cache git make gcc musl-dev linux-headers

# Сборка amneziawg-go
WORKDIR /build/awg-go
RUN git clone https://github.com/amnezia-vpn/amneziawg-go.git .
RUN make

# Сборка amneziawg-tools
WORKDIR /build/awg-tools
RUN git clone https://github.com/amnezia-vpn/amneziawg-tools.git .
RUN make

# Финальный образ
FROM alpine:3.19

RUN apk add --no-cache \
    bash \
    curl \
    iptables \
    iproute2 \
    ip6tables \
    libqrencode \
    libqrencode-tools \
    libcap \
    procps

# Копирование бинарников amneziawg-go
COPY --from=builder-go /build/awg-go/amneziawg-go /usr/bin/amneziawg-go

# Копирование бинарников amneziawg-tools
COPY --from=builder-go /build/awg-tools/awg /usr/bin/awg
COPY --from=builder-go /build/awg-tools/awg-quick /usr/bin/awg-quick
COPY --from=builder-go /build/awg-tools/bash-completion/awg /usr/share/bash-completion/completions/awg 2>/dev/null || true

# Права на выполнение
RUN chmod +x /usr/bin/amneziawg-go /usr/bin/awg /usr/bin/awg-quick

# Даём права на работу с сетью
RUN setcap cap_net_admin,cap_net_raw+ep /usr/bin/amneziawg-go

# Создание symlink для совместимости (awg -> wg команды для скриптов)
RUN ln -sf /usr/bin/awg /usr/bin/wg || true
RUN ln -sf /usr/bin/awg-quick /usr/bin/wg-quick || true

# Создание рабочих директорий
RUN mkdir -p /opt/amnezia/awg /etc/wireguard /etc/amnezia

# Копирование entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 51820/udp

VOLUME ["/opt/amnezia/awg", "/etc/wireguard"]

ENTRYPOINT ["/entrypoint.sh"]
