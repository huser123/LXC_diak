#!/bin/bash
set -e

ALAP_RESZ="10.0.59"
GATEWAY_IP="10.0.59.1"
DNS1="1.1.1.1"
DNS2="8.8.8.8"
SABLON_NEV="diak-template"

read -p "Osztály prefix (pl. 13C): " PREFIX

LISTA=$(lxc list --format csv -c n | grep "^${PREFIX}-" || true)

if [ -z "$LISTA" ]; then
    echo "Nincs ilyen prefixű konténer: ${PREFIX}-"
    exit 1
fi

echo "Következő konténerek lesznek resetelve:"
echo "$LISTA"
read -p "Biztosan folytatod? (yes/no): " VALASZ
if [ "$VALASZ" != "yes" ]; then
    echo "Megszakítva."
    exit 0
fi

for KONTENER_NEV in $LISTA; do
    OKTET=$(echo "$KONTENER_NEV" | cut -d'-' -f2)
    IP="${ALAP_RESZ}.${OKTET}"

    echo "Reset: ${KONTENER_NEV} -> ${IP}"

    lxc stop "${KONTENER_NEV}" || true
    lxc delete "${KONTENER_NEV}"

    lxc copy "${SABLON_NEV}" "${KONTENER_NEV}"
    lxc start "${KONTENER_NEV}"

    sleep 2

    lxc exec "${KONTENER_NEV}" -- bash -c "cat >/etc/systemd/network/eth0.network" <<EOF
[Match]
Name=eth0
[Network]
DHCP=no
Address=${IP}/24
Gateway=${GATEWAY_IP}
DNS=${DNS1} ${DNS2}
EOF

    lxc exec "${KONTENER_NEV}" -- bash -c "rm -f /etc/resolv.conf"
    lxc exec "${KONTENER_NEV}" -- bash -c "echo 'nameserver ${DNS1}' > /etc/resolv.conf"
    lxc exec "${KONTENER_NEV}" -- bash -c "echo 'nameserver ${DNS2}' >> /etc/resolv.conf"

    lxc restart "${KONTENER_NEV}"

    echo "Kész: ${KONTENER_NEV}"
done

echo "Prefix reset kész: ${PREFIX}-"
