# Router Monitoring System

Comprehensive health monitoring for home network routers (Flint-2 and Beryl).

## Contents

- **memory/** - Documentation and notes about router configuration and monitoring
- **router-check/** - Python script for automated health checks

## Quick Start

```bash
python3 router-check/router_check.py
```

## Routers

| Router | Model | IP | Tailscale |
|--------|-------|----|-----------| 
| Flint-2 | GL-MT6000 | 192.168.10.1 | 100.113.71.108 |
| Beryl | GL-MT3000 | 192.168.10.2 | — |

## Features

- 11 health checks for Flint-2 (services, DNS, Tailscale, hardware, WiFi, errors)
- 5 health checks for Beryl (services, connectivity, RAM, WiFi)
- Color-coded status indicators (✓/⚠/❌)
- Actionable recommendations for warnings/errors

