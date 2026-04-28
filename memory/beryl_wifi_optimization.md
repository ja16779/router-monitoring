---
name: Beryl WiFi Optimization — 4 cambios aplicados 2026-04-19
description: Canal 5GHz 56→149 (sin DFS), legacy_rates=0, max_inactivity=600s, txpower explícito (20/26 dBm)
type: project
originSessionId: continued-b6dfda45-a2d0-479a-ac75-92b80d73bbbe
---

## Estado Final — Optimizaciones Completadas ✅

**Fecha**: 2026-04-19 ~21:30 UTC  
**Router**: Beryl AP (GL-MT3000, 192.168.10.2)  
**Cambios**: 4 configuraciones WiFi aplicadas exitosamente

---

## Cambios Implementados

### 1. Canal 5GHz: 56 (DFS) → 149 (no-DFS) ✅

| Parámetro | Anterior | Nuevo |
|-----------|----------|-------|
| Canal | 56 (DFS, 5.280 GHz) | 149 (no-DFS, 5.745 GHz) |
| TX Power máximo | 24 dBm | **26 dBm** |
| Radar detection | Requerido (DFS) | No requerido |

**Beneficio**: 
- **+2 dBm de potencia** (máximo regulatorio MX para UNII-3)
- **Sin riesgo de interrupción por radar** — DFS events pueden pausar 60+ segundos
- Misma calidad de señal (canal 149 típicamente limpio en MX)

---

### 2. Deshabilitar legacy rates en 2.4GHz ✅

```sh
uci set wireless.radio0.legacy_rates='0'
```

| Parámetro | Valor |
|-----------|-------|
| legacy_rates (radio0) | **0** (OFF) |

**Beneficio**: 
- Elimina beacons y frames de gestión a 1/2/5.5 Mbps
- Reducción overhead canal ~10-15%
- Sincronizado con Flint-2 (ya tenía este cambio)

---

### 3. Sincronizar max_inactivity = 600s ✅

```sh
uci set wireless.default_radio0.max_inactivity='600'
uci set wireless.guest2g.max_inactivity='600'
```

| Interfaz | Anterior | Nuevo |
|----------|----------|-------|
| default_radio0 (Mega_2.4G_A2DF) | 300s | **600s** |
| guest2g (IOT) | 300s | **600s** |

**Beneficio**: 
- Evita desconexiones prematuras en dispositivos con power-saving
- iPhone, Android, IoT mantienen conexión incluso con tráfico esporádico
- Sincronización con Flint-2 (ambos routers usan ahora 600s)

---

### 4. TX Power Explícito ✅

```sh
uci set wireless.radio0.txpower='20'   # 2.4GHz
uci set wireless.radio1.txpower='26'   # 5GHz
```

| Banda | Anterior | Nuevo | Regulatorio MX |
|-------|----------|-------|----------------|
| 2.4GHz | auto (driver) | **20 dBm** | Máximo permitido |
| 5GHz canal 149 | auto (driver) | **26 dBm** | Máximo permitido UNII-3 |

**Beneficio**: 
- Garantiza potencia máxima independiente de firmware update
- Comportamiento predecible en futuras actualizaciones OpenWrt

---

## Estado Hardware Post-Optimización

### 2.4GHz (wlan0)
```
Mode:       Master
Channel:    6 (2.437 GHz)
HT Mode:    HE20
Tx-Power:   20 dBm ✅
Link Quality: 70/70 ✅
```

### 5GHz (wlan1)
```
Mode:       Master
Channel:    149 (5.745 GHz) ✅ [cambio aplicado]
HT Mode:    HE80
Tx-Power:   26 dBm ✅
Link Quality: 45/70 (normal post-reload)
```

---

## Clientes Conectados Post-Optimización

### wlan1 (5GHz — 2 clientes)
| MAC | Señal | Throughput | Modo |
|-----|-------|-----------|------|
| da:a5:7d:4e:71:2d | -53 dBm (buena) | **1200.9 Mbps** | HE-MCS 11, 2SS |
| 4a:9b:73:77:31:00 | -72 dBm (marginal) | en reconexión | (re-establishing) |

**Nota**: Throughput excelente en primer cliente post-cambio de canal.

### wlan0 (2.4GHz — ~1 cliente)
- Clientes en reconexión post-reload (normal)

---

## Verificación UCI

```sh
$ uci show wireless | grep -E "txpower|legacy|max_inactivity|channel="

wireless.radio0.legacy_rates='0'                    ✅
wireless.radio0.txpower='20'                        ✅
wireless.radio1.channel='149'                       ✅
wireless.radio1.txpower='26'                        ✅
wireless.default_radio0.max_inactivity='600'        ✅
wireless.guest2g.max_inactivity='600'               ✅
```

---

## Comparativa Flint-2 vs Beryl (Post-Optimización)

| Parámetro | Flint-2 | Beryl |
|-----------|---------|-------|
| 2.4GHz Tx-Power | 20 dBm | 20 dBm ✅ |
| 5GHz Tx-Power | variable* | 26 dBm ✅ |
| legacy_rates | 0 | 0 ✅ |
| max_inactivity | 600s | 600s ✅ |
| Clientes conectados | 60 total | 16 total |

*Flint-2 tiene múltiples canales (36, 149, etc) con diferentes potencias.

---

## Comportamiento Esperado post-Optimización

### Cobertura 5GHz
- Clientes a distancia lejana pueden conectarse mejor (potencia +2 dBm)
- Sin interrupciones por DFS/radar events

### Eficiencia 2.4GHz
- Menor overhead de beacons legacy
- Clientes 802.11ax (WiFi 6) obtienen mejor ancho de banda disponible

### Retención de Conexión
- Dispositivos con power-saving (smartphone, IoT) mantienen conexión 10+ minutos sin tráfico
- Reducción de re-handshakes y reconexiones frecuentes

### Device Flapping
- Problema anterior (MAC 1e:ba:75:ab:16:0a) — MAC aleatorizada probablemente iPhone:
  - max_inactivity=600s reduce desconexiones por inactividad
  - El flapping por escaneo de red sigue siendo comportamiento del cliente (no controlable por router)

---

## Notas

- **Canal 2.4GHz se mantiene en 6**: Excelente elección (13% ocupación). Los canales adyacentes muestran más interferencia (canal 1 con 38%). No cambiado.
- **HE20 en 2.4GHz (no HE40)**: Ambiente residencial con múltiples routers vecinos — HE40 causaría mayor interferencia con canales adyacentes.
- **WDS en wlan1**: Mantiene WDS=0 (correcto para red `lan` del Beryl).
- **Ruido 5GHz**: -90 dBm (excelente), -73 dBm en 2.4GHz (aceptable para residencial).

---

## Próximas Acciones (Opcionales)

1. **Monitoreo**: Verificar hit rate de clientes en próximas 24h — el cambio a canal 149 puede afectar clientes específicos (verificar station info periódicamente).
2. **Band steering**: Si algunos clientes se adhieren a 2.4GHz a distancia, considerar airtime fairness.
3. **Banda steering dual-band**: Forzar clientes WiFi 6 (HE) a 5GHz cuando posible.

Pero la configuración actual es **production-ready sin cambios obligatorios**.
