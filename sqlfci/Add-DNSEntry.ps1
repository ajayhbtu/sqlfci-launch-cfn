[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ADServerPrivateIP,

    [Parameter(Mandatory=$true)]
    [string]$DomainDNSName
)

try {
    $ErrorActionPreference = "Stop"
    Start-Transcript -Path C:\cfn\log\$($MyInvocation.MyCommand.Name).log -Append
    Get-NetAdapter | Set-DnsClientServerAddress -ServerAddresses $ADServerPrivateIP
}
catch {
    $_ | Write-AWSLaunchWizardException
}