FROM golang:1.22-alpine AS builder

# Установка зависимостей для сборки
RUN apk add --no-cache git make gcc musl-dev linux-headers

# Клонирование репозитория
WORKDIR /build
RUN git clone https://github.com/amnezia-vpn/amneziawg-go.git .

# Сборка
RUN make

# Финальный образ
FROM alpine:3.19

RUN apk add --no-cache \
    bash \
    curl \
    iptables \
    iproute2 \
    qrencode \
    libcap

# Копирование бинарников из builder
COPY --from=builder /build/amneziawg-go /usr/bin/amneziawg-go
COPY --from=builder /build/tools/awg /usr/bin/awg
COPY --from=builder /build/tools/awg-quick /usr/bin/awg-quick

# Даём права на выполнение
RUN chmod +x /usr/bin/amneziawg-go /usr/bin/awg /usr/bin/awg-quick

# Даём бинарнику права на работу с сетью без root
RUN setcap cap_net_admin+ep /usr/bin/amneziawg-go

# Создание рабочих директорий
RUN mkdir -p /opt/amnezia/awg /etc/wireguard

# Копирование entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 51820/udp

VOLUME ["/opt/amnezia/awg", "/etc/wireguard"]

ENTRYPOINT ["/entrypoint.sh"]
