# Windows Hotspot Toggle  

PowerShell script to toggle the WiFi hotspot on Windows 10/11 without using deprecated `netsh` commands.  

## Features  

**Modern Implementation** - Uses Windows Runtime API instead of legacy `netsh`  
**Automatic Adapter Detection** - Finds WiFi adapters intelligently  
**Task Scheduler Ready** - Perfect for automated startup/scheduled activation  
**Comprehensive Logging** - Detailed logs for troubleshooting  
**User-Friendly** - Remembers your adapter selection  
**Firewall Compatible** - Includes WiFi reset functionality, for compatibility with firewalls such as Comodo

## Usage

### Run script in terminal
`.\toggle-hotspot.ps1`

### Run as a shortcut, or in Task Scheduler
`%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe -file toggle-hotspot.ps1`

## Use Cases  

- 🕒 Run a hotspot automatically at startup  
- ⏱️ Schedule hotspot availability  
- 🖱️ Quickly toggle hotspot with a desktop shortcut  
- 🤖 Integrate with other automation workflows  

## Requirements  

- Windows 10/11  
- Administrator privileges  
- PowerShell 5.1+  
