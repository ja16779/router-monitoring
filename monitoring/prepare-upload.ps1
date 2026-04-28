$json = Get-Content 'C:\Users\ja167\.local\bin\monitoring\grafana\provisioning\dashboards\beryl-cloud.json' -Raw | ConvertFrom-Json

# Remove __inputs (used for import, not API)
$json.PSObject.Properties.Remove('__inputs')
$json.id = $null

# Add datasource to all panels and targets
$ds = @{type='prometheus';uid='grafanacloud-prom'}
foreach ($panel in $json.panels) {
    if ($panel.targets) {
        foreach ($target in $panel.targets) {
            $target | Add-Member -NotePropertyName 'datasource' -NotePropertyValue $ds -Force
        }
    }
    $panel | Add-Member -NotePropertyName 'datasource' -NotePropertyValue $ds -Force
}

# Wrap in API payload
$payload = @{
    dashboard = $json
    overwrite = $true
    folderUid = ''
} | ConvertTo-Json -Depth 20 -Compress

$outPath = 'C:\Users\ja167\.local\bin\monitoring\beryl-upload.json'
[System.IO.File]::WriteAllText($outPath, $payload, [System.Text.UTF8Encoding]::new($false))
Write-Host "Payload ready, size: $((Get-Item $outPath).Length) bytes"
