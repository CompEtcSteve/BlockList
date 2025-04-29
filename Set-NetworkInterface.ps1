# Script to configure network interface settings

# Import required module
Import-Module NetTCPIP

# Function to get user input for network settings
function Get-UserInput {
    param (
        [string]$Prompt
    )
    Write-Host $Prompt -ForegroundColor Green
    Read-Host
}

# Function to display available network interfaces and get user's choice
function Select-NetworkInterface {
    param (
        [bool]$IncludeInactive = $false
    )

    Write-Host "Fetching available network interfaces..." -ForegroundColor Cyan
    if ($IncludeInactive) {
        $Interfaces = Get-NetAdapter
    } else {
        $Interfaces = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
    }

    if ($Interfaces.Count -eq 0) {
        Write-Host "No network interfaces found. Exiting." -ForegroundColor Red
        exit
    }

    Write-Host "Available network interfaces:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $Interfaces.Count; $i++) {
        Write-Host "$($i + 1). $($Interfaces[$i].Name) (Status: $($Interfaces[$i].Status))" -ForegroundColor White
    }

    $SelectedIndex = Get-UserInput "Enter the number corresponding to the network interface:"
    if ($SelectedIndex -notmatch '^\d+$' -or $SelectedIndex -lt 1 -or $SelectedIndex -gt $Interfaces.Count) {
        Write-Host "Invalid selection. Exiting." -ForegroundColor Red
        exit
    }

    return $Interfaces[$SelectedIndex - 1].Name
}

# Function to enable DHCP on the selected interface
function Enable-DHCP {
    param (
        [string]$InterfaceName
    )
    try {
        Write-Host "Enabling DHCP for IP and DNS on interface '$InterfaceName'..." -ForegroundColor Yellow
        Set-NetIPInterface -InterfaceAlias $InterfaceName -Dhcp Enabled -ErrorAction Stop
        Set-DnsClientServerAddress -InterfaceAlias $InterfaceName -ResetServerAddresses -ErrorAction Stop
        Write-Host "DHCP has been enabled successfully." -ForegroundColor Green
    } catch {
        Write-Host "Failed to enable DHCP: $_" -ForegroundColor Red
        exit
    }
}

# Function to disable DHCP on the selected interface
function Disable-DHCP {
    param (
        [string]$InterfaceName
    )
    try {
        Write-Host "Disabling DHCP on interface '$InterfaceName'..." -ForegroundColor Yellow
        Set-NetIPInterface -InterfaceAlias $InterfaceName -Dhcp Disabled -ErrorAction Stop
        Write-Host "DHCP has been disabled successfully." -ForegroundColor Green
    } catch {
        Write-Host "Failed to disable DHCP: $_" -ForegroundColor Red
        exit
    }
}

# Function to add multiple IP addresses (multi-home) to the selected interface
function Add-MultiHomeIP {
    param (
        [string]$InterfaceName
    )

    $AddMore = $true
    while ($AddMore) {
        $IPAddress = Get-UserInput "Enter the new IP address to add (e.g., 192.168.1.101):"
        $SubnetMask = Get-UserInput "Enter the Subnet Mask for this IP (e.g., 255.255.255.0):"
        $SubnetMask.split(".") | ForEach-Object { $BinaryRep += [Convert]::ToString($_, 2) }
        $PrefixLength = $BinaryRep.IndexOf("0")

        try {
            Write-Host "Adding IP address $IPAddress with prefix length $PrefixLength..." -ForegroundColor Yellow
            New-NetIPAddress -InterfaceAlias $InterfaceName -IPAddress $IPAddress -PrefixLength $PrefixLength -ErrorAction Stop
            Write-Host "IP address $IPAddress added successfully." -ForegroundColor Green
        } catch {
            Write-Host "Failed to add IP address: $_" -ForegroundColor Red
            exit
        }

        $AddMoreInput = Get-UserInput "Do you want to add another IP address? (yes/no):"
        if ($AddMoreInput -notlike "yes") {
            $AddMore = $false
        }
    }
}

# Main script
Write-Host "Do you want to include inactive interfaces in the selection?" -ForegroundColor Cyan
Write-Host "1. Yes (Show all interfaces)" -ForegroundColor White
Write-Host "2. No (Show only active interfaces)" -ForegroundColor White
$IncludeInactiveChoice = Get-UserInput "Enter your choice (1 or 2):"

$IncludeInactive = $false
if ($IncludeInactiveChoice -eq "1") {
    $IncludeInactive = $true
} elseif ($IncludeInactiveChoice -ne "2") {
    Write-Host "Invalid choice. Exiting." -ForegroundColor Red
    exit
}

Write-Host "What do you want to do?" -ForegroundColor Cyan
Write-Host "1. Manual configuration" -ForegroundColor White
Write-Host "2. Enable DHCP" -ForegroundColor White
Write-Host "3. Add multiple IP addresses (multi-home)" -ForegroundColor White
$Choice = Get-UserInput "Enter your choice (1, 2, or 3):"

if ($Choice -eq "2") {
    # Enable DHCP
    $InterfaceName = Select-NetworkInterface -IncludeInactive $IncludeInactive
    Enable-DHCP -InterfaceName $InterfaceName
} elseif ($Choice -eq "1") {
    # Manual configuration
    $InterfaceName = Select-NetworkInterface -IncludeInactive $IncludeInactive

    # Check if DHCP is enabled and disable it before configuring a static IP
    $DhcpEnabled = (Get-NetIPInterface -InterfaceAlias $InterfaceName).Dhcp
    if ($DhcpEnabled -eq "Enabled") {
        Disable-DHCP -InterfaceName $InterfaceName
    }

    # Get IP settings from user
    $IPAddress = Get-UserInput "Enter the new IP address (e.g., 192.168.1.100):"
    $SubnetMask = Get-UserInput "Enter the Subnet Mask (e.g., 255.255.255.0):"
    $Gateway = Get-UserInput "Enter the Default Gateway (e.g., 192.168.1.1):"
    $DNS = Get-UserInput "Enter the DNS Server(s) separated by commas (e.g., 1.1.1.1,8.8.8.8):"

    # Apply the IP address and subnet mask
    try {
        Write-Host "Configuring IP address and subnet mask..." -ForegroundColor Yellow
        $SubnetMask.split(".") | ForEach-Object { $BinaryRep += [Convert]::ToString($_, 2) }
        $PrefixLength = $BinaryRep.IndexOf("0")
        Write-Host $IPAddress $PrefixLength -ForegroundColor Yellow
        if (-not [string]::IsNullOrWhiteSpace($Gateway)) {
            New-NetIPAddress -InterfaceAlias $InterfaceName -IPAddress $IPAddress -PrefixLength $PrefixLength -DefaultGateway $Gateway -ErrorAction Stop
        } else {
            New-NetIPAddress -InterfaceAlias $InterfaceName -IPAddress $IPAddress -PrefixLength $PrefixLength -ErrorAction Stop
            Write-Host "No gateway provided. Skipping gateway configuration." -ForegroundColor Yellow
        }
        Write-Host "IP address and subnet mask configured successfully." -ForegroundColor Green
    } catch {
        Write-Host "Failed to configure IP address and subnet mask: $_" -ForegroundColor Red
        exit
    }

    # Configure DNS servers
    if (-not [string]::IsNullOrWhiteSpace($DNS)) {
        try {
            Write-Host "Configuring DNS servers..." -ForegroundColor Yellow
            $DNSServers = $DNS -split ","
            Set-DnsClientServerAddress -InterfaceAlias $InterfaceName -ServerAddresses $DNSServers -ErrorAction Stop
            Write-Host "DNS servers configured successfully." -ForegroundColor Green
        } catch {
            Write-Host "Failed to configure DNS servers: $_" -ForegroundColor Red
            exit
        }
    } else {
        Write-Host "No DNS servers provided. Skipping DNS configuration." -ForegroundColor Yellow
    }

    Write-Host "Network settings updated successfully!" -ForegroundColor Cyan
} elseif ($Choice -eq "3") {
    # Add multiple IP addresses
    $InterfaceName = Select-NetworkInterface -IncludeInactive $IncludeInactive
    Add-MultiHomeIP -InterfaceName $InterfaceName
} else {
    Write-Host "Invalid choice. Exiting." -ForegroundColor Red
    exit
}
