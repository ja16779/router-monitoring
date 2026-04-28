#!/usr/bin/env python3
import paramiko

ROUTER_IP = '192.168.10.1'
USERNAME = 'root'
PASSWORD = 'admin'

print('=' * 70)
print('  CORRECCION FINAL ADGUARD HOME')
print('=' * 70)

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

try:
    print(f'\nConectando a {ROUTER_IP}...')
    ssh.connect(ROUTER_IP, username=USERNAME, password=PASSWORD, timeout=10)
    print('Conectado!\n')

    # 1. Limpiar configuración duplicada de dnsmasq
    print('=' * 60)
    print('1. Limpiando configuración de dnsmasq...')
    print('=' * 60)
    stdin, stdout, stderr = ssh.exec_command('uci del_list dhcp.@dnsmasq[0].server && uci commit dhcp && echo "Limpieza completada"')
    print(stdout.read().decode().strip())
    
    # Agregar solo una vez
    stdin, stdout, stderr = ssh.exec_command('uci add_list dhcp.@dnsmasq[0].server=127.0.0.1#3053 && uci commit dhcp')
    stdout.read()
    
    stdin, stdout, stderr = ssh.exec_command('uci show dhcp | grep server')
    print(f'Configuración final:\n{stdout.read().decode().strip()}')

    # 2. Verificar configuración de AdGuardHome
    print('\n' + '=' * 60)
    print('2. Verificando configuración de AdGuardHome...')
    print('=' * 60)
    
    stdin, stdout, stderr = ssh.exec_command('cat /etc/adguardhome/adguardhome.yaml')
    config = stdout.read().decode()
    
    # Verificar puerto DNS
    import re
    dns_port = re.search(r'^dns:.*?port:\s*(\d+)', config, re.MULTILINE | re.DOTALL)
    if dns_port:
        print(f'Puerto DNS configurado: {dns_port.group(1)}')
    
    # Verificar querylog
    querylog = re.search(r'^querylog:.*?dir_path:\s*(\S*)', config, re.MULTILINE | re.DOTALL)
    if querylog:
        dir_path = querylog.group(1)
        print(f'Querylog dir_path: "{dir_path}"')
        
        # Corregir si está vacío
        if dir_path == '""' or dir_path == '':
            print('Corregir dir_path del querylog...')
            # Establecer ruta correcta
            new_config = re.sub(
                r'(querylog:.*?dir_path:\s*)""',
                r'\g<1>"/var/lib/adguardhome/data/querylog"',
                config,
                flags=re.MULTILINE | re.DOTALL
            )
            stdin, stdout, stderr = ssh.exec_command("cat > /etc/adguardhome/adguardhome.yaml << 'EOF'\n" + new_config + "\nEOF")
            stdout.read()
            print('Configuración actualizada')

    # 3. Verificar y corregir permisos
    print('\n' + '=' * 60)
    print('3. Verificando permisos...')
    print('=' * 60)
    
    stdin, stdout, stderr = ssh.exec_command('chown -R adguardhome:adguardhome /var/lib/adguardhome && echo "Permisos corregidos"')
    print(stdout.read().decode().strip())
    
    stdin, stdout, stderr = ssh.exec_command('ls -la /etc/adguardhome/ /var/lib/adguardhome/data/')
    print(f'Permisos:\n{stdout.read().decode().strip()}')

    # 4. Detener procesos previos
    print('\n' + '=' * 60)
    print('4. Deteniendo procesos previos...')
    print('=' * 60)
    stdin, stdout, stderr = ssh.exec_command('killall AdGuardHome 2>/dev/null; sleep 2; echo "Procesos detenidos"')
    print(stdout.read().decode().strip())

    # 5. Iniciar AdGuardHome manualmente para ver errores
    print('\n' + '=' * 60)
    print('5. Iniciando AdGuardHome (modo debug)...')
    print('=' * 60)
    
    stdin, stdout, stderr = ssh.exec_command('/usr/bin/AdGuardHome -c /etc/adguardhome/adguardhome.yaml -w /var/lib/adguardhome &')
    # Esperar un momento
    import time
    time.sleep(3)
    
    # Verificar si está corriendo
    stdin, stdout, stderr = ssh.exec_command('netstat -ulnp | grep ":3053"')
    port_check = stdout.read().decode().strip()
    if port_check:
        print(f'✓ AdGuardHome corriendo:\n{port_check}')
    else:
        print('✗ AdGuardHome NO inició')
        # Ver logs
        stdin, stdout, stderr = ssh.exec_command('logread | grep -i adguard | tail -10')
        print(f'Logs de error:\n{stdout.read().decode().strip()}')

    # 6. Reiniciar dnsmasq
    print('\n' + '=' * 60)
    print('6. Reiniciando dnsmasq...')
    print('=' * 60)
    stdin, stdout, stderr = ssh.exec_command('/etc/init.d/dnsmasq restart && sleep 2 && echo "dnsmasq reiniciado"')
    print(stdout.read().decode().strip())

    # 7. Verificación final
    print('\n' + '=' * 60)
    print('7. VERIFICACIÓN FINAL')
    print('=' * 60)
    
    stdin, stdout, stderr = ssh.exec_command('netstat -ulnp | grep -E ":53 |:3053"')
    ports = stdout.read().decode().strip()
    print(f'Puertos DNS:\n{ports}')
    
    stdin, stdout, stderr = ssh.exec_command('nslookup google.com 127.0.0.1 2>&1 | head -4')
    dns_test = stdout.read().decode().strip()
    print(f'\nTest DNS:\n{dns_test}')
    
    stdin, stdout, stderr = ssh.exec_command('ls -la /var/lib/adguardhome/data/querylog/ 2>/dev/null | head -5')
    querylog_files = stdout.read().decode().strip()
    print(f'\nArchivos de querylog:\n{querylog_files if querylog_files else "Vacío"}')

except Exception as e:
    print(f'ERROR: {e}')
    import traceback
    traceback.print_exc()
finally:
    ssh.close()
    print('\n' + '=' * 70)
    print('  COMPLETADO')
    print('=' * 70)