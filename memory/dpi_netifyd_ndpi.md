---
name: DPI - netifyd + nDPI (Deep Packet Inspection)
description: Sistema activo de clasificación de tráfico usando netifyd + librería nDPI, con reportes automáticos diarios
type: project
originSessionId: 2c96e426-51df-475d-b2cd-7438aa373e7f
---
## Estado: ✅ **ACTIVO Y FUNCIONANDO**

### Componentes Instalados

| Componente | Versión | Estado | Función |
|-----------|---------|--------|---------|
| **netifyd** | 4.4.7 | ✅ CORRIENDO | Daemon principal de DPI (aarch64, conntrack, netlink, dns-cache) |
| **libndpi** | 5.0.0 | ✅ Instalado | 2.4MB - Librería de clasificación de tráfico |
| **CrowdSec** | — | ✅ CORRIENDO | Análisis complementario de seguridad |

### Archivos y Directorios

```
Socket activo:         /var/run/netifyd/netifyd.sock
Caché de flujos:       /etc/netify.d/flow-hash-cache.dat (385.5KB)
DNS cache:             /etc/netify.d/dns-cache.csv (62.7K)
Base de apps:          /etc/netify.d/netify-apps.conf (135.2K)
Categorías:            /etc/netify.d/netify-categories.json (16.7K)
Config principal:      /etc/netifyd.conf
Config UCI:            /etc/config/netifyd (enabled=1, autoconfig=1)
PID:                   /var/run/netifyd/netifyd.pid
Status JSON:           /var/run/netifyd/status.json
```

### Clasificación de Tráfico

**Protocolos detectables** (35+):
- HTTP, HTTPS, DNS, FTP, SMTP, IMAP, POP3
- BitTorrent, Gnutella, NFS, SMBv1, SSH
- DHCP, NTP, SNMP, MySQL, PostgreSQL
- BGP, SYSLOG, XDMCP, CoAP, VMware
- Y más...

**Metadata capturada:**
- Origen/destino IP
- Puertos
- Aplicación detectada
- Categoría (redes sociales, streaming, etc.)
- Hit rate en caché DNS

### Reportes Automáticos

**Cron Schedule:**
```
08:00 AM diarios → /usr/bin/monitor/dpi_report.sh --report
```

**Ubicación en master scripts:**
- **Archivo:** `/usr/bin/monitor/master_daily.sh`
- **Línea:** `run_task "dpi_stats" "/usr/bin/monitor/dpi_report.sh --report"`
- **Hora:** 08:00 AM (hour 8 en master_daily.sh)

### Scripts de Reportería

**dpi_report.sh** (shell wrapper)
```bash
#!/bin/sh
# Modo --live: dashboard en terminal (actualiza cada 10s)
# Modo --report: genera reporte y envía por Telegram
```

**dpi_report.py** (implementación Python)
- Lee datos de `/var/run/netifyd/netifyd.sock`
- Carga hostnames desde DHCP leases
- Genera estadísticas de flujos clasificados
- Envía reportes via notificar.sh

### Cómo Ver en Vivo

```bash
ssh root@192.168.10.1 /usr/bin/monitor/dpi_report.sh --live
```

**Muestra:**
- ✅ Clasificación de aplicaciones en tiempo real
- ✅ Flujos de red detectados por IP
- ✅ Actualiza cada 10 segundos

### Notas Operativas

1. **Autoconfiguración:** netifyd detecta automáticamente interfaces (LAN/WAN)
2. **Caché activo:** 385.5KB de flujos almacenados para búsqueda rápida
3. **DNS cache:** 62.7K entradas de resoluciones DNS
4. **Señales internas:** Recibe señal RT35 periódicamente (normal)
5. **Sin puerto remoto:** netifyd usa socket UNIX, no TCP/IP

### Estadísticas Observadas (2026-04-11)

- **Flow cache:** 385.5KB (flujos clasificados)
- **DNS cache entries:** ~62.7K
- **Clasificables:** 17,000+ aplicaciones en base de datos
- **Protocolos:** 35+ tipos detectables

### Changelog

**v1.0.0 (2026-04-11)**
- Verificado que DPI funciona mediante netifyd + libndpi
- Confirmado reporte automático en master_daily.sh (08:00 AM)
- Scripts de reportería: dpi_report.sh + dpi_report.py
- CrowdSec activo como complemento
- Socket UNIX activo en `/var/run/netifyd/netifyd.sock`
