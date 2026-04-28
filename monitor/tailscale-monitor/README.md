# Tailscale Monitor — GL-MT6000

Monitor externo que detecta cuando el router pierde conectividad en ambos enlaces WAN.

## Setup (5 minutos)

### 1. Crear repositorio en GitHub
- Crea un repo **privado** llamado `tailscale-monitor`
- Sube estos archivos

### 2. Configurar Secrets en GitHub
Ve a: Settings → Secrets and variables → Actions → New repository secret

| Secret | Valor |
|--------|-------|
| `TS_API_KEY` | Tu Tailscale API key (tskey-api-...) |
| `TELEGRAM_BOT_TOKEN` | Token de tu bot de Telegram |
| `TELEGRAM_CHAT_ID` | Tu chat ID de Telegram |

### 3. Generar Tailscale API Key
- Ve a: https://login.tailscale.com/admin/settings/keys
- Crea una API key con permisos de **lectura** (Read)
- Guárdala en el secret `TS_API_KEY`

### 4. Habilitar el workflow
- Ve a la pestaña **Actions** en tu repo
- Activa los workflows si están deshabilitados

## Funcionamiento
- Corre cada **5 minutos** via GitHub Actions (gratuito)
- Consulta la API de Tailscale para ver cuándo fue visto GL-MT6000
- Si han pasado más de **10 minutos** sin verse → Telegram alert
- Costo: **$0** (dentro del límite gratuito de GitHub Actions)
