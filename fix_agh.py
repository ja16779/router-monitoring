#!/usr/bin/env python3
import paramiko

ROUTER_IP = '192.168.10.1'
USERNAME = 'root'
PASSWORD = 'admin'

print('=' * 70)
print('  CORRECCIONES ADGUARD HOME')
print('=' * 70)

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

try:
    print(f'\nConectando a {ROUTER_IP}...')
    ssh.connect(ROUTER_IP, username=USERNAME, password=PASSWORD, timeout=10)
    print('Conectado!\n')

    # 1. Verificar qué hay en el puerto 5335 (upstream)
    print('=' * 60)
    print('1. Verificando upstream DNS (puerto 5335)...')
    print('=' * 60)
    stdin, stdout, stderr = ssh.exec_command('netstat -ulnp 2>/dev/null | grep ":5335" || echo "No hay servicio en 5335"')
    print(stdout.read().decode().strip())
    
    # Verificar si hay unbound o dnsproxy
    stdin, stdout, stderr = ssh.exec_command('pidof unbound; pidof dnsproxy; pidof dnscrypt-proxy')
    pids = stdout.read().decode().strip()
    print(f'PIDs encontrados: {pids if pids else "Ninguno"}')
    
    # Verificar config de upstreams
    stdin, stdout, stderr = ssh.exec_command('cat /etc/adguardhome/adguardhome.yaml | grep -A20 "upstream_dns:"')
    print('\nUpstream configurados:')
    print(stdout.read().decode().strip())
    
    # 2. Verificar init script
    print('\n' + '=' * 60)
    print('2. Analizando init script de adguardhome...')
    print('=' * 60)
    stdin, stdout, stderr = ssh.exec_command('cat /etc/init.d/adguardhome | head -60')
    print(stdout.read().decode().strip())
    
    # 3. Verificar archivo de PID
    print('\n' + '=' * 60)
    print('3. Verificando archivo de PID...')
    print('=' * 60)
    stdin, stdout, stderr = ssh.exec_command('ls -la /var/run/adguardhome.pid 2>/dev/null || echo "No existe /var/run/adguardhome.pid"')
    print(stdout.read().decode().strip())
    
    # Verificar si hay archivo PID en otra ubicación
    stdin, stdout, stderr = ssh.exec_command('find /tmp /var -name "*adguard*.pid" 2>/dev/null')
    pidfile = stdout.read().decode().strip()
    print(f'Archivos PID encontrados: {pidfile if pidfile else "Ninguno"}')
    
    # 4. Verificar permisos de directorio de datos
    print('\n' + '=' * 60)
    print('4. Verificando permisos de datos...')
    print('=' * 60)
    stdin, stdout, stderr = ssh.exec_command('ls -la /var/lib/adguardhome/data/ && echo "---" && id adguardhome')
    print(stdout.read().decode().strip())
    
    # 5. Solución: Crear archivo PID correcto y reiniciar init script
    print('\n' + '=' * 60)
    print('5. Aplicando correcciones...')
    print('=' * 60)
    
    # Crear el archivo PID manualmente
    stdin, stdout, stderr = ssh.exec_command('pidof AdGuardHome > /var/run/adguardhome.pid 2>/dev/null && echo "PID file creado" || echo "No se pudo crear PID file"')
    print(stdout.read().decode().strip())
    
    # Verificar si ahora el status funciona
    stdin, stdout, stderr = ssh.exec_command('/etc/init.d/adguardhome status')
    status = stdout.read().decode().strip()
    print(f'Status después de corrección: {status}')

except Exception as e:
    print(f'ERROR: {e}')
    import traceback
    traceback.print_exc()
finally:
    ssh.close()
    print('\n' + '=' * 70)
    print('  COMPLETADO')
    print('=' * 70)