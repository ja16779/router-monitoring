---
name: AdGuardHome - Cliente LG Bypass
description: Configuración del cliente Tv Lg (192.168.10.103) con todos los filtros deshabilitados
type: project
---

## Cliente LG (Tv Lg) - Bypass AdGuardHome

**IP:** 192.168.10.103
**Estado:** Todos los filtros deshabilitados
**Objetivo:** Permitir funcionamiento de LG TV Apps y Canales

### Configuración Actual

```yaml
- name: Tv Lg
  ids:
    - 192.168.10.103
  filtering_enabled: false ← TODOS LOS FILTROS DESHABILITADOS
  parental_enabled: false
  safebrowsing_enabled: false
  use_global_settings: false
```

## Dominios Que Están Siendo Permitidos

### 🔴 CRÍTICOS para Canales/Apps
- `lgtvsdp.com` - LG TV Content Store
- `smartshare.lgtvsdp.com` - LG Smart Share
- `aic-ngfts.lge.com` - Servicios de Apps LG
- `androidtvchannels-pa.googleapis.com` - Google Play Channels
- `ngfts.lge.com` - Thumbnails/Galería
- `lgtvcommon.com` - Servicios comunes LG
- `rdx2.lgtvsdp.com` - Sincronización

### 🟡 SECUNDARIOS (Analytics/Publicidad)
- `ad.lgappstv.com` - Publicidad LG
- `ibis.lgappstv.com` - Analytics
- `ibs.lgappstv.com` - Analytics
- `lgsmartad.com` - Publicidad

## Impacto

### ✅ Ahora Funciona
- LG Content Store
- Canales de televisión
- Google Play Channels
- Smart Share
- Galerías y Thumbnails

### ⚠️ También Permitido
- Tracking y Analytics de LG
- Publicidad
- Recolección de datos de uso

## Fuente de Bloqueo Original

**Lista:** Smart-TV Blocklist for AdGuard Home (by Dandelion Sprout)
```
URL: https://raw.githubusercontent.com/Perflyst/PiHoleBlocklist/master/SmartTV-AGH.txt
Almacenado en: /var/lib/adguardhome/data/filters/1735355315.txt
```

## Alternativa Recomendada

Si quieres permitir SOLO canales sin permitir tracking:
1. Habilitar `filtering_enabled: true` para el cliente
2. Crear una whitelist solo con dominios críticos:
   - lgtvsdp.com
   - smartshare.lgtvsdp.com
   - androidtvchannels-pa.googleapis.com

Esto bloquearía publicidad/tracking pero permitiría funcionalidad completa de canales.
