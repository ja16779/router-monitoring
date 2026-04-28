---
name: Arquitectura DNS — AdGuard Home → Unbound
description: Pipeline DNS correcto de Flint-2 con puertos y flujo de tráfico
type: project
originSessionId: f5639322-5c14-453f-82b7-08c9a1d5b769
---
## Arquitectura DNS de Flint-2

### Pipeline Correcto (2026-04-12)

```
Clientes DNS (puerto 53)
  ↓
AdGuard Home (127.0.0.1:53)  ← Recibe queries DNS de clientes
  ↓
Unbound (127.0.0.1:5335)     ← Upstream resolver
  ↓
Upstreams estáticos (8.8.8.8, 1.1.1.1)
```

### Puertos en Escucha

| Servicio | Puerto | Interfaz | Función |
|----------|--------|----------|---------|
| **AdGuard Home** | 53 | 127.0.0.1, ::1, 0.0.0.0 | DNS principal (clientes internos) |
| **AdGuard Home API** | 3000 | :: (IPv6) | Web UI / API de control (opcional) |
| **Unbound** | 5335 | 127.0.0.1, ::1 | Recursive resolver (upstream de AGH) |

### Configuración Actual (Verificado 2026-04-12)

**AdGuard Home**:
- Escucha: `0.0.0.0:53` (todos los clientes)
- Upstream: `127.0.0.1:5335` (Unbound)
- Versión: 0.107.73

**Unbound**:
- Escucha: `127.0.0.1:5335` (local only)
- Upstreams: 8.8.8.8, 1.1.1.1 (estáticos, sin Tailscale)
- Cache: 192MB (msg-cache 64MB + rrset-cache 128MB)
- Threads: 4

### Verificación

```sh
# Ver puerto DNS (53)
netstat -tlnp | grep :53

# Ver Unbound upstream (5335)
netstat -tlnp | grep 5335

# Test DNS
nslookup google.com 127.0.0.1

# Verificar que AGH apunta a Unbound
curl http://127.0.0.1:3000/control/status | jq '.upstream_dns'
```

### Cambio Documentado (2026-04-11)

- **Antes**: Documentación mencionaba "puerto 3053" para verificar AdGuard Home
- **Ahora**: Corregido a puerto **53** para DNS, puerto **3000** para API si es necesario
- **Nota**: El puerto 3053 NO se usa en esta instalación

### Script adguard_health.sh

**Problema**: Script de monitoreo `/usr/bin/monitor/adguard_health.sh` genera errores cada 10 minutos
- Verifica puerto 3053 (incorrecto)
- Debería verificar puerto 3000 (API) o 53 (DNS)

**Fix**: Actualizar el script para usar:
```bash
curl -s http://127.0.0.1:3000/control/status  # Para API
# O verificar DNS simplemente con nslookup
```

### Why
- **DNS debe escuchar en 53**: Estándar de protocolo, todos los clientes esperan este puerto
- **Unbound en 5335**: Evita conflicto con puerto 53, permite coexistencia de AGH
- **API en 3000**: Interfaz web de administración (opcional, no crítica para DNS)
- **Sin Tailscale**: Upstreams estáticos garantizan DNS incluso si Tailscale falla

### How to apply
- Cuando hagas router-check, verifica puerto 53 (no 3053) para DNS
- Para API de AdGuard Home, usa puerto 3000 si es necesario
- El pipeline ADH → Unbound es el correcto y está funcionando ✅
