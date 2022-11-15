[CmdletBinding()]
param(

    [Parameter(Mandatory=$true)]
    [string]$AdminSecret,

    [Parameter(Mandatory=$true)]
    [string]$DomainAdminUser

)
#Requires -Modules xFailOverCluster,PSDscResources
try {
Start-Transcript -Path C:\cfn\log\AdditionalNodeAddCluster.ps1.txt -Append
$ErrorActionPreference = "Stop"
# Getting the DSC Cert Encryption Thumbprint to Secure the MOF File
$DscCertThumbprint = (get-childitem -path cert:\LocalMachine\My | where { $_.subject -eq "CN=AWSLWDscEncryptCert" }).Thumbprint
$DomainNetBIOSName = $env:USERDOMAIN
# Getting Password from Secrets Manager for AD Admin User
$AdminUser = ConvertFrom-Json -InputObject (Get-SECSecretValue -SecretId $AdminSecret).SecretString
$ClusterAdminUser = $DomainNetBIOSName + '\' + $DomainAdminUser
# Creating Credential Object for Administrator
$Credentials = (New-Object PSCredential($ClusterAdminUser,(ConvertTo-SecureString $AdminUser.Password -AsPlainText -Force)))

$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName="*"
            CertificateFile = "C:\cfn\dsc\publickeys\AWSLWDscPublicKey.cer"
            Thumbprint = $DscCertThumbprint
            PSDscAllowDomainUser = $true
        },
        @{
            NodeName = 'localhost'
        }
    )
}

Configuration AdditionalNodeAddCluster {
param(
[PSCredential] $Credentials
)

Import-DscResource -ModuleName xFailOverCluster
Import-DscResource -ModuleName PSDscResources

Node 'localhost'{

WindowsFeature RSAT-AD-PowerShell {
Name = 'RSAT-AD-PowerShell'
Ensure = 'Present'
}

WindowsFeature AddFailoverFeature {
Ensure = 'Present'
Name = 'Failover-clustering'
DependsOn = '[WindowsFeature]RSAT-AD-PowerShell'
}
}
}

AdditionalNodeAddCluster -OutputPath 'C:\cfn\dsc\AdditionalNodeAddCluster' -ConfigurationData $ConfigurationData -Credentials $Credentials

Start-DscConfiguration 'C:\cfn\dsc\AdditionalNodeAddCluster' -Wait -Verbose -Force
}catch {
    $_ | Write-AWSLaunchWizardException
}
