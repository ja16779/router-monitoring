#!/usr/bin/env bash
# router-backup.sh — Backup del Flint 2 (GL-MT6000) + Beryl AX
# Guarda los backups en PC y OneDrive
# Uso: router-backup.sh [etiqueta]
#   etiqueta: sufijo opcional, ej: "post-update" → backup-flint2-20260225-post-update.tar.gz

set -euo pipefail

FLINT_IP="192.168.8.1"
BERYL_IP="192.168.10.2"
ROUTER_USER="root"
ROUTER_PASS="admin"
PC_DIR="/c/Users/ja167"
ONEDRIVE_DIR="/c/Users/ja167/OneDrive/Backups/router"
DATE=$(date +%Y%m%d)
LABEL="${1:-}"
SUFFIX="${LABEL:+-$LABEL}"

ERRORS=0

mkdir -p "$ONEDRIVE_DIR"

# ─── Función para hacer backup de un router ───────────────────────────────────
backup_router() {
  local name="$1"
  local ip="$2"
  local filename="backup-${name}-${DATE}${SUFFIX}.tar.gz"
  local remote_path="/tmp/${filename}"
  local pc_path="${PC_DIR}/${filename}"
  local od_path="${ONEDRIVE_DIR}/${filename}"

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  ${name^^} (${ip}) — $(date '+%H:%M')"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Verificar conectividad
  if ! plink -ssh -l "$ROUTER_USER" -pw "$ROUTER_PASS" -batch "$ip" "echo ok" &>/dev/null; then
    echo "  ERROR: No se puede conectar a ${ip}. Saltando."
    ERRORS=$((ERRORS + 1))
    return
  fi

  # Crear backup en el router
  echo "  [1/4] Creando backup en el router..."
  plink -ssh -l "$ROUTER_USER" -pw "$ROUTER_PASS" -batch "$ip" \
    "sysupgrade -b ${remote_path} && echo OK" 2>&1 | grep -v "^$"

  # Descargar a la PC
  echo "  [2/4] Descargando a PC..."
  plink -ssh -l "$ROUTER_USER" -pw "$ROUTER_PASS" -batch "$ip" \
    "cat ${remote_path}" > "${pc_path}"
  echo "  OK → ${pc_path} ($(du -sh "${pc_path}" | cut -f1))"

  # Copiar a OneDrive
  echo "  [3/4] Copiando a OneDrive..."
  cp "${pc_path}" "${od_path}"
  echo "  OK → ${od_path}"

  # Verificar integridad (solo Flint tiene scripts/hotplugs)
  echo "  [4/4] Verificando integridad..."
  TOTAL=$(tar -tzf "${pc_path}" | wc -l)
  echo "  Total archivos: ${TOTAL}"
  if [ "$name" = "flint2" ]; then
    SCRIPTS=$(tar -tzf "${pc_path}" | grep -E "script|hotplug|monitor" | wc -l)
    echo "  Scripts/hotplugs: ${SCRIPTS}"
    if [ "$SCRIPTS" -lt 100 ]; then
      echo "  AVISO: Se esperan >100 scripts. Revisar sysupgrade.conf en el Flint 2."
      ERRORS=$((ERRORS + 1))
    else
      echo "  Integridad OK"
    fi
  else
    echo "  Integridad OK"
  fi

  # Limpiar /tmp del router
  plink -ssh -l "$ROUTER_USER" -pw "$ROUTER_PASS" -batch "$ip" \
    "rm -f ${remote_path}" 2>/dev/null || true

  # Rotar en OneDrive — conservar últimos 5 por router
  ls -t "${ONEDRIVE_DIR}"/backup-${name}-*.tar.gz 2>/dev/null | tail -n +6 | while read old; do
    echo "  Rotando: $(basename $old)"
    rm -f "$old"
  done
}

# ─── Main ─────────────────────────────────────────────────────────────────────
echo "========================================="
echo "  Router Backup — $(date '+%Y-%m-%d %H:%M')"
echo "  Etiqueta: ${LABEL:-ninguna}"
echo "========================================="

backup_router "flint2" "$FLINT_IP"
backup_router "beryl"  "$BERYL_IP"

# ─── Resumen ──────────────────────────────────────────────────────────────────
echo ""
echo "========================================="
echo "  BACKUP COMPLETADO"
echo "  PC       : ${PC_DIR}/backup-*-${DATE}${SUFFIX}.tar.gz"
echo "  OneDrive : ${ONEDRIVE_DIR}/"
if [ "$ERRORS" -gt 0 ]; then
  echo "  AVISOS   : ${ERRORS} error(es) — revisar salida arriba"
fi
echo "  Backups guardados en OneDrive:"
ls -lh "${ONEDRIVE_DIR}"/backup-*-*.tar.gz 2>/dev/null | awk '{print "    " $NF, $5}'
echo "========================================="
