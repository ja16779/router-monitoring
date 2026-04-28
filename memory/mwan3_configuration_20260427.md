---
name: MWAN3 Dual-WAN Configuration — Flint-2
description: Configuración completa de MWAN3 con 2 interfaces WAN (Telmex + Megacable)
type: project
originSessionId: ae67fc42-954c-48f8-b197-a95f80c1176f
---
## Estado Actual (2026-04-27)

```
Interface Status:
  wan (Telmex):       ONLINE 70h:31m (uptime: 70h:31m:40s)
  secondwan (Mega):   ONLINE 70h:31m (uptime: 70h:31m:44s)

Load Balance:
  wan:       62% (weight 5)
  secondwan: 38% (weight 3)
```

---

## 1. Interfaces (Health Checks)

### WAN (Telmex)
| Parámetro | Valor | Descripción |
|-----------|-------|-------------|
| **Enabled** | ✓ | Interface activa |
| **Family** | IPv4 | Solo IPv4 (IPv6 unreachable) |
| **Track Method** | ping | Monitoreo con ICMP |
| **Track IPs** | 208.67.222.222, 208.67.220.220 | OpenDNS (2 IPs redundancia) |
| **Reliability** | 2 | Requiere 2 de 3 pings exitosos |
| **Count** | 3 | 3 pings por chequeo |
| **Timeout** | 6s | Máximo 6 segundos por ping |
| **Interval** | 5s | Chequeo cada 5 segundos |
| **Failure Interval** | 3s | Si falla, rechequea en 3s |
| **Recovery Interval** | 5s | Si se recupera, rechequea en 5s |
| **Down** | 5 | Fallos necesarios para marcar DOWN |
| **Up** | 5 | Éxitos necesarios para marcar UP |
| **Size** | 56 bytes | Tamaño del ping |
| **Max TTL** | 60 | TTL máximo |

### SECONDWAN (Megacable)
| Parámetro | Valor | Descripción |
|-----------|-------|-------------|
| **Enabled** | ✓ | Interface activa |
| **Family** | IPv4 | Solo IPv4 |
| **Track Method** | ping | Monitoreo con ICMP |
| **Track IPs** | 208.67.222.222, 208.67.220.220 | Mismos OpenDNS |
| **Reliability** | 2 | Requiere 2 de 2 pings |
| **Count** | 2 | 2 pings por chequeo (más agresivo) |
| **Timeout** | 6s | Máximo 6 segundos |
| **Interval** | 5s | Chequeo cada 5 segundos |
| **Check Quality** | ✓ | Verificar latencia/pérdida |
| **Failure Latency** | 250ms | Si latencia > 250ms → warning |
| **Failure Loss** | 20% | Si pérdida > 20% → warning |
| **Recovery Latency** | 150ms | Si latencia < 150ms → recovery |
| **Recovery Loss** | 5% | Si pérdida < 5% → recovery |

---

## 2. Members (Métricas y Pesos)

Los members definen cómo las rutas usan cada interfaz:

### WAN Members
| Member | Metric | Weight | Uso |
|--------|--------|--------|-----|
| **wan_m1_w3** | 1 (primaria) | 3 | Rutas prioritarias |
| **wan_m2_w3** | 2 (secundaria) | 3 | Rutas fallback |
| **wan_bal** | 1 (primaria) | 5 | Balanceo (62% tráfico) |

### SECONDWAN Members
| Member | Metric | Weight | Uso |
|--------|--------|--------|-----|
| **wanb_m1_w2** | 1 (primaria) | 2 | Rutas prioritarias |
| **wanb_m2_w2** | 2 (secundaria) | 2 | Rutas fallback |
| **wanb_bal** | 1 (primaria) | 3 | Balanceo (38% tráfico) |

---

## 3. Policies (Políticas de Enrutamiento)

### wan_only
- **Miembros**: wan_m1_w3
- **Uso**: Tráfico que SOLO usa Telmex
- **Reglas**: Tailscale (100.0.0.0/8)

### wanb_only
- **Miembros**: wanb_m1_w2
- **Uso**: Tráfico que SOLO usa Megacable
- **Reglas**: Red Telmex (192.168.1.0/24)

### balanced (default)
- **Miembros**: wan_bal (5), wanb_bal (3)
- **Uso**: Balanceo 62/38 entre ambas WANs
- **Reglas**: Red Normal (192.168.10.0/24)

### wan_wanb
- **Miembros**: wan_m1_w3, wanb_m2_w2
- **Uso**: Primaria Telmex, fallback Megacable
- **Reglas**: DNS (53, 853), Citi IP range (192.193.0.0/16)

### wanb_wan
- **Miembros**: wanb_m1_w2, wan_m2_w3
- **Uso**: Primaria Megacable, fallback Telmex
- **Reglas**: Xbox, Beryl, IoT, Papertrail

---

## 4. Rules (Reglas de Enrutamiento)

### Reglas Críticas

#### **DNS** (Prioridad máxima)
- **Protocolo**: UDP + TCP
- **Puerto**: 53 (DNS), 853 (DoT)
- **Política**: wan_wanb
- **Función**: Fuerza DNS a Telmex primaria (mejor latencia OpenDNS)

#### **Tailscale** (Prioridad 1)
- **Fuente**: 100.0.0.0/8
- **Política**: wan_only
- **Función**: Todo tráfico Tailscale siempre por Telmex

#### **Citi** (Sticky 300s)
- **Destino**: 192.193.0.0/16 (Citi México)
- **Política**: wan_wanb
- **Sticky**: Sí (300s)
- **Función**: Mantiene sesiones Citi en la misma WAN 5 minutos

### Reglas por Red/Dispositivo

| Regla | Origen | Política | Sticky | Notas |
|-------|--------|----------|--------|-------|
| **Telmex** | 192.168.1.0/24 | wanb_only | No | Red Telmex usa Megacable |
| **Mega** | 192.168.100.0/24 | wanb_only | No | Red Megacable usa Megacable |
| **Normal** | 192.168.10.0/24 | balanced | Sí (300s) | Red LAN: 62% Telmex / 38% Mega |
| **Xbox** | 192.168.10.244 | wanb_wan | Sí (300s) | Xbox: Megacable primaria |
| **Beryl** | 192.168.10.2 | wanb_wan | No | Router Beryl: Megacable primaria |
| **IoT** | 192.168.8.0/24 | wanb_wan | Sí (300s) | IoT VLAN: Megacable primaria |
| **Papertrail** | UDP 52356 | wanb_wan | Sí | Logs Papertrail: Megacable |

### Regla Default
- **Destino**: 0.0.0.0/0 (todo)
- **Política**: balanced
- **Sticky**: Sí (600s)
- **Función**: Fallback general, balanceo 62/38

---

## 5. Análisis de Tráfico Actual

```
Usuario Flint-2 (192.168.10.0/24):
├─ DNS (todos):        wan_wanb   (Telmex primaria)
├─ Tailscale:          wan_only   (Telmex siempre)
├─ Citi (192.193.0.0): wan_wanb   (Telmex primaria)
├─ Otro tráfico:       balanced   (62% Telmex, 38% Mega)

Usuario Telmex (192.168.1.0/24):
└─ Todo:               wanb_only  (Megacable siempre)

Usuario Megacable (192.168.100.0/24):
└─ Todo:               wanb_only  (Megacable siempre)

Dispositivos especiales:
├─ Xbox (192.168.10.244):    wanb_wan     (Mega primaria)
├─ Beryl (192.168.10.2):     wanb_wan     (Mega primaria)
├─ IoT (192.168.8.0/24):     wanb_wan     (Mega primaria)
└─ Papertrail logs:          wanb_wan     (Mega primaria)
```

---

## 6. Configuración Global

| Parámetro | Valor | Significado |
|-----------|-------|------------|
| **mmx_mask** | 0x3F00 | Máscara de tabla de rutas |
| **rt_table_lookup** | 220 | Tabla de rutas customizada |
| **logging** | enabled | Logs de MWAN3 activos |
| **loglevel** | notice | Nivel: info + warnings + errors |

---

## 7. Resumen Operacional

### ¿Por qué esta configuración?

1. **DNS separado (wan_wanb)**
   - OpenDNS en 208.67.222.222 responde mejor desde Telmex
   - Fallback automático a Megacable si Telmex cae

2. **Tailscale siempre por Telmex (wan_only)**
   - Evita cambios de IP durante conexiones
   - Mantiene exit-node estable

3. **Usuarios/redes separadas**
   - Telmex y Mega por Megacable: menos interferencia
   - LAN principal (10.0/24) balanceada: máximo throughput

4. **Dispositivos estratégicos en Megacable**
   - Xbox: mejor estabilidad para gaming
   - Beryl: router repetidor, mejor link
   - IoT: menos latencia variable

5. **Sticky sessions**
   - Citi, Normal, Xbox, IoT: 300s
   - Default: 600s
   - Evita cambio de IP a mitad de conexión

### Failover automático

Si **wan** (Telmex) cae:
- DNS: fallback a Megacable vía wan_wanb
- Tailscale: sin cambio (siempre wan_only, que fuerza Mega si wan no disponible)
- Usuarios: usan política "balanced" que se adapta automáticamente

Si **secondwan** (Megacable) cae:
- Xbox/Beryl/IoT: fallback automático a Telmex vía wanb_wan
- Papertrail: cambio a Telmex
- Normal users: compensan vía balanced

---

## 8. Notas de Monitoreo

- **Check frequency**: Cada 5 segundos (detecta fallos en <30s típicamente)
- **Recovery time**: 5-25 segundos (depende de "up" threshold)
- **Quality checks**: secondwan valida latencia y pérdida además de disponibilidad
- **Conntrack flush**: Limpia conexiones tracking al cambiar estado

---

## 9. Posibles Mejoras Futuras

- [ ] Agregar alerts Telegram en cambios de WAN
- [ ] Monitorear calidad de Telmex (actualmente solo ping)
- [ ] Aumentar weight de secondwan si tiene mejor latencia
- [ ] Agregar más IPs de tracking (Google, Cloudflare)
- [ ] Timeout protection en scripts MWAN3 (mwan3_test.sh)
