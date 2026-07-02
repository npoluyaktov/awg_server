FROM golang:1.24-alpine AS builder-go

# Установка зависимостей для сборки
RUN apk add --no-cache git make gcc musl-dev linux-headers

# Сборка amneziawg-go
WORKDIR /build/awg-go
RUN git clone https://github.com/amnezia-vpn/amneziawg-go.git .
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
    procps \
    wireguard-tools

# Копирование бинарников amneziawg-go
COPY --from=builder-go /build/awg-go/amneziawg-go /usr/bin/amneziawg-go


# Права на выполнение
RUN chmod +x /usr/bin/amneziawg-go

# Даём права на работу с сетью
RUN setcap cap_net_admin,cap_net_raw+ep /usr/bin/amneziawg-go

# Создание рабочих директорий
RUN mkdir -p /opt/amnezia/awg /etc/wireguard /etc/amnezia

# Копирование entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 51820/udp

VOLUME ["/opt/amnezia/awg", "/etc/wireguard"]

ENTRYPOINT ["/entrypoint.sh"]
