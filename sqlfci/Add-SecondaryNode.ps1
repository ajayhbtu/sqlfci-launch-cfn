[CmdletBinding()]
param(

    [Parameter(Mandatory=$true)]
    [string]$WSFCNode2PrivateIP2,

    [Parameter(Mandatory=$true)]
    [string]$ClusterName,

    [Parameter(Mandatory=$true)]
    [string]$AdminSecret,

    [Parameter(Mandatory=$true)]
    [string]$DomainAdminUser

)
try{
Start-Transcript -Path C:\cfn\log\AddSecondaryNode.ps1.txt -Append
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

Configuration AddSecondaryNode  {
    param(
        [PSCredential] $Credentials
    )

    Import-Module -Name xFailOverCluster
    Import-Module -Name PSDscResources
    Import-Module -Name AmznFailoverCluster

    Import-DscResource -ModuleName xFailOverCluster
    Import-DscResource -ModuleName PSDscResources
    Import-DscResource -ModuleName AmznFailoverCluster

    Node 'localhost'{

        xWaitForCluster WaitForCluster {
            Name             = $ClusterName
            RetryIntervalSec = 10
            RetryCount       = 120
        }

        xCluster JoinNodeToCluster {
            Name                          = $ClusterName
            StaticIPAddress               = $WSFCNode2PrivateIP2
            DomainAdministratorCredential = $Credentials
            DependsOn                     = '[xWaitForCluster]WaitForCluster'
        }
         ClusterIPAddressResource IPaddress
        {
            OwnerGroup = 'Cluster Group'
            Ensure     = 'Present'
            PsDscRunAsCredential = $Credentials
            DependsOn = '[xCluster]JoinNodeToCluster'
        }
    }
}

AddSecondaryNode -OutputPath 'C:\cfn\dsc\AddSecondaryNode' -ConfigurationData $ConfigurationData -Credentials $Credentials

Start-DscConfiguration 'C:\cfn\dsc\AddSecondaryNode' -Wait -Verbose -Force
} catch {
    $_ | Write-AWSLaunchWizardException
}
