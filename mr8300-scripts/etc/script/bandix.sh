#!/bin/sh

# URLs de los paquetes
URL_BANDIX="https://github.com/timsaya/openwrt-bandix/releases/download/v0.6.1/bandix_0.6.1-r1_aarch64_cortex-a53.ipk"
URL_LUCI="https://github.com/timsaya/luci-app-bandix/releases/download/v0.6.3/luci-app-bandix_0.6.3-r1_all.ipk"

# Nombres de archivo
PKG_BANDIX="bandix_0.6.1-r1_aarch64_cortex-a53.ipk"
PKG_LUCI="luci-app-bandix_0.6.3-r1_all.ipk"

# Log de instalación
LOG="/tmp/bandix_install.log"

echo "=== Instalación de Bandix y LuCI App ===" | tee "$LOG"

download_and_install() {
    local url="$1"
    local pkg="$2"

    echo "Descargando $pkg..." | tee -a "$LOG"
    if wget --no-check-certificate -O "$pkg" "$url"; then
        echo "Descarga exitosa: $pkg" | tee -a "$LOG"
        echo "Instalando $pkg..." | tee -a "$LOG"
        if opkg install "$pkg"; then
            echo "Instalación completada: $pkg" | tee -a "$LOG"
        else
            echo "Error al instalar $pkg" | tee -a "$LOG"
        fi
    else
        echo "Error al descargar $pkg" | tee -a "$LOG"
    fi
}

download_and_install "$URL_BANDIX" "$PKG_BANDIX"
download_and_install "$URL_LUCI" "$PKG_LUCI"

echo "=== Proceso finalizado ===" | tee -a "$LOG"
