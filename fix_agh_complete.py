#!/usr/bin/env python3
import paramiko
import time

ROUTER_IP = '192.168.10.1'
USERNAME = 'root'
PASSWORD = 'admin'

print('=' * 70)
print('  CORRECCION COMPLETA ADGUARD HOME')
print('=' * 70)

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

try:
    print(f'\nConectando a {ROUTER_IP}...')
    ssh.connect(ROUTER_IP, username=USERNAME, password=PASSWORD, timeout=10)
    print('Conectado!\n')

    # 1. LIMPIAR configuración dnsmasq completamente
    print('=' * 60)
    print('1. LIMPIANDO configuración dnsmasq...')
    print('=' * 60)
    
    # Eliminar TODOS los server entries
    stdin, stdout, stderr = ssh.exec_command('uci delete dhcp.@dnsmasq[0].server 2>/dev/null; echo "deleted"')
    stdout.read()
    
    # Agregar uno nuevo
    stdin, stdout, stderr = ssh.exec_command('uci set dhcp.@dnsmasq[0].server=127.0.0.1#3053 && uci commit dhcp')
    stdout.read()
    
    stdin, stdout, stderr = ssh.exec_command('uci show dhcp | grep server')
    print(f'Configuración limpia:\n{stdout.read().decode().strip()}')

    # 2. ARREGLAR configuración YAML de AdGuardHome
    print('\n' + '=' * 60)
    print('2. Arreglando configuración AdGuardHome...')
    print('=' * 60)
    
    # Leer configuración actual
    stdin, stdout, stderr = ssh.exec_command('cat /etc/adguardhome/adguardhome.yaml')
    config = stdout.read().decode()
    
    # Reemplazar dir_path vacío con ruta correcta
    import re
    new_config = re.sub(
        r'dir_path:\s*""+',
        'dir_path: "/var/lib/adguardhome/data/querylog"',
        config
    )
    
    # Asegurar que querylog está habilitado
    new_config = re.sub(
        r'enabled:\s*false',
        'enabled: true',
        new_config
    )
    
    # Verificar puerto DNS
    if 'port: 3053' not in new_config:
        new_config = re.sub(
            r'port:\s*\d+',
            'port: 3053',
            new_config
        )
    
    # Guardar nueva configuración
    stdin, stdout, stderr = ssh.exec_command("cat > /etc/adguardhome/adguardhome.yaml << 'EOF'\n" + new_config + "\nEOF")
    stdout.read()
    
    # Verificar cambios
    stdin, stdout, stderr = ssh.exec_command('grep -A2 "querylog:" /etc/adguardhome/adguardhome.yaml')
    print(f'Querylog config:\n{stdout.read().decode().strip()}')
    
    stdin, stdout, stderr = ssh.exec_command('grep "port:" /etc/adguardhome/adguardhome.yaml | head -1')
    print(f'Puerto DNS: {stdout.read().decode().strip()}')

    # 3. CORREGIR PERMISOS
    print('\n' + '=' * 60)
    print('3. Corrigiendo permisos...')
    print('=' * 60)
    
    cmds = [
        'chown -R adguardhome:adguardhome /var/lib/adguardhome',
        'chown -R adguardhome:adguardhome /etc/adguardhome',
        'chmod 750 /var/lib/adguardhome',
        'chmod 750 /etc/adguardhome',
        'chmod 644 /etc/adguardhome/adguardhome.yaml',
        'chmod 755 /usr/bin/AdGuardHome',
    ]
    for cmd in cmds:
        stdin, stdout, stderr = ssh.exec_command(cmd)
        stdout.read()
    print('Permisos corregidos')

    # 4. Crear directorios necesarios
    print('\n' + '=' * 60)
    print('4. Creando directorios...')
    print('=' * 60)
    
    cmds = [
        'mkdir -p /var/lib/adguardhome/data/querylog',
        'chown adguardhome:adguardhome /var/lib/adguardhome/data/querylog',
        'chmod 755 /var/lib/adguardhome/data/querylog',
    ]
    for cmd in cmds:
        stdin, stdout, stderr = ssh.exec_command(cmd)
        stdout.read()
    
    stdin, stdout, stderr = ssh.exec_command('ls -la /var/lib/adguardhome/data/querylog/')
    print(stdout.read().decode().strip())

    # 5. DETENER y REINICIAR AdGuardHome correctamente
    print('\n' + '=' * 60)
    print('5. Reiniciando AdGuardHome...')
    print('=' * 60)
    
    # Detener todo
    stdin, stdout, stderr = ssh.exec_command('/etc/init.d/adguardhome stop 2>/dev/null; killall AdGuardHome 2>/dev/null; sleep 3')
    stdout.read()
    print('AdGuardHome detenido')
    
    # Limpiar archivo PID si existe
    stdin, stdout, stderr = ssh.exec_command('rm -f /var/run/adguardhome.pid')
    stdout.read()
    
    # Iniciar con init.d
    stdin, stdout, stderr = ssh.exec_command('/etc/init.d/adguardhome start')
    time.sleep(5)
    
    # Verificar
    stdin, stdout, stderr = ssh.exec_command('netstat -ulnp | grep ":3053"')
    port_check = stdout.read().decode().strip()
    if port_check:
        print(f'✓ AdGuardHome corriendo:\n{port_check}')
    else:
        print('✗ AdGuardHome NO inició')
        # Ver error detallado
        stdin, stdout, stderr = ssh.exec_command('logread | grep -i adguard | tail -15')
        print(f'Logs recientes:\n{stdout.read().decode().strip()}')
        
        # Intentar iniciar manualmente para ver error
        stdin, stdout, stderr = ssh.exec_command('/usr/bin/AdGuardHome -c /etc/adguardhome/adguardhome.yaml -w /var/lib/adguardhome 2>&1 &')
        time.sleep(3)
        stdin, stdout, stderr = ssh.exec_command('netstat -ulnp | grep ":3053"')
        if stdout.read().decode().strip():
            print('✓ AdGuardHome iniciado manualmente')
        else:
            print('✗ Falló también inicio manual')

    # 6. Reiniciar dnsmasq
    print('\n' + '=' * 60)
    print('6. Reiniciando dnsmasq...')
    print('=' * 60)
    stdin, stdout, stderr = ssh.exec_command('/etc/init.d/dnsmasq restart && sleep 2')
    stdout.read()
    print('dnsmasq reiniciado')

    # 7. VERIFICACIÓN FINAL
    print('\n' + '=' * 60)
    print('7. VERIFICACIÓN FINAL')
    print('=' * 60)
    
    stdin, stdout, stderr = ssh.exec_command('netstat -ulnp | grep -E ":53 |:3053"')
    ports = stdout.read().decode().strip()
    print(f'Puertos activos:\n{ports}\n')
    
    stdin, stdout, stderr = ssh.exec_command('nslookup google.com 127.0.0.1 2>&1 | head -5')
    dns_test = stdout.read().decode().strip()
    print(f'Test DNS local:\n{dns_test}\n')
    
    stdin, stdout, stderr = ssh.exec_command('nslookup google.com 127.0.0.1#3053 2>&1 | head -5')
    agh_test = stdout.read().decode().strip()
    print(f'Test DNS a AdGuardHome (3053):\n{agh_test}\n')
    
    stdin, stdout, stderr = ssh.exec_command('ls -la /var/lib/adguardhome/data/querylog/ 2>/dev/null')
    logs = stdout.read().decode().strip()
    print(f'Querylog files:\n{logs if logs else "No hay archivos"}\n')
    
    stdin, stdout, stderr = ssh.exec_command('pgrep -a AdGuardHome')
    process = stdout.read().decode().strip()
    print(f'Proceso AdGuardHome:\n{process if process else "No corriendo"}')

except Exception as e:
    print(f'ERROR: {e}')
    import traceback
    traceback.print_exc()
finally:
    ssh.close()
    print('\n' + '=' * 70)
    print('  PROCESO COMPLETADO')
    print('=' * 70)