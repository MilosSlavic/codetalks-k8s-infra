$lb_ip = (terraform output --raw lb_ip)
Write-Host "LoadBalancer IP: ${lb_ip}"
Invoke-WebRequest -Method Get -Uri "http://${lb_ip}:15021/healthz/ready"