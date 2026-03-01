FROM mcr.microsoft.com/powershell:latest

WORKDIR /app

COPY UltraSecurityMonitor.ps1 ./
COPY dashboard.html ./

CMD ["pwsh", "-File", "UltraSecurityMonitor.ps1"]
