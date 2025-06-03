<#
.SYNOPSIS
    Hotspot Toggle with Persistent WiFi Adapter Selection
.DESCRIPTION
    Remembers selected WiFi adapter between sessions only when manual selection is needed
.NOTES
    Requires: Windows 10/11, Administrator privileges
    Config file: $PSScriptRoot\adapter.config
#>

# ==== Script Version ====

	# This is automatically updated via pre-commit hook
	$scriptVersion = "1.0.0"

	# Config file path
	$configDir = $PSScriptRoot
	$configFile = "$configDir\adapter.config"

	# Create log file? For debugging purposes
	$logFile = $true

	#should the log file be printed in reverse order?
	$logReverse = $false

	# Define a log file path
	$logFilePath = "$configDir\script.log"

	# Restart Wifi adapter? 
	# This is necessary for certain firewalls such as Comodo to open ports for the Hotspot
	$restartWiFi = $true

# ==== FUNCTIONS =====

	# Create the logging system
	function LogThis  {
		param (
			[string]$Message,
			[string]$Color = "White"
		)
		
		#Terminal message
		Write-Host $Message -ForegroundColor $Color
		
		# Log only if Logging is enabled
		if ($logFile) {
			#check if printing in reverse or not
			if ($logReverse) {
				
				# Read the existing content of the log file
				$existingContent = Get-Content -Path $logFilePath -Raw

				# Prepend the new log entry to the existing content
				$updatedContent = "$Message`n$existingContent"

				# Write the updated content back to the log file
				$updatedContent | Set-Content -Path $logFilePath -Encoding UTF8
				
			} else {
				
				$Message | Out-File -Append -FilePath $logFilePath -Encoding UTF8
			}

		}
	}

	# Determine if the script runs interactively
	function IsRunningFromTerminal {

		# Get the current process ID
		$proc = Get-CimInstance Win32_Process -Filter "ProcessId = $pid"

		# Get the parent process ID
		$parent = Get-CimInstance Win32_Process -Filter "ProcessId = $($proc.ParentProcessId)"

		# Check if the parent process is 'svchost.exe' and contains 'Schedule' in the command line
		if ($parent.Name -eq "svchost.exe" -or $parent.CommandLine -like "*Schedule*") {

			return $false

		} else {

			return $true
		}
	}
	
	# Identify Wifi Adapter
	function Get-WiFiAdapter {
		# Try to load saved adapter first (only if config exists)
		if (Test-Path $configFile) {
			try {
				LogThis "Found config file, attempting to load adapter"														 
				$savedAdapter = Get-Content $configFile -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
				$adapter = Get-NetAdapter | Where-Object { 
					$_.Name -eq $savedAdapter.Name -and 
					$_.InterfaceDescription -eq $savedAdapter.Description
				}
				
				if ($adapter) {
					LogThis -Message "Using saved WiFi adapter: $($adapter.Name)" -Color "Cyan"													  
					return $adapter
				} else {
					LogThis "Saved adapter not found"
				}
			}
			catch {
				LogThis "Error reading adapter config: $_"  -Color "Yellow"
		   }
		}

		# Automatic detection patterns
		$patterns = @(
			"*Wireless*", 
			"*Wi-Fi*",
			"*WLAN*",
			"*802.11*"
		)
		
		foreach ($pattern in $patterns) {
			$adapter = Get-NetAdapter | Where-Object { 
				$_.Name -like $pattern -or 
				$_.InterfaceDescription -like $pattern
			} | Select-Object -First 1
			
			if ($adapter) {
				LogThis "Found WiFi adapter via pattern: $pattern -> $($adapter.Name)"
				return $adapter
			}
		}

		# Fallback to physical media types
		$adapter = Get-NetAdapter | Where-Object {
			$_.PhysicalMediaType -eq 'Native 802.11' -or
			$_.MediaType -eq 'Wireless WAN'
		} | Select-Object -First 1
		
		if ($adapter) {
			LogThis "Found WiFi adapter via fallback type match: $($adapter.Name)"														
			return $adapter
		}

		# Final fallback - manual selection (only creates config in this case)
		LogThis -Message "Automatic detection failed, requesting manual adapter selection" -Color "Yellow"
		$selected = Get-NetAdapter | Out-GridView -Title "Select your WiFi adapter (Will be remembered for future use)" -PassThru
		
		if ($selected) {
			LogThis "Manual adapter selected: $($selected.Name)"
			Save-AdapterConfig $selected
			return $selected
		}

		LogThis "No WiFi adapter selected, aborting"  -Color "Red"
		throw "No WiFi adapter selected"
	}

	# Save WIFI adapter in a file, if manually selected
	function Save-AdapterConfig {
		param($adapter)
		
		try {
			if (-not (Test-Path $configDir)) {
				New-Item -ItemType Directory -Path $configDir -ErrorAction Stop | Out-Null
			}
			
			[PSCustomObject]@{
				Name = $adapter.Name
				Description = $adapter.InterfaceDescription
			} | ConvertTo-Json -ErrorAction Stop | Out-File $configFile -ErrorAction Stop
			
			LogThis "Adapter config saved: $($adapter.Name)" -Color "Green"
		}
		catch {
			LogThis "Failed to save adapter config: $_" -Color "Yellow"
		}
	}
	
	# Restart WiFi Adapter (Necessary for certain firewalls such as Comodo)
	function Restart-WiFi {
		try {
			$wifiAdapter = Get-NetAdapter | Where-Object { $_.InterfaceDescription -like "*Wireless*" } | Select-Object -First 1
			if (-not $wifiAdapter) {
				Write-Host "WiFi adapter not found"  -Color "Yellow"
				return $false
			}

			LogThis "Restarting WiFi adapter..."  -Color "Yellow"
			Restart-NetAdapter -Name $wifiAdapter.Name -Confirm:$false -ErrorAction Stop
			Start-Sleep -Seconds 2
			LogThis "WiFi restart complete"  -Color "Green"
			return $true
		}
		catch {
			LogThis "WiFi restart failed: $_" -Color "Red"
			return $false
		}
	}

	# Main function
	function Toggle-Hotspot {
		try {
			$connectionProfile = [Windows.Networking.Connectivity.NetworkInformation]::GetInternetConnectionProfile()
			$tetheringManager = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager]::CreateFromConnectionProfile($connectionProfile)
			
			if ($tetheringManager.TetheringOperationalState -eq 'On') {
				LogThis "Hotspot is active - disabling..." -Color "Yellow"
				$null = $tetheringManager.StopTetheringAsync()
				LogThis "Hotspot disabled"  -Color "Green"
			}
			else {
				LogThis "Hotspot is inactive - enabling..."  -Color "Yellow"
				if ($restartWiFi) {Restart-WiFi | Out-Null}
				$null = $tetheringManager.StartTetheringAsync()
				LogThis "Hotspot enabled"  -Color "Green"
			}
			return $true
		}
		catch {
			LogThis "Hotspot toggle failed: $_" -Color "Red"
			return $false
		}
	}

# ==== RUNTIME EXECUTION ====

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

LogThis ""
LogThis "==== Script started @ $timestamp ===="  -Color "Cyan"
LogThis ""

# Load required assemblies
LogThis "Loading required assemblies..."
[Windows.Networking.Connectivity.NetworkInformation, Windows.Networking.Connectivity, ContentType = WindowsRuntime] | Out-Null
[Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager, Windows.Networking.NetworkOperators, ContentType = WindowsRuntime] | Out-Null

if (IsRunningFromTerminal) {LogThis "Script is running from Terminal."}
else {LogThis "Script is running from Task Scheduler."}

# Call the main function
Toggle-Hotspot

LogThis ""
# Keep console open briefly
Start-Sleep -Seconds 2