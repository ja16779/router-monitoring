#!/bin/sh
# Script de limpieza de archivos antiguos
# Elimina backups, logs y archivos temporales mayores a 7 dias

LOGTAG="cleanup"
DAYS_OLD=7
BACKUP_DEST=""

# Detectar destino segun router
case "$(uname -n)" in
    GL-MT6000)
        BACKUP_DEST="/tmp/mountd/disk2_part1"
        ;;
    GL-MT3000*)
        BACKUP_DEST="/tmp/mountd/disk1_part1/beryl"
        ;;
esac

# Funcion para limpiar archivos
cleanup_files() {
    local path="$1"
    local pattern="$2"
    local count=0

    [ -d "$path" ] || return 0

    count=$(find "$path" -maxdepth 1 -name "$pattern" -mtime +${DAYS_OLD} 2>/dev/null | wc -l)

    if [ "$count" -gt 0 ]; then
        find "$path" -maxdepth 1 -name "$pattern" -mtime +${DAYS_OLD} -exec rm -f {} \; 2>/dev/null
        logger -t "$LOGTAG" "Eliminados $count archivos $pattern en $path"
    fi
}

# Limpiar archivos temporales
cleanup_files "/tmp" "*.tar.gz"
cleanup_files "/tmp" "*.log"

# Limpiar scripts
cleanup_files "/etc/script" "*.tar.gz"
cleanup_files "/etc/script" "*.log"

# Limpiar logs del sistema
cleanup_files "/var/log" "*.log"

# Limpiar destino de backup si existe
if [ -d "$BACKUP_DEST" ]; then
    cleanup_files "$BACKUP_DEST" "backup*"
    cleanup_files "$BACKUP_DEST" "packages*"
    cleanup_files "$BACKUP_DEST" "my*"
    cleanup_files "${BACKUP_DEST}/script" "*.log"
fi

logger -t "$LOGTAG" "Limpieza completada"
