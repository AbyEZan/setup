#!/usr/bin/env bash
# Configura ddcutil para controlar el brillo de monitores externos en Fedora.
# Uso: ./setup-ddcutil-fedora.sh   (NO ejecutar como root; usa sudo internamente)

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Ejecuta el script como tu usuario normal (no con sudo). Pedirá sudo cuando lo necesite."
    exit 1
fi

RULES_SRC_NEW="/usr/share/ddcutil/data/60-ddcutil-i2c.rules"
RULES_SRC_OLD="/usr/share/ddcutil/data/45-ddcutil-i2c.rules"
RULES_DST_DIR="/etc/udev/rules.d"

echo "==> 1. Instalando ddcutil..."
sudo dnf install -y ddcutil

echo "==> 2. Cargando el módulo i2c-dev..."
sudo modprobe i2c-dev

echo "==> 3. Verificando soporte de brillo (VCP 0x10)..."
if ddcutil capabilities 2>/dev/null | grep -q "Feature: 10"; then
    echo "    OK: el monitor soporta control de brillo."
else
    echo "    AVISO: no se pudo confirmar el soporte (puede requerir permisos hasta reiniciar)."
    echo "    Prueba más tarde con: sudo ddcutil capabilities | grep 'Feature: 10'"
fi

echo "==> 4. Configurando regla udev..."
if [[ -f "$RULES_SRC_NEW" ]]; then
    RULES_FILE="$(basename "$RULES_SRC_NEW")"
    sudo cp "$RULES_SRC_NEW" "$RULES_DST_DIR/"
    # Fedora 40+: descomentar la línea que asigna el grupo i2c
    sudo sed -i -E 's/^#\s*(KERNEL=="i2c-\[0-9\]\*", GROUP="i2c", MODE="0660")/\1/' \
        "$RULES_DST_DIR/$RULES_FILE"
elif [[ -f "$RULES_SRC_OLD" ]]; then
    RULES_FILE="$(basename "$RULES_SRC_OLD")"
    sudo cp "$RULES_SRC_OLD" "$RULES_DST_DIR/"
else
    echo "No se encontró ningún archivo de reglas de ddcutil en /usr/share/ddcutil/data/"
    exit 1
fi
sudo udevadm control --reload-rules
sudo udevadm trigger

echo "==> 5. Creando grupo i2c y añadiendo a $USER..."
if ! getent group i2c >/dev/null; then
    sudo groupadd --system i2c
fi
sudo usermod -aG i2c "$USER"

echo "==> 6. Cargando i2c-dev automáticamente en cada arranque..."
echo "i2c-dev" | sudo tee /etc/modules-load.d/i2c.conf >/dev/null

echo
echo "Listo. Es necesario reiniciar para que se apliquen los cambios de grupo."
echo "Después del reinicio, prueba sin sudo:"
echo "    ddcutil detect"
echo "    ddcutil getvcp 10"
echo "    ddcutil setvcp 10 100"
echo

read -rp "¿Reiniciar ahora? [s/N] " resp
if [[ "${resp,,}" == "s" ]]; then
    sudo reboot
fi
