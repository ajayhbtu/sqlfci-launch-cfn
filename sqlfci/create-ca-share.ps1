[CmdletBinding()]
param(

    [Parameter(Mandatory=$true)]
    [string]$AdminSecret,

    [Parameter(Mandatory=$true)]
    [string]$Stackname,

    [Parameter(Mandatory=$true)]
    [string]$DomainAdminUser,

    [Parameter(Mandatory=$true)]
    [string]$SqlAdminUser

)
#function GetFSXFileSystem{
#    $fsList = Get-FSXFileSystem|?{$_.Tags.Key -eq 'Name' -and $_.Tags.Value -eq $Stackname}
#    $fsList.forEach{
#       $tags = $_.Tags;
#       foreach ($tag in $tags)
#       {
#         if ($tag.key -eq "aws:cloudformation:stack-name" -And $tag.value -eq $Stackname)
#         {
#           $dnsName = $_.DNSName;
#           $psEndpoint = $_.WindowsConfiguration.RemoteAdministrationEndpoint
#           break;
#         }
#       }
#     };
#     return $resultStr = "{0};{1}" -f $dnsName, $psEndpoint
#}
try{
Start-Transcript -Path C:\cfn\log\createcashare.ps1.txt -Append
$ErrorActionPreference = "Stop"
$DomainNetBIOSName = $env:USERDOMAIN
$AdminUser = ConvertFrom-Json -InputObject (Get-SECSecretValue -SecretId $AdminSecret).SecretString
$ClusterAdminUser = $DomainNetBIOSName + '\' + $DomainAdminUser
$SqlUser = $DomainNetBIOSName + '\'+ $SqlAdminUser
# Creating Credential Object for Administrator
$Credentials = (New-Object PSCredential($ClusterAdminUser,(ConvertTo-SecureString $AdminUser.Password -AsPlainText -Force)))

#Configure CA SMB share on FSx
$shareName = "SqlShare"

$fsxexists -eq $false
do{
    $fsxshare = Get-FSXFileSystem|where {$_.Tags.Key -eq "aws:cloudformation:stack-name" -And $_.Tags.Value -eq $Stackname}
    if ($fsxshare)
    {
        $fsxexists -eq $true
    }
}while($fsxexists -eq $false)

$fsList = Get-FSXFileSystem|where {$_.Tags.Key -eq 'aws:cloudformation:stack-name' -and $_.Tags.Value -eq $Stackname}

Invoke-Command -ComputerName $fslist.WindowsConfiguration.RemoteAdministrationEndpoint -ConfigurationName FSxRemoteAdmin -scriptblock {
  New-FSxSmbShare -Name $Using:shareName -Path "D:\share\" -Description "CA share for MSSQL FCI" -ContinuouslyAvailable $True -Credential $Using:Credentials
} -Credential $Credentials

Invoke-Command -ComputerName $fslist.WindowsConfiguration.RemoteAdministrationEndpoint -ConfigurationName FSxRemoteAdmin -scriptblock {
  Grant-FSxSmbShareAccess -Name $Using:shareName -AccountName $Using:ClusterAdminUser -AccessRight Full -force
} -Credential $Credentials

Invoke-Command -ComputerName $fslist.WindowsConfiguration.RemoteAdministrationEndpoint -ConfigurationName FSxRemoteAdmin -scriptblock {
   Grant-FSxSmbShareAccess -Name $Using:shareName -AccountName $Using:SqlUser -AccessRight Full -force
} -Credential $Credentials
#Configure Witness SMB share on FSx
$WitnessshareName = "SqlWitnessShare"
Invoke-Command -ComputerName $fslist.WindowsConfiguration.RemoteAdministrationEndpoint -ConfigurationName FSxRemoteAdmin -scriptblock {
  New-FSxSmbShare -Name $Using:WitnessshareName -Path "D:\share\" -Description "Witness share for MSSQL FCI" -ContinuouslyAvailable $True -Credential $Using:Credentials
} -Credential $Credentials

Invoke-Command -ComputerName $fslist.WindowsConfiguration.RemoteAdministrationEndpoint -ConfigurationName FSxRemoteAdmin -scriptblock {
  Grant-FSxSmbShareAccess -Name $Using:WitnessshareName  -AccountName Everyone -AccessRight Change -force
} -Credential $Credentials
} catch {
            $_ | Write-AWSLaunchWizardException
}






