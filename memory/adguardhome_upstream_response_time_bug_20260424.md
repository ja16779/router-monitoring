---
name: AdGuardHome Upstream Response Time Bug
description: Bug conocido #6818 - métrica muestra valores 10x más altos y aumentan con el tiempo
type: project
date: 2026-04-24
originSessionId: a1292108-e8e8-414e-b3e2-08db0a2954fb
---
## Problema Identificado

**GitHub Issue:** [AdguardTeam/AdGuardHome#6818](https://github.com/AdguardTeam/AdGuardHome/issues/6818)

El "Average upstream response time" mostrado en AdGuardHome Dashboard es **INCORRECTO**:
- Muestra valores **10x más altos** que la latencia real
- **Aumenta progresivamente** con el tiempo
- NO refleja la performance actual del DNS

## Caso Observado (2026-04-24)

**Setup:** Flint-2 router con Unbound + AdGuardHome

| Métrica | Valor Reportado | Valor Real | Factor |
|---------|-----------------|-----------|--------|
| AGH Dashboard | 400ms+ | 0.24ms | 1,666x más alto |
| Tendencia | Aumentando | Estable | Bug de medición |

**Comando correcto para latencia real:**
```bash
unbound-control stats | grep "recursion.time.avg"
# thread1.recursion.time.avg=0.238171
```

## Causa

El problema está en cómo AdGuardHome **mide y acumula** los tiempos de respuesta:
1. Registra cada query/respuesta con timestamp
2. Calcula promedio de forma incorrecta (probablemente sin limpiar datos antiguos)
3. Los valores se degradan con el tiempo

## Impacto

- ❌ Dashboard metrics NO CONFIABLES
- ❌ No se puede diagnosticar latencia desde AGH UI
- ✅ La latencia REAL sigue siendo correcta (el DNS funciona bien)
- ✅ Solo afecta la presentación/medición, no el servicio

## Solución Workaround

### Opción 1: Ignorar la Métrica (Recomendado)
- No usar el Dashboard para evaluar latencia
- Usar `unbound-control stats` para latencia real
- La latencia real del DNS es excelente (~0.24ms)

### Opción 2: Limpiar Estadísticas (Temporal)
```bash
/etc/init.d/adguardhome stop
rm -f /var/lib/adguardhome/stats*
/etc/init.d/adguardhome start
```
- Resetea el dashboard
- Métrica vuelve a mostrar valores correctos por ~30 min
- Luego vuelve a degradarse

### Opción 3: Esperar Fix en AdGuardHome
- Actualizar a versión con bug arreglado cuando esté disponible
- Actualmente sin fix en versión estable (0.107.74)

## Verificación de Latencia Real

**Comando confiable:**
```bash
unbound-control stats | grep -E "thread.*recursion.time.avg|total.recursion.time.avg"

# Salida esperada:
# thread0.recursion.time.avg=0.332825
# thread1.recursion.time.avg=0.238171
# thread2.recursion.time.avg=0.306709
# thread3.recursion.time.avg=0.336880
# total.recursion.time.avg=0.328464
```

**Interpretación:**
- < 1ms = Excelente ✅
- 1-5ms = Muy bueno ✅
- 5-10ms = Bueno ✅
- > 50ms = Problema ❌

En este caso: **0.24-0.33ms = EXCELENTE** ✅

## Notas

- Bug es conocido y reportado en GitHub
- Afecta a múltiples versiones de AdGuardHome
- Es un problema de software, no de hardware/red
- La funcionalidad DNS NO está afectada
- Solo la métrica de presentación es incorrecta

---

**Conclusión:** El DNS en Flint-2 está optimizado y funcionando perfectamente. Ignorar el dashboard de AdGuardHome para métricas de latencia.
