---
name: RPS/RFS Monitoring & Validation
description: Scripts y procedimientos para monitorear la distribución de carga CPU con RPS/RFS
type: project
originSessionId: 0ae2cb93-3170-4396-8c45-1af6ded5c062
---
## Resumen Ejecutivo

**RPS (Receive Packet Steering)** y **RFS (Receive Flow Steering)** distribuyen la carga de procesamiento de paquetes entre múltiples cores de CPU. En el Flint-2 (4 cores), esto reduce contención y mejora rendimiento.

**Configuración actual (2026-04-22):**
- RPS: `f` (todos 4 cores) en eth0, eth1, br-lan
- RFS: `32768` entries
- Persistencia: `/etc/rc.local`

---

## Validación Manual

### Verificar Estado Actual
```bash
# RPS por interfaz
for intf in eth0 eth1 br-lan; do
  echo "$intf: $(cat /sys/class/net/$intf/queues/rx-0/rps_cpus)"
done

# RFS
cat /proc/sys/net/core/rps_sock_flow_entries
```

### Generar Carga y Monitorear
```bash
# Terminal 1: Monitorear en tiempo real
watch -n 1 'cat /proc/loadavg; echo "---"; for intf in eth0 eth1; do echo "$intf: $(cat /sys/class/net/$intf/queues/rx-0/rps_cpus)"; done'

# Terminal 2: Generar DNS queries (carga)
for i in {1..100}; do
  nslookup google.com 127.0.0.1 > /dev/null &
  nslookup cloudflare.com 127.0.0.1 > /dev/null &
done
wait
```

---

## Script de Monitoreo `/usr/bin/monitor/rps_rfs_monitor.sh`

Localización: `/usr/bin/monitor/rps_rfs_monitor.sh`
Cron: `*/10 * * * *` (cada 10 minutos)

**Funcionalidad:**
- Verificar RPS en eth0, eth1, br-lan
- Verificar RFS habilitado
- Detectar cambios inesperados
- Alertar a Telegram si hay desviaciones

**Modos de ejecución:**
```bash
/usr/bin/monitor/rps_rfs_monitor.sh --check   # Verificación instantánea
/usr/bin/monitor/rps_rfs_monitor.sh --live    # Dashboard (cada 2 segundos)
/usr/bin/monitor/rps_rfs_monitor.sh --alert   # Alertas si hay problemas
/usr/bin/monitor/rps_rfs_monitor.sh --restore # Restaurar si está deshabilitado
```

---

## Validación en Router-Check

Agregado automáticamente a `/router-check`:

```
✓ RPS/RFS (Receive Packet Steering / Flow Steering)
  RPS eth0: f ✅
  RPS eth1: f ✅
  RPS br-lan: f ✅
  RFS entries: 32768 ✅
  Load average: 0.06 (normal)
```

**Thresholds de alerta:**
- RPS no en `f`: ⚠️ WARNING (solo 1 core recibiendo paquetes)
- RFS < 32768: ⚠️ WARNING (flow steering debilitado)
- Load > 3.0 persistente: ⚠️ POSIBLE CONGESTIÓN

---

## Interpretación de Valores

### RPS (rps_cpus) - Máscara de Bits Hexadecimal
```
Valor Hex | Binario | Cores Activos | Descripción
---------|---------|---------------|------------------
    0    |  0000   | Ninguno       | RPS deshabilitado
    1    |  0001   | Core 0        | Solo 1 core
    4    |  0100   | Core 2        | Solo 1 core
    f    |  1111   | 0,1,2,3       | Todos 4 cores ✅

Ejemplo: "f" significa cores 0, 1, 2, 3 reciben paquetes
```

### RFS (rps_sock_flow_entries)
```
Valor    | Descripción
---------|------------------
    0    | RFS deshabilitado
 32768   | 32K entradas (recomendado para Flint-2) ✅
 65536   | 64K entradas (mayor consumo de RAM)
```

---

## Impacto Esperado

### Antes (RPS = 1 core, RFS = 0)
```
Load: [■■■░░░░░░░] 40% CPU
  Core 0: 5%
  Core 1: 35%  ← Sobrecarga
  Core 2: 0%
  Core 3: 0%
  → Contención, latencia alta en picos
```

### Después (RPS = 4 cores, RFS = 32768)
```
Load: [■■░░░░░░░░] 20% CPU
  Core 0: 10% ✅
  Core 1: 5%  ✅
  Core 2: 3%  ✅
  Core 3: 2%  ✅
  → Distribución equitativa, latencia baja
```

---

## Troubleshooting

| Síntoma | Causa | Solución |
|---------|-------|----------|
| RPS = `0` en eth0/eth1 | Interface reiniciada sin rc.local | Ejecutar `/etc/rc.local` manualmente |
| RFS = `0` | System cache limpiado | Correr script `--restore` |
| Load > 3.0 persistente | Posible DDoS o congestión | Verificar `mwan3 status` |
| Cambios no persisten | rc.local no ejecutó | Reiniciar router |

**Restaurar si está deshabilitado:**
```bash
for intf in eth0 eth1 br-lan; do
  for queue in /sys/class/net/$intf/queues/rx-*/rps_cpus; do
    echo "f" > "$queue"
  done
done
echo 32768 > /proc/sys/net/core/rps_sock_flow_entries
```

---

## Referencias

- RPS en Linux kernel: Distribución de carga de recepción
- RFS: Flow-based affinity para localidad de caché
- Especialmente útil en routers multi-interfaz (dual-WAN)
