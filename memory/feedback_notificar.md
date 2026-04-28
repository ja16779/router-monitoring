# notificar.sh no soporta mensajes multilinea

**Type:** feedback
**Description:** notificar.sh usa -d en curl (no --data-urlencode), rompe mensajes con saltos de línea

---

`notificar.sh` usa `curl -d "text=${MENSAJE}"` que NO codifica saltos de línea.

Los mensajes con newlines fallan silenciosamente: curl retorna ok:true pero Telegram no los recibe correctamente.

**Solución:** Para scripts con mensajes multilinea, usar curl directo con `--data-urlencode` como en `onhostchange.sh`.

Ver `wa850_monitor.sh` como ejemplo correcto de manejo de mensajes multilinea.
