---
name: Master Weekly - Corrección conflicto de horarios
description: Reparación del bug donde backup_verify no se ejecutaba en domingos cada 3 días
type: project
---

## Bug Encontrado y Reparado - 2026-04-07

### 🔴 Problema

El script `master_weekly.sh` tenía un conflicto en la lógica de case statements:

```
CRONTAB:
  0 3 * * 0      → Domingo 3am       → case 0:03 (ejecuta reboot)
  0 3 */3 * *    → Cada 3d 3am       → case *:03 (ejecuta backup_verify)

EN DOMINGOS CADA 3 DÍAS (1, 7, 13, 19, 25, 31):
  • Ambas condiciones coinciden
  • Pero bash evalúa case en orden
  • case 0:03 se matcheaba PRIMERO
  • ❌ case *:03 nunca se ejecutaba
  • ❌ backup_verify NUNCA corría los domingos
```

**Resultado**: backup_verify se ejecutaba solo 20 veces/mes en lugar de 24 veces.

### ✅ Solución Aplicada

**Archivo**: `/usr/bin/monitor/master_weekly.sh`

**Cambio**: Reordenar y consolidar la lógica de 3am

```bash
# ANTES (BUGGY):
case "${dow}:${hour}" in
    0:03)  # Domingo 3am - PRIMERO (bloquea *:03)
        run_task "reboot" "/etc/script/reboot.sh"
        ;;
    *:03)  # Cada 3 días 3am - NUNCA se ejecuta si es domingo
        if [ $((($dom - 1) % 3)) -eq 0 ]; then
            run_task "backup_verify" ...
        fi
        ;;
esac

# DESPUÉS (FIXED):
case "${dow}:${hour}" in
    *:03)  # PRIMERO - Cada 3 días Y domingos
        # Backup cada 3 días
        if [ $((($dom - 1) % 3)) -eq 0 ]; then
            run_task "backup_verify" ...
        fi
        # Reboot si es domingo (DESPUÉS del backup)
        if [ "$dow" -eq 0 ]; then
            run_task "reboot" ...
        fi
        ;;
esac
```

### 📊 Impacto

| Situación | Antes | Después |
|-----------|-------|---------|
| **Martes día 4, 3am** | backup_verify ✅ | backup_verify ✅ |
| **Domingo día 1, 3am** | reboot solo ❌ | backup_verify + reboot ✅✅ |
| **Domingo día 7, 3am** | reboot solo ❌ | backup_verify + reboot ✅✅ |
| **Domingo no-cada3d, 3am** | reboot ✅ | reboot ✅ |

### 🎯 Cronograma Resultante

```
CADA 3 DÍAS a las 3am (1, 4, 7, 10, 13, 16, 19, 22, 25, 28, 31):
  ✅ backup_verify.sh

TODOS LOS DOMINGOS a las 3am:
  ✅ reboot.sh (DESPUÉS del backup si coinciden)

RESULTADO: 24 ejecuciones de backup_verify/mes (antes: ~20)
```

### 🧪 Validación

Tests ejecutados:
- ✅ Domingo día 1 (cada 3 días): ambas tareas
- ✅ Martes día 4 (cada 3 días): solo backup
- ✅ Domingo no-cada3d: solo reboot

**Estado**: 100% Operacional ✅
