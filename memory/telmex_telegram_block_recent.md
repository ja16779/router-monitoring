---
name: Bloqueo Reciente de Telegram en Telmex (eth1)
description: Telmex bloqueó api.telegram.org entre 2026-04-07 y 2026-04-14
type: project
originSessionId: 5df9b90a-0dee-4075-a28c-7433d3d62640
---
## Descubrimiento (2026-04-14)

**Fecha de bloqueo:** Entre 2026-04-07 y 2026-04-14 (última confirmación de funcionamiento)

**Estado:** Telegram API BLOQUEADO en eth1 (Telmex), pero funciona en lan1 (Megacable)

## Evidencia Técnica

### Tests realizados 2026-04-14

| Test | eth1 (Telmex) | lan1 (Megacable) |
|------|---------------|-----------------|
| ICMP (ping) | ✅ Responde | ✅ Responde |
| HTTPS api.telegram.org | ❌ **BLOQUEADO** | ✅ Conecta |
| IP pública | 187.138.253.78 | 177.245.39.199 |

**Tipo de bloqueo:** TCP/HTTPS nivel de aplicación (DPI)
- ICMP no está bloqueado (ping funciona)
- Pero HTTPS a api.telegram.org está interceptado

## Implicaciones

### Causa probable
Telmex activó/mejoró su sistema DPI para detectar y bloquear:
- Telegram API (api.telegram.org)
- Probablemente otros servicios de mensajería/VPN

### Por qué afecta internet-detector
- internet-detector necesita Telegram para notificaciones
- Solución aplicada: rutear Telegram por lan1 (mod_telegram_iface='lan1')
- Esto evita pasar por el DPI de Telmex

## Escalation de Bloqueos ISP México

Este es un patrón en ISPs mexicanos (Telmex, Megacable):

| Servicio | Telmex | Megacable | Mitigation |
|----------|--------|-----------|-----------|
| Telegram | ✅ antes / ❌ ahora | ✅ | Ruta por Megacable |
| DNS externo (UDP) | ❌ | ✅ | usa NextDNS con bootstrap anycast |
| Algunos VPN | ❌ | ? | Ruantiblock (si se descarga) |

## Próximos pasos recomendados

1. **Monitorear** si otros servicios son bloqueados (VPN, DNS específicos, etc.)
2. **Usar Ruantiblock** cuando las listas se descarguen (puede evadir DPI)
3. **Documentar cambios** en bloqueos para ajustar routing

## Notas

- El bloqueo es **selectivo** (no bloquea ICMP, solo HTTPS)
- Sugiere que Telmex está usando **DPI avanzado** (inspección por aplicación)
- Es una escalation reciente, no un problema antiguo del router
