#!/usr/bin/env python3
import paramiko

ROUTER_IP = '192.168.10.1'
USERNAME = 'root'
PASSWORD = 'admin'

print('=' * 70)
print('  CORRECCION DNS FORWARD A ADGUARDHOME (PUERTO 3053)')
print('=' * 70)

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

try:
    print(f'\nConectando a {ROUTER_IP}...')
    ssh.connect(ROUTER_IP, username=USERNAME, password=PASSWORD, timeout=10)
    print('Conectado!\n')

    # 1. Verificar estado actual
    print('=' * 60)
    print('1. Estado actual del DNS...')
    print('=' * 60)
    stdin, stdout, stderr = ssh.exec_command('netstat -ulnp | grep -E ":53 |:3053"')
    dns_ports = stdout.read().decode().strip()
    print('Puertos DNS:')
    print(dns_ports if dns_ports else 'No se encontraron servicios')

    # 2. Verificar configuración de dnsmasq
    print('\n' + '=' * 60)
    print('2. Configuración actual de dnsmasq...')
    print('=' * 60)
    
    stdin, stdout, stderr = ssh.exec_command('uci show dhcp | grep -E "server|noresolv|port"')
    dhcp_config = stdout.read().decode().strip()
    print('Configuración dhcp/dnsmasq:')
    print(dhcp_config if dhcp_config else 'No hay configuración personalizada')
    
    # Verificar /etc/resolv.conf
    stdin, stdout, stderr = ssh.exec_command('cat /etc/resolv.conf')
    resolv_conf = stdout.read().decode().strip()
    print(f'\n/etc/resolv.conf:\n{resolv_conf}')

    # 3. Configurar forward a AdGuardHome
    print('\n' + '=' * 60)
    print('3. Configurando dnsmasq para forward a AdGuardHome...')
    print('=' * 60)
    
    # Eliminar servidores DNS anteriores de dnsmasq
    stdin, stdout, stderr = ssh.exec_command('uci del_list dhcp.@dnsmasq[0].server 2>/dev/null; echo "OK"')
    print(f'Eliminar servers anteriores: {stdout.read().decode().strip()}')
    
    # Agregar forward a AdGuardHome en puerto 3053
    stdin, stdout, stderr = ssh.exec_command('uci add_list dhcp.@dnsmasq[0].server=127.0.0.1#3053')
    stdout.read()
    
    # Deshabilitar resolv.conf automático
    stdin, stdout, stderr = ssh.exec_command('uci set dhcp.@dnsmasq[0].noresolv=1')
    stdout.read()
    
    # Aplicar cambios
    stdin, stdout, stderr = ssh.exec_command('uci commit dhcp')
    stdout.read()
    
    # Verificar configuración aplicada
    stdin, stdout, stderr = ssh.exec_command('uci show dhcp | grep -E "server|noresolv"')
    applied = stdout.read().decode().strip()
    print(f'Configuración aplicada:\n{applied}')

    # 4. Reiniciar dnsmasq
    print('\n' + '=' * 60)
    print('4. Reiniciando dnsmasq...')
    print('=' * 60)
    stdin, stdout, stderr = ssh.exec_command('/etc/init.d/dnsmasq restart && sleep 2 && echo "dnsmasq reiniciado"')
    print(stdout.read().decode().strip())

    # 5. Verificar que AdGuardHome está corriendo en 3053
    print('\n' + '=' * 60)
    print('5. Verificando AdGuardHome...')
    print('=' * 60)
    
    stdin, stdout, stderr = ssh.exec_command('netstat -ulnp | grep ":3053"')
    agh_port = stdout.read().decode().strip()
    if agh_port:
        print(f'✓ AdGuardHome en puerto 3053:\n{agh_port}')
    else:
        print('✗ AdGuardHome NO está en puerto 3053')
        print('Iniciando AdGuardHome...')
        stdin, stdout, stderr = ssh.exec_command('/etc/init.d/adguardhome restart && sleep 2')
        stdout.read()
        
        stdin, stdout, stderr = ssh.exec_command('netstat -ulnp | grep ":3053"')
        agh_check = stdout.read().decode().strip()
        if agh_check:
            print(f'✓ AdGuardHome iniciado: {agh_check}')

    # 6. Verificar querylog de AdGuardHome
    print('\n' + '=' * 60)
    print('6. Verificando querylog de AdGuardHome...')
    print('=' * 60)
    
    # Verificar que querylog está habilitado
    stdin, stdout, stderr = ssh.exec_command('cat /etc/adguardhome/adguardhome.yaml | grep -A3 "querylog:"')
    querylog_config = stdout.read().decode().strip()
    print(f'Configuración querylog:\n{querylog_config}')
    
    # Verificar directorio de querylog
    stdin, stdout, stderr = ssh.exec_command('ls -la /var/lib/adguardhome/data/ 2>/dev/null || echo "Directorio no existe"')
    data_dir = stdout.read().decode().strip()
    print(f'\nDirectorio de datos:\n{data_dir}')
    
    # Verificar si hay archivos de querylog
    stdin, stdout, stderr = ssh.exec_command('find /var/lib/adguardhome -name "*querylog*" -o -name "*.json" 2>/dev/null | head -5')
    querylog_files = stdout.read().decode().strip()
    print(f'\nArchivos de log encontrados:\n{querylog_files if querylog_files else "Ninguno"}')

    # 7. Test DNS para verificar que funciona
    print('\n' + '=' * 60)
    print('7. Test DNS...')
    print('=' * 60)
    
    stdin, stdout, stderr = ssh.exec_command('nslookup google.com 127.0.0.1 2>&1 | head -4')
    dns_test = stdout.read().decode().strip()
    print(f'Test DNS local:\n{dns_test}')
    
    # Ver logs recientes de AdGuardHome
    stdin, stdout, stderr = ssh.exec_command('logread | grep -i adguard | tail -5')
    logs = stdout.read().decode().strip()
    print(f'\nLogs recientes:\n{logs if logs else "No hay logs"}')

    # 8. Habilitar inicio automático de AdGuardHome
    print('\n' + '=' * 60)
    print('8. Habilitando inicio automático...')
    print('=' * 60)
    stdin, stdout, stderr = ssh.exec_command('/etc/init.d/adguardhome enable && echo "AdGuardHome habilitado"')
    print(stdout.read().decode().strip())

except Exception as e:
    print(f'ERROR: {e}')
    import traceback
    traceback.print_exc()
finally:
    ssh.close()
    print('\n' + '=' * 70)
    print('  COMPLETADO')
    print('=' * 70)