# Limitaciones de ash/BusyBox en OpenWrt

**Type:** feedback
**Description:** Restricciones conocidas del shell ash en OpenWrt 25.12

---

## Limitaciones conocidas

- `!` para negar comandos en `if ! cmd` puede fallar en algunos contextos de ash. Usar `cmd; if [ $? -ne 0 ]` en su lugar.

- `awk` con single quotes dentro de comandos SSH complejos falla por escaping. Escribir scripts a archivo y ejecutarlos, no inline.

- `cat -A` no existe en BusyBox. Usar `sed -n 'p'` o simplemente `cat`.

- `ss` no existe; usar `netstat`.

- `nl` no existe.

- BusyBox ssh client (en Flint-2) falla al ejecutar comandos remotos en Beryl con "Connection exited: Interrupted". Usar ProxyJump desde la PC local.

- Interfaces WiFi en Beryl AX usan nombres wlan0/wlan1, no phy*-ap* como el Flint-2.
