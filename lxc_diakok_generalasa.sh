#!/bin/bash

SABLON_NEV="diak-template"
GATEWAY_IP="10.0.59.1"
DNS_SZERVER="1.1.1.1 8.8.8.8"

read -p "Osztály jelölése (pl. 13C): " OSZTALY
read -p "Hány konténer készüljön?: " DARAB
read -p "Kezdő IP (pl. 10.0.59.198): " KEZDO_IP

ALAP_RESZ=$(echo "$KEZDO_IP" | cut -d'.' -f1-3)
UTOLSO_OKTET=$(echo "$KEZDO_IP" | cut -d'.' -f4)

if ! [[ "$DARAB" =~ ^[0-9]+$ ]]; then
    echo "Hibás darabszám."
    exit 1
fi

for ((i=1; i<=DARAB; i++)); do
    AKT_OKTET=$((UTOLSO_OKTET - (i - 1)))
    if (( AKT_OKTET <= 0 )); then
        echo "HIBA: nincs elég IP."
        break
    fi

    UJ_IP="${ALAP_RESZ}.${AKT_OKTET}"
    KONTENER_NEV="${OSZTALY}-${AKT_OKTET}-diak-kontener"

    echo "Létrehozás: ${KONTENER_NEV}  →  ${UJ_IP}"

    if ! lxc copy "${SABLON_NEV}" "${KONTENER_NEV}"; then
        echo "HIBA: nem sikerült a másolás: ${KONTENER_NEV}"
        continue
    fi

    if ! lxc start "${KONTENER_NEV}"; then
        echo "HIBA: nem indult el: ${KONTENER_NEV}"
        continue
    fi

    lxc exec "${KONTENER_NEV}" -- bash -c "cat > /etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address ${UJ_IP}/24
    gateway ${GATEWAY_IP}
    dns-nameservers ${DNS_SZERVER}
EOF"

    if ! timeout 20s lxc restart "${KONTENER_NEV}"; then
        echo "Figyelem: restart elakadt, force ciklus: ${KONTENER_NEV}"
        lxc stop "${KONTENER_NEV}" --force || true
        if ! lxc start "${KONTENER_NEV}"; then
            echo "HIBA: nem sikerült újraindítani: ${KONTENER_NEV}"
            continue
        fi
    fi

    echo "Kész: ${KONTENER_NEV}"
done

echo "Script lefutott."
