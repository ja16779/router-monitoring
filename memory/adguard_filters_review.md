---
name: Revisión de Filtros AdGuard Home - Óptimos
description: Análisis y verificación de filtros de AdGuard Home (8 activos, bien configurados)
type: project
---

## Revisión de Filtros: 2026-04-07 ✅ ÓPTIMOS

**Estado**: 100% Operacional - Configuración excelente

---

## 📊 Estadísticas Actuales

| Métrica | Valor |
|---------|-------|
| Total queries (última hora) | 339 |
| Queries bloqueadas | 31 (9%) |
| Tiempo promedio respuesta | 0.155s |
| Upstreams usados | 2 primarios + 2 fallback |

---

## ✅ Filtros Habilitados (8)

### ESENCIALES
1. **AdGuard DNS filter** - Base de filtrado
2. **Phishing Army** - Protección contra malware/phishing
3. **Malicious URL Blocklist** - URLs peligrosas

### ALTAMENTE RECOMENDADOS
4. **HaGeZi Pro DNS Blocklist** - Ads, tracking, malware (muy efectivo)
5. **Easyprivacy** - Rastreadores de publicidad (excelente)
6. **Smart-TV Blocklist** - Necesario para LG TV (tu red tiene TV LG)

### COMPLEMENTARIOS
7. **Scam Blocklist by DurableNapkin** - Fraudes/scams
8. **NoCoin** - Protección contra cryptomining

---

## ❌ Filtros Deshabilitados (4)

| Filtro | Razón de deshabilitación |
|--------|-------------------------|
| AdAway Default | Redundante (AdGuard DNS es mejor) |
| CNAME disguised trackers | Redundante (Easyprivacy ya lo cubre) |
| HaGeZi Threat Intelligence | MUY agresivo (falsos positivos) |
| OISD Big List | MUY agresivo (redundancia con HaGeZi) |

**Conclusión**: Decisión CORRECTA - Los deshabilitados son redundantes o demasiado agresivos.

---

## ✅ Whitelist (Excepciones Configuradas)

### SERVICIOS CRÍTICOS
```
@@||coppel.com^$important          # Banco Coppel
@@||banamex.com^$important          # Banamex
@@||content22.bancanet.banamex.com^ # Bancanet
@@||api.us-east-1.aiv-delivery.net^ # Prime Video (AWS)
```

### LG TV (NECESARIAS)
```
@@||lgtvsdp.com^
@@||lgappstv.com^
@@||lge.com^
@@||lgtvcommon.com^$important
@@||lgsmartad.com^$important
@@||yumenetworks.com^$important
```

### APLICACIONES
```
@@||data.cline.bot^ # Cline app
@@||graph.instagram.com^ # Instagram
@@||graph-fallback.instagram.com^ # Instagram fallback
```

**Conclusión**: Whitelist CORRECTA - Cubre servicios esenciales.

---

## 🛡️ Reglas Personalizadas

### BLOQUEADOS (Control Parental)
```
||xxx.com^$important
||xvideos^$important
||xvideos.com^$important
||pornhub.com^$important
||ads-api.tiktok.com^ # Ads de TikTok
||3gppnetwork.org^
```

### WHITELIST (Excepciones especiales)
- LG TV (completa)
- Bancos mexicanos
- Instagram APIs
- Prime Video
- Cline app

---

## 🌐 Upstreams DNS (Configuración)

### Primarios (Load Balance)
- `tls://8.8.8.8:853` - Google DoT
- `tls://1.1.1.1:853` - Cloudflare DoT

### Fallback (si fallan primarios)
- `tls://1.1.1.1` - Cloudflare DoH
- `tls://8.8.8.8` - Google DoH

### Bootstrap (resolución inicial)
- `8.8.8.8` - Para startup

**Ventajas**:
✅ DNS sobre TLS (encriptado)
✅ Redundancia automática
✅ Sin dependencia de Unbound
✅ Servidores confiables

---

## 🔒 Configuración de Seguridad

| Setting | Estado | Nota |
|---------|--------|------|
| DNSSEC | ✅ Habilitado | Validación de integridad |
| Safe Search | ❌ Deshabilitado | No aplica filtro familiar |
| IPv6 | ❌ Deshabilitado | aaaa_disabled: true |
| Anonymize Client IP | ❌ | Ver IPs reales en logs |
| Cache | ✅ Habilitado | Optimización de velocidad |
| DoT/DoH | ✅ | Encriptación completa |

---

## ✅ Top Dominios Bloqueados (Últimas queries)

```
app-analytics-services.com     (6) - Google Analytics
app-measurement.com            (3) - App measurement
google-analytics               (2) - Analytics
amazon-adsystem (mdtb)         (2) - Amazon Ads
doubleclick.net               (2) - Google Ads
googleads.g.doubleclick.net    (2) - Google Ads
rubicon prebid-server         (2) - Ad network
firebaselogging               (2) - Google Firebase
apple ads (ca.iadsdk)         (2) - Apple Ads
```

**Conclusión**: Bloqueando correctamente trackers de marketing y análisis.

---

## ⚠️ Problemas Encontrados y RESUELTOS

### Problema 1: Permisos de directorios
- **Síntoma**: Logs repetitivos "unexpected permissions type=directory"
- **Causa**: `/var/lib/adguardhome/data/filters` con permisos 0755
- **Solución**: Cambiado a 0700
- **Estado**: ✅ RESUELTO

### Problema 2: Referencias a Unbound
- **Síntoma**: Upstreams pointing to 127.0.0.1:5335 (Unbound)
- **Causa**: Configuración heredada cuando Unbound estaba activo
- **Solución**: Reemplazados con upstreams reales (Google, Cloudflare)
- **Estado**: ✅ RESUELTO

### Problema 3: Upstreams no coincidían
- **Síntoma**: API mostraba DoH extras además de configurados
- **Causa**: fallback_dns también definido
- **Solución**: Documentar que es por redundancia (correcto)
- **Estado**: ✅ NO ES UN PROBLEMA

---

## 💡 Recomendaciones

### ✅ MANTENER IGUAL
1. Los 8 filtros activos están bien balanceados
2. Whitelist es apropiada para tus servicios
3. Upstreams son redundantes y seguros
4. Reglas personalizadas están correctas

### 🔍 MONITOREAR
- Estadísticas de bloqueo (actualmente 9%)
- Falsos positivos (sitios legales bloqueados)
- Velocidad de respuesta (0.155s es excelente)

### ❌ NO HACER
- No habilitar HaGeZi Threat Intelligence (demasiado agresivo)
- No habilitar OISD Big List (redundancia)
- No cambiar upstreams (ya están óptimos)

---

## 📌 CONCLUSIÓN FINAL

| Aspecto | Evaluación |
|---------|-----------|
| **Filtros** | ✅ ÓPTIMOS (8 activos, bien balanceados) |
| **Whitelist** | ✅ APROPIADA (servicios críticos cubiertos) |
| **Upstreams** | ✅ EXCELENTES (DoT redundante) |
| **Seguridad** | ✅ EXCELENTE (DNSSEC, encriptación) |
| **Rendimiento** | ✅ RÁPIDO (0.155s promedio) |
| **Configuración** | ✅ CORRECTA (sin Unbound, permisos OK) |

**VEREDICTO**: 🎯 Sistema de filtrado LISTO PARA PRODUCCIÓN
- No requiere cambios
- Protección adecuada sin sacrificar usabilidad
- Bien configurado para red con TV LG, bancos mexicanos, apps críticas

