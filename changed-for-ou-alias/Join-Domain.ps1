[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$DomainDNSName,

    [Parameter(Mandatory=$true)]
    [string]$AdminSecret,

    [Parameter(Mandatory=$true)]
    [string]$DomainAdminUser

    [Parameter(Mandatory=$true)]
    [string]$OUPath
)

try {
$ErrorActionPreference = "Stop"
Start-Transcript -Path C:\cfn\log\$($MyInvocation.MyCommand.Name).log -Append

# Getting Password from Secrets Manager for AD Admin User
$ADAdminPassword = ConvertFrom-Json -InputObject (Get-SECSecretValue -SecretId $AdminSecret | Select-Object -ExpandProperty 'SecretString')
# Creating Credential Object for Administrator
$AdminUserName = $DomainNetBIOSName+"\"+$DomainAdminUser
$AdminUserPW = ConvertTo-SecureString ($ADAdminPassword.Password) -AsPlainText -Force
$Credentials = New-Object -TypeName 'System.Management.Automation.PSCredential' ($AdminUserName, $AdminUserPW)
Add-Computer -DomainName $DomainDNSName -Credential $Credentials -OUPath $OUPath -ErrorAction Stop
}
catch {
    $_ | Write-AWSLaunchWizardException
}

# restart computer to make joining domain effective
C:\cfn\scripts\common\Restart-Computer.ps1
