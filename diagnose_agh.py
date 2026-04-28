#!/usr/bin/env python3
import paramiko
import time

ROUTER_IP = '192.168.10.1'
USERNAME = 'root'
PASSWORD = 'admin'

print('=' * 70)
print('  DIAGNÓSTICO ADGUARD HOME')
print('=' * 70)

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

try:
    print(f'\nConectando a {ROUTER_IP}...')
    ssh.connect(ROUTER_IP, username=USERNAME, password=PASSWORD, timeout=10)
    print('Conectado!\n')

    # 1. Verificar configuración completa
    print('=' * 60)
    print('1. Configuración YAML completa')
    print('=' * 60)
    stdin, stdout, stderr = ssh.exec_command('cat /etc/adguardhome/adguardhome.yaml')
    config = stdout.read().decode()
    print(config)

    # 2. Verificar errores de inicio
    print('\n' + '=' * 60)
    print('2. Intentando iniciar y ver errores')
    print('=' * 60)
    
    stdin, stdout, stderr = ssh.exec_command('/usr/bin/AdGuardHome -c /etc/adguardhome/adguardhome.yaml -w /var/lib/adguardhome 2>&1 &')
    time.sleep(2)
    
    stdin, stdout, stderr = ssh.exec_command('logread | grep -i "adguard\\|error" | tail -20')
    logs = stdout.read().decode().strip()
    print(f'Logs:\n{logs}')

    # 3. Verificar puertos
    print('\n' + '=' * 60)
    print('3. Puertos en uso')
    print('=' * 60)
    stdin, stdout, stderr = ssh.exec_command('netstat -tulnp | grep -E "3053|6060|AdGuard"')
    ports = stdout.read().decode().strip()
    print(ports if ports else "Ningún puerto de AdGuard encontrado")

    # 4. Verificar proceso
    print('\n' + '=' * 60)
    print('4. Proceso')
    print('=' * 60)
    stdin, stdout, stderr = ssh.exec_command('ps | grep -i adguard')
    proc = stdout.read().decode().strip()
    print(proc if proc else "No hay proceso")

    # 5. Verificar dnsmasq
    print('\n' + '=' * 60)
    print('5. Configuración dnsmasq')
    print('=' * 60)
    stdin, stdout, stderr = ssh.exec_command('uci show dhcp | grep server')
    print(stdout.read().decode().strip())
    
    stdin, stdout, stderr = ssh.exec_command('cat /etc/resolv.conf')
    print(f'\nresolv.conf:\n{stdout.read().decode().strip()}')

except Exception as e:
    print(f'ERROR: {e}')
finally:
    ssh.close()