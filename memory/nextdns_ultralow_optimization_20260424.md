---
name: NextDNS Ultralow DoH Optimization
description: Optimización DNS Flint-2: cambio de Anycast (66ms) a Ultralow DoH (13ms)
type: project
originSessionId: a1292108-e8e8-414e-b3e2-08db0a2954fb
---
## Optimización NextDNS - 2026-04-24

### Cambios Realizados

**Antes:**
```yaml
upstream_dns:
  - 127.0.0.1:5335
  - tls://dns1.nextdns.io       (Anycast DoT)
  - tls://dns2.nextdns.io       (Duplicado)
```
- Protocolo: DoT (DNS over TLS) - puerto 853
- IP Anycast: 45.90.28.0 (Delaware, USA)
- Latencia: **66ms**

**Después:**
```yaml
upstream_dns:
  - 127.0.0.1:5335
  - https://dns.nextdns.io/dns-query  (Ultralow DoH)
```
- Protocolo: DoH (DNS over HTTPS) - puerto 443
- IP Ultralow: 200.25.32.197 (Brasil/Latinoamérica)
- Latencia: **13ms**

### Resultados

| Métrica | Antes | Después | Mejora |
|---------|-------|---------|--------|
| Latencia NextDNS | 66ms | 13ms | **-80%** ⬇️ |
| Protocolo | DoT/TLS | DoH/HTTPS | ✅ Funciona mejor |
| Configuración | Duplicada | Limpia | ✅ Optimizado |
| Estadísticas | Antiguas | Reseteadas | ✅ Fresh data |

### Arquitectura Final

```
Clientes → AGH:53 → Unbound:5335 (0ms primario)
                  → NextDNS Ultralow DoH (13ms fallback)
```

**Upstream Mode:** `parallel` (respuesta más rápida gana)

### Respaldos

- Configuración anterior: `/etc/adguardhome/adguardhome.yaml.bak.ultralow`
- Estadísticas antiguas: `/etc/adguardhome/data/backup/`

### Por qué Ultralow?

**Why:** NextDNS Ultralow resuelve automáticamente a servidores geográficamente cercanos, reduciendo latencia significativamente.

**How to apply:** Usar `https://dns.nextdns.io/dns-query` como upstream en lugar de `tls://dns1.nextdns.io`. El sistema resuelve automáticamente al servidor más cercano (geolocalización IP).

### Referencias

- IP Anycast anterior: 45.90.28.0 (Wilmington, Delaware, USA)
- IP Ultralow actual: 200.25.32.197 (Brasil/Latinoamérica)
- NextDNS Help: Forced ultralow/anycast
