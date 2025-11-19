#!/bin/bash
set -e

SABLON_NEV="diak-template"
GATEWAY_IP="10.0.59.1"
DNS_SZERVER="1.1.1.1 8.8.8.8"

read -p "Osztály jelölése (pl. 13C): " OSZTALY
read -p "Hány konténer készüljön?: " DARAB
read -p "Kezdő IP (pl. 10.0.59.198): " KEZDO_IP

ALAP_RESZ=$(echo "$KEZDO_IP" | cut -d'.' -f1-3)
UTOLSO_OKTET=$(echo "$KEZDO_IP" | cut -d'.' -f4)

for ((i=1; i<=DARAB; i++)); do
    AKT_OKTET=$((UTOLSO_OKTET - (i - 1)))
    if (( AKT_OKTET <= 0 )); then
        echo "HIBA: nincs elég IP."
        exit 1
    fi

    UJ_IP="${ALAP_RESZ}.${AKT_OKTET}"
    KONTENER_NEV="${OSZTALY}-${AKT_OKTET}-diak-kontener"

    echo "Létrehozás: ${KONTENER_NEV}  →  ${UJ_IP}"

    lxc copy "${SABLON_NEV}" "${KONTENER_NEV}"
    lxc start "${KONTENER_NEV}"

    lxc exec "${KONTENER_NEV}" -- bash -c "cat > /etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address ${UJ_IP}/24
    gateway ${GATEWAY_IP}
    dns-nameservers ${DNS_SZERVER}
EOF"

    lxc restart "${KONTENER_NEV}"

    echo "Kész: ${KONTENER_NEV}"
done

echo "Összes konténer elkészült."
