#!/bin/sh
# Package Manager - Backup y restauración de paquetes OpenWrt
# Uso: pkg_manager.sh save    - Guarda lista de paquetes instalados
#       pkg_manager.sh restore - Restaura paquetes después de upgrade
#       pkg_manager.sh list    - Muestra paquetes que se restaurarían
#       pkg_manager.sh diff    - Muestra diferencias con el backup

LOGTAG="pkg-manager"
PKG_FILE="/etc/config/my_installed_packages"
PKG_BACKUP="/etc/config/my_installed_packages.bak"
EXCLUDE_FILE="/etc/config/pkg_exclude"
LOGFILE="/var/log/pkg-restore.log"

TELEGRAM_TOKEN="REDACTED_BOT_TOKEN"
TELEGRAM_CHAT_ID="716542586"
DEVICE_NAME="$(uname -n)"

send_telegram() {
    curl -skim 10 \
        --data disable_notification="false" \
        --data parse_mode="HTML" \
        --data chat_id="$TELEGRAM_CHAT_ID" \
        --data-urlencode "text=$1" \
        "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" >/dev/null 2>&1
}

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOGFILE"
    logger -t "$LOGTAG" "$*"
}

# Paquetes a excluir (kernel modules, GL.iNet base, nginx internos)
init_exclude() {
    if [ ! -f "$EXCLUDE_FILE" ]; then
        cat > "$EXCLUDE_FILE" << EXCL
# Paquetes a excluir de la restauración automática
# Kernel modules (dependen de la versión exacta del kernel)
kmod-*
# Paquetes que pueden romper la GUI de GL.iNet
nginx-ssl
nginx-mod-*
# LuCI (puede causar conflictos con GL.iNet GUI)
luci
luci-base
luci-light
luci-mod-*
luci-lib-*
luci-lua-*
luci-theme-*
luci-compat
luci-i18n-*
EXCL
        log "Archivo de exclusión creado: $EXCLUDE_FILE"
    fi
}

# Verificar si un paquete debe excluirse
is_excluded() {
    local pkg="$1"
    while IFS= read -r pattern; do
        # Ignorar comentarios y líneas vacías
        case "$pattern" in
            "#"*|"") continue ;;
        esac
        # Convertir glob a regex simple
        local regex=$(echo "$pattern" | sed s/*/.*/)
        echo "$pkg" | grep -qE "^${regex}$" && return 0
    done < "$EXCLUDE_FILE"
    return 1
}

# Obtener paquetes instalados por el usuario (no en ROM)
get_user_packages() {
    local rom_pkgs="/tmp/pkg_rom.tmp"
    local all_pkgs="/tmp/pkg_all.tmp"

    # Paquetes del ROM (vienen con el firmware)
    cat /rom/usr/lib/opkg/status 2>/dev/null | grep "^Package:" | cut -d" " -f2 | sort -u > "$rom_pkgs"

    # Todos los paquetes instalados
    opkg list-installed | cut -d" " -f1 | sort -u > "$all_pkgs"

    # Solo los que NO están en ROM = instalados por usuario
    grep -v -F -x -f "$rom_pkgs" "$all_pkgs"

    rm -f "$rom_pkgs" "$all_pkgs"
}

# SAVE: Guardar lista actual de paquetes
cmd_save() {
    init_exclude

    [ -f "$PKG_FILE" ] && cp "$PKG_FILE" "$PKG_BACKUP"

    local count=0
    > "$PKG_FILE"

    get_user_packages | while read pkg; do
        if ! is_excluded "$pkg"; then
            echo "$pkg" >> "$PKG_FILE"
        fi
    done

    count=$(wc -l < "$PKG_FILE")
    log "Guardados $count paquetes en $PKG_FILE"

    send_telegram "<b>📦 Package Backup — $DEVICE_NAME</b>
<pre>Paquetes guardados: $count
Archivo: $PKG_FILE</pre>
🕐 $(date '+%Y-%m-%d %H:%M:%S')"

    echo "Guardados $count paquetes en $PKG_FILE"
}

# RESTORE: Restaurar paquetes después de upgrade
cmd_restore() {
    init_exclude

    if [ ! -f "$PKG_FILE" ]; then
        log "ERROR: No existe $PKG_FILE. Ejecuta pkg_manager.sh save primero."
        exit 1
    fi

    > "$LOGFILE"
    log "=== Restauración de paquetes iniciada ==="

    # Actualizar repositorios
    log "Ejecutando opkg update..."
    if ! opkg update >> "$LOGFILE" 2>&1; then
        log "ERROR: opkg update falló"
        send_telegram "<b>📦 Package Restore FAILED — $DEVICE_NAME</b>
<pre>opkg update falló</pre>"
        exit 1
    fi

    # Obtener paquetes actuales
    opkg list-installed | cut -d" " -f1 | sort -u > /tmp/pkg_current.tmp

    # Paquetes que faltan
    local to_install=$(grep -v -F -x -f /tmp/pkg_current.tmp "$PKG_FILE" | sort -u)
    rm -f /tmp/pkg_current.tmp

    if [ -z "$to_install" ]; then
        log "Todos los paquetes ya están instalados"
        send_telegram "<b>📦 Package Restore — $DEVICE_NAME</b>
<pre>Todos los paquetes ya instalados ✓</pre>"
        exit 0
    fi

    local total=$(echo "$to_install" | wc -l)
    local ok=0
    local fail=0
    local ok_list=""
    local fail_list=""

    log "Instalando $total paquetes..."

    echo "$to_install" | while read pkg; do
        [ -z "$pkg" ] && continue
        log "Instalando: $pkg"
        if opkg install "$pkg" >> "$LOGFILE" 2>&1; then
            ok=$((ok + 1))
            ok_list="${ok_list}  ✓ ${pkg}\n"
            log "OK: $pkg"
        else
            fail=$((fail + 1))
            fail_list="${fail_list}  ✗ ${pkg}\n"
            log "FAIL: $pkg"
        fi
    done

    # Recontar desde el log porque el while es un subshell
    ok=$(grep -c "^.*OK:" "$LOGFILE")
    fail=$(grep -c "^.*FAIL:" "$LOGFILE")

    log "=== Restauración completada: $ok OK, $fail fallidos ==="

    MSG="<b>📦 Package Restore — $DEVICE_NAME</b>
━━━━━━━━━━━━━━━━━━━━
<pre>Instalados: $ok / $total</pre>"

    if [ "$fail" -gt 0 ]; then
        fail_pkgs=$(grep "FAIL:" "$LOGFILE" | sed s/.*FAIL: / ✗ /)
        MSG="${MSG}
<b>Fallidos:</b>
<pre>$fail_pkgs</pre>"
    fi

    MSG="${MSG}
🕐 $(date '+%Y-%m-%d %H:%M:%S')"

    send_telegram "$MSG"
    echo "Restauración completada: $ok OK, $fail fallidos"
    echo "Log completo: $LOGFILE"
}

# LIST: Mostrar paquetes que se restaurarían
cmd_list() {
    if [ ! -f "$PKG_FILE" ]; then
        echo "No existe $PKG_FILE. Ejecuta pkg_manager.sh save primero."
        exit 1
    fi

    opkg list-installed | cut -d" " -f1 | sort -u > /tmp/pkg_current.tmp
    local missing=$(grep -v -F -x -f /tmp/pkg_current.tmp "$PKG_FILE")
    rm -f /tmp/pkg_current.tmp

    if [ -z "$missing" ]; then
        echo "Todos los paquetes del backup ya están instalados."
    else
        echo "Paquetes que se instalarían con restore:"
        echo "$missing" | sed s/^/ /
        echo "Total: $(echo "$missing" | wc -l)"
    fi
}

# DIFF: Mostrar diferencias entre backup y estado actual
cmd_diff() {
    if [ ! -f "$PKG_FILE" ]; then
        echo "No existe $PKG_FILE"
        exit 1
    fi

    init_exclude

    local current="/tmp/pkg_current_filtered.tmp"
    get_user_packages | while read pkg; do
        is_excluded "$pkg" || echo "$pkg"
    done | sort -u > "$current"

    local saved=$(sort -u "$PKG_FILE")

    echo "=== En backup pero NO instalados ==="
    grep -v -F -x -f "$current" "$PKG_FILE" | sed s/^/ [-] / || echo "  (ninguno)"

    echo ""
    echo "=== Instalados pero NO en backup ==="
    grep -v -F -x -f "$PKG_FILE" "$current" | sed s/^/ [+] / || echo "  (ninguno)"

    rm -f "$current"
}

# Main
case "$1" in
    save)    cmd_save ;;
    restore) cmd_restore ;;
    list)    cmd_list ;;
    diff)    cmd_diff ;;
    *)
        echo "Uso: $0 {save|restore|list|diff}"
        echo "  save    - Guarda lista de paquetes instalados"
        echo "  restore - Restaura paquetes después de upgrade"
        echo "  list    - Muestra paquetes pendientes de instalar"
        echo "  diff    - Muestra diferencias con el backup"
        exit 1
        ;;
esac
