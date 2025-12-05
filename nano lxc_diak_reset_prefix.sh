#!/bin/bash
set -e

ALAP_RESZ="10.0.59"
GATEWAY_IP="10.0.59.1"
DNS_SZERVER="1.1.1.1 8.8.8.8"
SABLON_NEV="diak-template"

read -p "Osztály prefix (pl. 13C): " PREFIX

# Prefixhez tartozó konténerek listája (pl. 13C-166-diak-kontener)
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
    # Név: 13C-166-diak-kontener  →  OKTET = 166
    OKTET=$(echo "$KONTENER_NEV" | cut -d'-' -f2)
    IP="${ALAP_RESZ}.${OKTET}"

    echo "Reset: ${KONTENER_NEV} -> ${IP}"

    # Régi konténer leállítása és törlése
    lxc stop "${KONTENER_NEV}" || true
    lxc delete "${KONTENER_NEV}" || true

    # Új konténer létrehozása a sablonból
    lxc copy "${SABLON_NEV}" "${KONTENER_NEV}"
    lxc start "${KONTENER_NEV}"

    # Várjuk meg, amíg a konténer tényleg elindul és elérhető
    for i in {1..20}; do
        if lxc exec "${KONTENER_NEV}" -- true 2>/dev/null; then
            break
        fi
        sleep 0.5
    done

    # Biztonsági tisztítás: ha volt systemd-networkd/netplan config, ne zavarjon be
    lxc exec "${KONTENER_NEV}" -- bash -c "rm -f /etc/systemd/network/*.network /etc/netplan/*.yaml 2>/dev/null || true"

    # Az EGYETLEN aktív hálózati config: /etc/network/interfaces
    lxc exec "${KONTENER_NEV}" -- bash -c "cat >/etc/network/interfaces" <<EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address ${IP}/24
    gateway ${GATEWAY_IP}
    dns-nameservers ${DNS_SZERVER}
EOF

    # resolv.conf felülírása
    lxc exec "${KONTENER_NEV}" -- bash -c "rm -f /etc/resolv.conf"
    lxc exec "${KONTENER_NEV}" -- bash -c "echo 'nameserver 1.1.1.1' > /etc/resolv.conf"
    lxc exec "${KONTENER_NEV}" -- bash -c "echo 'nameserver 8.8.8.8' >> /etc/resolv.conf"

    # Konténer újraindítása, hogy az új network config biztosan életbe lépjen
    lxc restart "${KONTENER_NEV}"

    echo "Kész: ${KONTENER_NEV} visszaállítva erre az IP-re: ${IP}"
done

echo "Prefix reset kész: ${PREFIX}-"
