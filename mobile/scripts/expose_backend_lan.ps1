# Expose le backend WSL (KORA FastAPI port 8001) sur le LAN Wi-Fi pour le
# telephone. A executer en POWERSHELL ADMINISTRATEUR sur Windows.
#
# Apres execution :
#  - 192.168.1.12:8001 (IP LAN Windows) repond
#  - Le telephone peut taper http://192.168.1.12:8001/api/v1/...
#
# Pour annuler tout ca : .\expose_backend_lan.ps1 -Remove
param([switch]$Remove)

$Port = 8001
$FirewallName = "KORA backend dev (port $Port)"

if ($Remove) {
    Write-Host "Suppression du port-forward et de la regle firewall..."
    netsh interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=$Port | Out-Null
    Get-NetFirewallRule -DisplayName $FirewallName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
    Write-Host "OK, tout est revoque."
    exit 0
}

# 1. Detection IP WSL (change a chaque reboot WSL)
$wslIp = (wsl -- hostname -I).Trim().Split()[0]
if (-not $wslIp) {
    Write-Error "Impossible de detecter l'IP WSL. WSL est-il demarre ?"
    exit 1
}
Write-Host "IP WSL detectee : $wslIp"

# 2. Suppression de l'ancien port-forward (idempotent)
netsh interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=$Port 2>$null | Out-Null

# 3. Creation du port-forward Windows:8001 -> WSL:8001
netsh interface portproxy add v4tov4 `
    listenaddress=0.0.0.0 listenport=$Port `
    connectaddress=$wslIp connectport=$Port | Out-Null
Write-Host "Port-forward 0.0.0.0:$Port -> ${wslIp}:$Port active."

# 4. Regle firewall (idempotent)
$existing = Get-NetFirewallRule -DisplayName $FirewallName -ErrorAction SilentlyContinue
if (-not $existing) {
    New-NetFirewallRule -DisplayName $FirewallName `
        -Direction Inbound -Protocol TCP -LocalPort $Port -Action Allow `
        -Profile Private | Out-Null
    Write-Host "Regle firewall ajoutee (Inbound TCP $Port, profile Private)."
} else {
    Write-Host "Regle firewall deja presente."
}

# 5. Verification finale
Write-Host ""
Write-Host "=== Verifications ==="
netsh interface portproxy show v4tov4
$winIp = (Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -ne $null -and $_.NetAdapter.Status -eq 'Up' } | Select-Object -First 1).IPv4Address.IPAddress
Write-Host ""
Write-Host "IP LAN Windows (a utiliser dans l'APK) : $winIp"
Write-Host ""
Write-Host "Pour tester depuis le telephone :"
Write-Host "  Ouvre le navigateur, va sur http://${winIp}:$Port/docs"
Write-Host "  Si la doc Swagger s'affiche, le forward fonctionne."
