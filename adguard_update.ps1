Import-Module Posh-SSH

$password = ConvertTo-SecureString 'admin' -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential('root', $password)

$session = New-SSHSession -ComputerName '192.168.8.1' -Credential $cred -AcceptKey -Force -ErrorAction Stop
Write-Host "SSH session established, SessionId: $($session.SessionId)"

# Command 1: Update AdGuard upstream DNS
Write-Host ""
Write-Host "=== COMMAND 1: Update AdGuard Home upstream DNS ==="
$jsonBody = '{"upstream_dns":["quic://dns.adguard-dns.com","quic://unfiltered.adguard-dns.com","https://dns.google/dns-query","https://cloudflare-dns.com/dns-query","[/0.openwrt.pool.ntp.org/]8.8.8.8","[/1.openwrt.pool.ntp.org/]8.8.4.4"],"upstream_mode":"fastest_addr"}'
$cmd1 = "curl -s -X POST http://127.0.0.1:3000/control/dns_config -H 'Content-Type: application/json' -d '$jsonBody'"
$result1 = Invoke-SSHCommand -SessionId $session.SessionId -Command $cmd1
Write-Host "Output: $($result1.Output)"
Write-Host "ExitStatus: $($result1.ExitStatus)"

# Command 2: Verify config
Write-Host ""
Write-Host "=== COMMAND 2: Verify config applied ==="
$cmd2 = "curl -s http://127.0.0.1:3000/control/dns_info | python3 -c `"import sys,json; d=json.load(sys.stdin); print(json.dumps({'upstream_dns': d.get('upstream_dns'), 'upstream_mode': d.get('upstream_mode')}, indent=2))`""
$result2 = Invoke-SSHCommand -SessionId $session.SessionId -Command $cmd2
Write-Host "Output: $($result2.Output)"
Write-Host "ExitStatus: $($result2.ExitStatus)"

# Command 3: Test DNS
Write-Host ""
Write-Host "=== COMMAND 3: Test DNS resolution ==="
$result3 = Invoke-SSHCommand -SessionId $session.SessionId -Command 'nslookup google.com 127.0.0.1'
Write-Host "Output: $($result3.Output)"
Write-Host "ExitStatus: $($result3.ExitStatus)"

Remove-SSHSession -SessionId $session.SessionId
Write-Host ""
Write-Host "Done."
