# Guía de Configuración: Impresión LAN → IOT (Flint-2)

## 📋 Resumen del Problema

- **Red LAN**: 192.168.10.x (clientes/computadoras)
- **Red IOT**: 192.168.8.x (impresora Samsung)
- **Problema**: No se puede imprimir desde LAN hacia IOT
- **Causa**: Firewall bloquea el tráfico entre VLANs

---

## 🚀 Solución Rápida (Script Automático)

### 1. Copiar el script al router

Desde tu PC (en el mismo directorio donde está el script):

```bash
# Usando scp (Linux/Mac/Git Bash)
scp iot_printer_access.sh root@192.168.10.1:/tmp/

# O copiar manualmente a través de SCP/WinSCP
```

### 2. Ejecutar en el router

```bash
# Conectar al router
ssh root@192.168.10.1

# Ir al directorio temporal
cd /tmp

# Hacer ejecutable el script
chmod +x iot_printer_access.sh

# Ver configuración propuesta
./iot_printer_access.sh

# Aplicar reglas
./iot_printer_access.sh aplicar
```

### 3. Comandos útiles del script

| Comando | Descripción |
|---------|-------------|
| `./iot_printer_access.sh` | Ver configuración propuesta |
| `./iot_printer_access.sh aplicar` | Aplicar reglas de firewall |
| `./iot_printer_access.sh revertir` | Eliminar reglas |
| `./iot_printer_access.sh status` | Ver estado actual |

---

## 🖥️ Configuración Manual (LuCI Web Interface)

Si prefieres configurar manualmente desde la interfaz web:

### Paso 1: Acceder a LuCI
1. Abre navegador → `http://192.168.10.1`
2. Inicia sesión
3. Ve a **Network → Firewall**

### Paso 2: Configurar Zona LAN/IOT

Busca la zona `lan` y verifica:
- ✅ **Input**: Accept
- ✅ **Output**: Accept
- ✅ **Forward**: Accept
- ✅ **Covered Networks**: lan, IOT

Si `Forward` está en `REJECT`, cámbialo a `ACCEPT`.

### Paso 3: Crear Reglas de Tráfico

Ve a **Network → Firewall → Traffic Rules** y haz clic en **Add**

#### Regla 1: Impresión TCP
```
Name: Allow-LAN-to-IOT-Printer-TCP
Source zone: lan
Destination zone: iot
Protocol: TCP
Destination ports: 9100, 515, 631, 445, 139, 80, 443
Action: accept
```

#### Regla 2: Descubrimiento UDP
```
Name: Allow-LAN-to-IOT-Printer-UDP
Source zone: lan
Destination zone: iot
Protocol: UDP
Destination ports: 161, 162, 137, 138, 5353, 427
Action: accept
```

#### Regla 3: Ping/ICMP (opcional pero recomendado)
```
Name: Allow-LAN-to-IOT-ICMP
Source zone: lan
Destination zone: iot
Protocol: ICMP
Action: accept
```

### Paso 4: Guardar y Aplicar
Haz clic en **Save & Apply**

---

## 🔍 Diagnóstico y Verificación

### 1. Verificar conectividad básica

Desde un cliente en LAN (192.168.10.x):

```bash
# Ping a la IP de la impresora (cambia 192.168.8.xxx por tu IP)
ping 192.168.8.xxx

# Verificar puertos de impresión
nc -zv 192.168.8.xxx 9100    # RAW/JetDirect
nc -zv 192.168.8.xxx 631     # IPP
nc -zv 192.168.8.xxx 445     # SMB
```

### 2. Verificar reglas en el router

Conecta al router por SSH y ejecuta:

```bash
# Ver reglas de firewall
iptables -L -n | grep -E "(9100|515|631|Allow-LAN)"

# Ver configuración UCI
uci show firewall | grep -A5 "Allow-LAN-to-IOT"

# Ver conexiones activas
cat /proc/net/nf_conntrack | grep 192.168.8
```

### 3. Probar impresión

**Windows:**
1. Configurar impresora con IP: `192.168.8.xxx`
2. Puerto: `9100` (RAW) o `631` (IPP)
3. Probar página de prueba

**Linux:**
```bash
# Agregar impresora con IPP
lpadmin -p Samsung-IOT -E -v ipp://192.168.8.xxx/ipp -m everywhere

# O con JetDirect
lpadmin -p Samsung-RAW -E -v socket://192.168.8.xxx:9100 -m raw
```

---

## 🛠️ Solución de Problemas

### Problema: No hay ping a la impresora

**Verificar:**
```bash
# En el router
iptables -L FORWARD -n -v | head -20
```

**Solución:**
- Verificar que la impresora tenga IP correcta
- Verificar que esté encendida y conectada
- Verificar reglas de firewall

### Problema: Ping OK pero no imprime

**Verificar puertos:**
```bash
# Desde un PC en LAN
nmap -p 9100,515,631,445,139 192.168.8.xxx
```

**Posibles causas:**
- Puerto incorrecto configurado
- Servicio de impresión no iniciado en la impresora
- Firewall de la impresora bloqueando

### Problema: Descubrimiento automático no funciona

**Solución:**
Los protocolos de descubrimiento (mDNS/Bonjour) usan multicast y no cruzan VLANs fácilmente.

**Opciones:**
1. Configurar impresora manualmente con IP estática
2. Usar **avahi-reflector** o **mdns-repeater** en el router
3. Instalar paquete `avahi-daemon` en OpenWrt:

```bash
# Instalar reflector mdns
opkg update
opkg install avahi-daemon

# Configurar para reenviar entre lan e iot
uci set avahi-daemon.@reflector[0].enabled=1
uci commit avahi-daemon
/etc/init.d/avahi-daemon restart
```

---

## 📊 Puertos de Impresión por Protocolo

| Puerto | Protocolo | Uso |
|--------|-----------|-----|
| 9100 | RAW/JetDirect | Impresión directa HP, Samsung, etc. |
| 515 | LPD/LPR | Line Printer Daemon (Unix/Linux) |
| 631 | IPP | Internet Printing Protocol (moderno) |
| 445 | SMB/CIFS | Compartir impresora Windows |
| 139 | NetBIOS | Windows legacy |
| 137/138 | NetBIOS | Nombre/discovery Windows |
| 161/162 | SNMP | Descubrimiento y monitoreo |
| 5353 | mDNS | Bonjour/Avahi discovery |
| 80/443 | HTTP/HTTPS | Web interface de impresora |

---

## 🔐 Consideraciones de Seguridad

⚠️ **Advertencia**: Permitir acceso de LAN a IOT abre la red IOT.

**Recomendaciones:**
1. Usar solo los puertos necesarios para tu impresora
2. Configurar IP estática para la impresora
3. Crear reglas más específicas (por IP de origen/destino)
4. Monitorear conexiones sospechosas

**Regla más restrictiva (por IP específica):**
```bash
# Solo permite desde IP específica de la impresora
uci add firewall rule
uci set firewall.@rule[-1].name="Allow-LAN-to-Printer-Only"
uci set firewall.@rule[-1].src="lan"
uci set firewall.@rule[-1].dest="iot"
uci set firewall.@rule[-1].dest_ip="192.168.8.xxx"  # IP de tu impresora
uci set firewall.@rule[-1].proto="tcp"
uci set firewall.@rule[-1].dest_port="9100"
uci set firewall.@rule[-1].target="ACCEPT"
uci commit firewall
```

---

## 📞 Comandos Útiles para Debug

```bash
# Ver logs de firewall en tiempo real
logread -f | grep -i firewall

# Ver intentos de conexión bloqueados
logread | grep -i "DROP\|REJECT"

# Reiniciar firewall
/etc/init.d/firewall restart

# Ver configuración completa
uci show firewall

# Ver estadísticas de iptables
iptables -L -v -n
```

---

## ✅ Checklist Final

Después de aplicar la configuración:

- [ ] Ping desde LAN a impresora funciona
- [ ] Puerto 9100 (o el que uses) responde
- [ ] Impresora aparece en configuración del sistema operativo
- [ ] Página de prueba se imprime correctamente
- [ ] No hay errores en logs del router

---

**Nota**: Si la impresora Samsung usa algún protocolo específico adicional, consulta el manual para verificar los puertos requeridos.