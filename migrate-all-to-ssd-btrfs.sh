#!/usr/bin/env bash
set -euo pipefail

SSD_POOL="ssd-btrfs"
OLD_POOL="default"

echo "=== LXD konténerek költöztetése a ${OLD_POOL} poolról a ${SSD_POOL} poolra ==="
echo "FIGYELEM: minden érintett konténer le fog állni átmenetileg!"
echo

# Konténerek listája (csak a neveket kérjük CSV-ben)
containers=$(lxc list --format csv -c n)

for c in $containers; do
    echo ">>> Konténer: $c"

    # Ha már az SSD-n van (van volume az SSD poolban), akkor kihagyjuk
    if lxc storage volume show "${SSD_POOL}" "container/${c}" >/dev/null 2>&1; then
        echo "    Már az SSD poolon van (${SSD_POOL}), kihagyom."
        echo
        continue
    fi

    # Ha nincs a régi poolon, akkor valami extra (custom) lehet – inkább kihagyjuk
    if ! lxc storage volume show "${OLD_POOL}" "container/${c}" >/dev/null 2>&1; then
        echo "    Nem található a ${OLD_POOL} poolon sem – kihagyom (valószínűleg speciális eset)."
        echo
        continue
    fi

    echo "    Konténer még a ${OLD_POOL} poolon van, költöztetjük a ${SSD_POOL} poolra."

    echo "    Leállítás (normál módon, timeouttal)..."
    if ! timeout 20 lxc stop "$c" >/dev/null 2>&1; then
        echo "    Normál leállítás nem sikerült 20 mp-en belül, force stop..."
        lxc stop "$c" --force
    fi

    echo "    Mozgatás ${OLD_POOL} -> ${SSD_POOL} ..."
    lxc move "$c" "$c" --storage "${SSD_POOL}"

    echo "    Indítás..."
    lxc start "$c"

    echo "    Ellenőrzés (storage volume az SSD poolon)..."
    if lxc storage volume show "${SSD_POOL}" "container/${c}" >/dev/null 2>&1; then
        echo "    OK: $c most már az ${SSD_POOL} poolon van."
    else
        echo "    FIGYELEM: nem találom ${SSD_POOL} alatt a volume-ot $c-hez – kézzel ellenőrizd!"
    fi

    echo
done

echo "=== Kész: a script lefutott. Ellenőrizd néhány konténeren kézzel is az SSD-re költözést. ==="
