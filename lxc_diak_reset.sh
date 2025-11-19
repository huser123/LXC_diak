#!/bin/bash
set -e

ALAP_RESZ="10.0.59"
GATEWAY_IP="10.0.59.1"
DNS_SZERVER="1.1.1.1 8.8.8.8"
SABLON_NEV="diak-template"

read -p "IP utolsó oktettje (pl. 198): " OKTET

if ! [[ "$OKTET" =~ ^[0-9]+$ ]]; then
    echo "Hibás oktett."
    exit 1
fi

if [ "$OKTET" -le 0 ] || [ "$OKTET" -ge 255 ]; then
    echo "Hibás tartomány."
    exit 1
fi

KONTENER_NEV=$(lxc list --format csv -c n | grep -E "^.+-${OKTET}-diak-kontener$" || true)

if [ -z "$KONTENER_NEV" ]; then
    echo "Nem található konténer *-${OKTET}-diak-kontener névvel."
    exit 1
fi

if [ "$(echo "$KONTENER_NEV" | wc -l)" -ne 1 ]; then
    echo "Több konténer is egyezik:"
    echo "$KONTENER_NEV"
    exit 1
fi

KONTENER_NEV=$(echo "$KONTENER_NEV" | head -n1)
UJ_IP="${ALAP_RESZ}.${OKTET}"

echo "Reset indul: ${KONTENER_NEV}  →  ${UJ_IP}"

lxc stop "${KONTENER_NEV}" || true
lxc delete "${KONTENER_NEV}"

lxc copy "${SABLON_NEV}" "${KONTENER_NEV}"
lxc start "${KONTENER_NEV}"

lxc exec "${KONTENER_NEV}" -- bash -c "cat >/etc/network/interfaces" <<EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address ${UJ_IP}/24
    gateway ${GATEWAY_IP}
    dns-nameservers ${DNS_SZERVER}
EOF

lxc restart "${KONTENER_NEV}"

echo "Kész: ${KONTENER_NEV} visszaállítva erre az IP-re: ${UJ_IP}"
