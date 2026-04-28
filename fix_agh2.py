#!/usr/bin/env python3
import paramiko

ROUTER_IP = '192.168.10.1'
USERNAME = 'root'
PASSWORD = 'admin'

print('=' * 70)
print('  DIAGNOSTICO Y CORRECCION ADGUARD HOME')
print('=' * 70)

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

try:
    print(f'\nConectando a {ROUTER_IP}...')
    ssh.connect(ROUTER_IP, username=USERNAME, password=PASSWORD, timeout=10)
    print('Conectado!\n')

    # 1. Verificar si AdGuardHome está corriendo
    print('=' * 60)
    print('1. Verificando proceso AdGuardHome...')
    print('=' * 60)
    stdin, stdout, stderr = ssh.exec_command('ps | grep -i adguard | grep -v grep')
    procs = stdout.read().decode().strip()
    if procs:
        print(f'Procesos encontrados:\n{procs}')
    else:
        print('ERROR: AdGuardHome NO está corriendo!')
    
    # Verificar puerto 53
    stdin, stdout, stderr = ssh.exec_command('netstat -ulnp | grep ":53 "')
    port53 = stdout.read().decode().strip()
    print(f'\nPuerto 53 (DNS):')
    print(port53 if port53 else 'Ningún servicio en puerto 53')
    
    # 2. Verificar logs recientes
    print('\n' + '=' * 60)
    print('2. Verificando logs de AdGuardHome...')
    print('=' * 60)
    stdin, stdout, stderr = ssh.exec_command('logread | grep -i adguard | tail -20')
    logs = stdout.read().decode().strip()
    print(logs if logs else 'No hay logs recientes de AdGuardHome')
    
    # Verificar error logs
    stdin, stdout, stderr = ssh.exec_command('cat /var/lib/adguardhome/data/querylog.json 2>/dev/null | head -5 || echo "No existe querylog.json"')
    print(f'\nQuerylog existe: {stdout.read().decode().strip()}')
    
    # 3. Verificar configuración
    print('\n' + '=' * 60)
    print('3. Verificando configuración...')
    print('=' * 60)
    stdin, stdout, stderr = ssh.exec_command('cat /etc/adguardhome/adguardhome.yaml | grep -E "port:|bind_host:|log_|- 127.0.0.1:53" | head -20')
    config = stdout.read().decode().strip()
    print('Configuración relevante:')
    print(config if config else 'No se pudo leer configuración')
    
    # 4. Verificar si hay errores al iniciar manualmente
    print('\n' + '=' * 60)
    print('4. Probando inicio manual de AdGuardHome...')
    print('=' * 60)
    stdin, stdout, stderr = ssh.exec_command('/usr/bin/AdGuardHome --help 2>&1 | head -5')
    help_out = stdout.read().decode().strip()
    print(f'AdGuardHome disponible: {"Sí" if help_out else "No"}')
    
    # 5. Verificar permisos del directorio
    print('\n' + '=' * 60)
    print('5. Verificando permisos...')
    print('=' * 60)
    stdin, stdout, stderr = ssh.exec_command('ls -la /etc/adguardhome/ && echo "---" && ls -la /usr/bin/AdGuardHome')
    perms = stdout.read().decode().strip()
    print(perms)
    
    # 6. CORRECCIONES
    print('\n' + '=' * 60)
    print('6. APLICANDO CORRECCIONES...')
    print('=' * 60)
    
    # Primero detener cualquier proceso zombie
    print('\n-> Deteniendo procesos anteriores...')
    stdin, stdout, stderr = ssh.exec_command('killall -9 AdGuardHome 2>/dev/null; sleep 1; echo "Procesos detenidos"')
    print(stdout.read().decode().strip())
    
    # Verificar que el directorio de trabajo existe y tiene permisos correctos
    print('\n-> Verificando directorios...')
    stdin, stdout, stderr = ssh.exec_command('mkdir -p /var/lib/adguardhome/data && chown -R adguardhome:adguardhome /var/lib/adguardhome && chmod 700 /var/lib/adguardhome && echo "OK"')
    print(stdout.read().decode().strip())
    
    stdin, stdout, stderr = ssh.exec_command('chown -R adguardhome:adguardhome /etc/adguardhome && chmod 700 /etc/adguardhome && echo "OK"')
    print(stdout.read().decode().strip())
    
    # Verificar si el puerto 53 está libre
    print('\n-> Verificando puerto 53...')
    stdin, stdout, stderr = ssh.exec_command('netstat -ulnp | grep ":53 " | grep -v AdGuard || echo "Puerto 53 disponible"')
    port_check = stdout.read().decode().strip()
    print(port_check)
    
    # Iniciar AdGuardHome
    print('\n-> Iniciando AdGuardHome...')
    stdin, stdout, stderr = ssh.exec_command('export HOME=/var/lib/adguardhome && cd /var/lib/adguardhome && su -s /bin/sh adguardhome -c "/usr/bin/AdGuardHome -c /etc/adguardhome/adguardhome.yaml -w /var/lib/adguardhome &" && sleep 2 && pidof AdGuardHome')
    pid = stdout.read().decode().strip()
    if pid:
        print(f'AdGuardHome iniciado con PID: {pid}')
        
        # Crear archivo PID
        stdin, stdout, stderr = ssh.exec_command(f'echo {pid} > /var/run/adguardhome.pid && chown adguardhome:adguardhome /var/run/adguardhome.pid')
        stdout.read()
        
        # Verificar que está escuchando en puerto 53
        stdin, stdout, stderr = ssh.exec_command('sleep 1 && netstat -ulnp | grep ":53 " | grep AdGuard')
        dns_port = stdout.read().decode().strip()
        if dns_port:
            print(f'\n✓ AdGuardHome escuchando en puerto 53:\n{dns_port}')
        else:
            print('\n✗ AdGuardHome NO está escuchando en puerto 53')
    else:
        print('ERROR: No se pudo iniciar AdGuardHome')
        stdin, stdout, stderr = ssh.exec_command('logread | tail -10')
        print(f'Logs recientes:\n{stdout.read().decode().strip()}')

    # 7. Verificación final
    print('\n' + '=' * 60)
    print('7. VERIFICACIÓN FINAL')
    print('=' * 60)
    stdin, stdout, stderr = ssh.exec_command('/etc/init.d/adguardhome status')
    print(f'Status: {stdout.read().decode().strip()}')
    
    stdin, stdout, stderr = ssh.exec_command('ps | grep AdGuard | grep -v grep')
    print(f'Proceso: {stdout.read().decode().strip()}')
    
    # Verificar que responde DNS
    print('\n-> Probando resolución DNS...')
    stdin, stdout, stderr = ssh.exec_command('nslookup google.com 127.0.0.1 2>&1 | head -5')
    dns_test = stdout.read().decode().strip()
    print(dns_test if dns_test else 'No hay respuesta DNS')

except Exception as e:
    print(f'ERROR: {e}')
    import traceback
    traceback.print_exc()
finally:
    ssh.close()
    print('\n' + '=' * 70)
    print('  COMPLETADO')
    print('=' * 70)