---
name: MWAN3 "disconnecting" infinito — Fix keepalive vestigial (2026-07-06)
description: network.wan.keepalive '10 6' (residuo de PPPoE) causaba que netifd reiniciara udhcpc cada ~1.5-2.5 min durante cortes de Telmex, reseteando el score de mwan3 a "online" en cada ciclo y evitando que la interfaz se estabilizara en "offline". Eliminado.
type: project
---
## Síntoma reportado por el usuario

Con Telmex caído, `mwan3 status` mostraba la interfaz `wan` permanentemente en
"disconnecting" / "tracking is active", sin pasar nunca a "offline" de forma estable.
El usuario deshabilitó `wan` manualmente como mitigación.

## Root cause (confirmado vía logs, no hipótesis)

`network.wan` tenía `option keepalive '10 6'` — parámetro heredado de una config PPPoE
anterior (ver [[network_topology]], memoria de 2026 muestra wan como PPPoE en su momento).
Nunca se limpió al migrar wan a `proto dhcp`. `secondwan` (Megacable) NO tiene este
parámetro y por eso nunca mostró el mismo problema — comparación que confirmó la causa
(Fase 2 de systematic-debugging).

Mecanismo exacto observado en logread:
1. netifd hace su propia sonda de keepalive (independiente de mwan3) hacia el gateway.
2. Al fallar (sin salida real a internet), netifd mata udhcpc: `netifd: wan (PID):
   udhcpc: received SIGTERM` — esto lo hace netifd mismo, no un script custom ni mwan3.
3. El módem de Telmex (192.168.1.254) sigue vivo y responde DHCP localmente aunque no
   haya internet aguas arriba → udhcpc consigue lease nuevo en ~3s → netifd marca
   `Interface 'wan' is now up`.
4. mwan3track trata cualquier ifup detectado como señal de reconexión y resetea su
   score a "online" desde cero (comportamiento normal de mwan3, no bug de mwan3).
5. El contador de mwan3 tarda ~2 min en volver a caer a "offline" (down=5, up=5,
   ver [[mwan3_configuration_20260427]]), pero el keepalive vuelve a matar udhcpc antes
   de que se estabilice → vuelve al paso 1.
6. Resultado: la interfaz pasa la mayoría del tiempo en "disconnecting" y solo 1-2s en
   "offline" antes de rebotar — de ahí la percepción de "nunca llega a offline".

Efecto colateral detectado: Tailscale (`tailscaled`) se reiniciaba completo en cada
ciclo (kill + restart del proceso), desperdiciando recursos y generando ruido en logs
durante todo el corte.

## Fix aplicado

```
uci delete network.wan.keepalive
uci commit network
```

Aplicado con `wan` ya deshabilitada por el usuario (sin interrupción). Verificado en
`/etc/config/network` que la sección `wan` ya no tiene `option keepalive`.
`secondwan` nunca tuvo este parámetro — no requiere cambios.

## Lección para próxima auditoría

Al migrar una interfaz de PPPoE → DHCP (o viceversa), revisar y limpiar parámetros
específicos de protocolo que no apliquen al nuevo proto (`keepalive`, `pppoe`-specific
options, etc.) — quedarse un parámetro vestigial puede interactuar mal con mwan3 y
generar bucles de reinicio silenciosos, difíciles de diagnosticar sin leer logread
línea por línea durante una caída real.
