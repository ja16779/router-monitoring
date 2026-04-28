---
name: RPS/RFS Network Optimization
description: Configuración de Receive Packet Steering (RPS) y Receive Flow Steering (RFS) para distribución de carga multi-core
type: project
originSessionId: 0ae2cb93-3170-4396-8c45-1af6ded5c062
---
## Optimización Aplicada (2026-04-22)

### Problema
Router Flint-2 (4 cores) tenía RPS mal configurado:
- eth0/eth1 (WANs): Solo distribuían a 1 core (core 2)
- br-lan: Deshabilitado completamente
- RFS: Deshabilitado

Esto causaba contención de CPU y subutilización de cores.

### Solución Aplicada

**RPS (Receive Packet Steering)** - Distribuir recepción de paquetes entre cores:
```bash
# Todos los interfaces ahora distribuyen a todos 4 cores
for intf in eth0 eth1 lan1 br-lan; do
  for queue in /sys/class/net/$intf/queues/rx-*/rps_cpus; do
    echo "f" > "$queue"  # f = 1111 binario = cores 0,1,2,3
  done
done
```

**RFS (Receive Flow Steering)** - Afinidad de flujos:
```bash
echo 32768 > /proc/sys/net/core/rps_sock_flow_entries
```

### Configuración Actual (2026-04-22)

| Interfaz | RPS Anterior | RPS Actual | Cores |
|----------|-------------|-----------|-------|
| eth0 (Telmex) | `4` (core 2) | `f` (todos) | 4 |
| eth1 (Megacable) | `4` (core 2) | `f` (todos) | 4 |
| lan1 | `f` (todos) | `f` (todos) | 4 |
| br-lan | `0` (ninguno) | `f` (todos) | 4 |

RFS: `0` → `32768` entries

### Persistencia

Agregado a `/etc/rc.local`:
```bash
# RPS optimization - Distribute RX load across all CPU cores
(
  for intf in eth0 eth1 lan1 br-lan; do
    for queue in /sys/class/net/$intf/queues/rx-*/rps_cpus; do
      [ -f "$queue" ] && echo "f" > "$queue"
    done
  done
  echo 32768 > /proc/sys/net/core/rps_sock_flow_entries
) &
```

### Impacto Esperado

**Mejoras:**
- ✅ Distribución equitativa de carga entre 4 cores
- ✅ Menor latencia en dual-WAN failover
- ✅ Mejor throughput en Tailscale exit node
- ✅ Respuesta DNS más rápida bajo carga
- ✅ WiFi más estable con alta concurrencia

**Nota:** Load average puede parecer más alto (normal - cores activos siendo utilizados)

### Monitoreo

Para verificar el impacto en próximas horas:
```bash
# Ver carga por core
mpstat -P ALL 1

# Ver tráfico por interfaz
ifstat -i eth0,eth1,br-lan 1

# Ver CPU load
watch -n 1 'cat /proc/loadavg'
```

### Referencias

- RPS en Linux: Distribución de carga de recepción entre CPUs
- RFS: Afinidad de flujos para localidad de caché
- Especialmente útil en routers con múltiples interfaces (dual-WAN) y alta concurrencia
