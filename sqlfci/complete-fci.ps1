    [CmdletBinding()]
param(

    [Parameter(Mandatory=$true)]
    [string]$AdminSecret,

	[Parameter(Mandatory=$true)]
    [string]$Node1FciIp,

    [Parameter(Mandatory=$true)]
    [string]$Node1SubnetId,

	[Parameter(Mandatory=$true)]
    [string]$Node2FciIp,

    [Parameter(Mandatory=$true)]
    [string]$Node2SubnetId,

	[Parameter(Mandatory=$true)]
    [string]$FCIName,

	[Parameter(Mandatory=$true)]
    [string]$SQLAdminAccounts,

    [Parameter(Mandatory=$true)]
    [string]$StackName,

    [Parameter(Mandatory=$true)]
    [string]$DomainAdminUser

)
try
{
    #Function to find Subnet mask
    function Get-SubnetMask($subnetid)
                 {
                    $subnet = get-ec2subnet -SubnetId $subnetid
                    $cidr = $subnet.CidrBlock
                    $cidr_mask = $cidr.split('/')[1]
                    $A = 0
                    $A_Index = 8
                    $B = 0
                    $B_Index = 16
                    $C = 0
                    $C_Index = 24
                    $D = 0
                    $D_Index = 32
                    for ($i = 1; $i -le $cidr_mask; $i++)
                    {
                        if ($i -le $A_Index)
                        {
                            $A += ([Math]::Pow(2, 8 - $i))
                        }
                        elseif ($i -le $B_Index)
                        {
                            $B += ([Math]::Pow(2, 8 - $i + $A_Index))
                        }
                        elseif ($i -le $C_Index)
                        {
                            $C += ([Math]::Pow(2, 8 - $i + $B_Index))
                        }
                        elseif ($i -le $D_Index)
                        {
                            $D += ([Math]::Pow(2, 8 - $i + $C_Index))
                        }
                    }
                    $subnet_mask = "{0}.{1}.{2}.{3}" -f $A, $B, $C, $D
                    return $subnet_mask
                 }
    Start-Transcript -Path C:\cfn\log\completefci.ps1.txt -Append
    $ErrorActionPreference = "Stop"
    $DomainNetBIOSName = $env:USERDOMAIN
    $AdminGroup = 'BUILTIN\Administrators'
    # Creating Credential Object for Administrator
    $AdminUser = ConvertFrom-Json -InputObject (Get-SECSecretValue -SecretId $AdminSecret).SecretString
    $ClusterAdminUser = $DomainNetBIOSName + '\' + $AdminUser.username
    $Credentials = (New-Object PSCredential($ClusterAdminUser, (ConvertTo-SecureString $AdminUser.Password -AsPlainText -Force)))

    #https://docs.microsoft.com/en-us/sql/database-engine/install-windows/install-sql-server-from-the-command-prompt?view=sql-server-ver15

    $HostName = hostname
    $fsList = Get-FSXFileSystem|?{$_.Tags.Key -eq 'aws:cloudformation:stack-name' -and $_.Tags.Value -eq $Stackname}
    #Need to run cluster validation first
    Invoke-Command -scriptblock { Test-Cluster } -Credential $Credentials -ComputerName $HostName -Authentication credssp

    $mediaExtractPath = 'C:\SQLServerSetup'
    $fileshare = $fsList.DNSName
    $sqlRootPath = "\\$($fileshare)\SqlShare\mssql"
    $sqlDataPath = "\\$($fileshare)\SqlShare\mssql\data"
    $sqlLogPath = "\\$($fileshare)\SqlShare\mssql\log"
    $Node1SubnetMask = Get-SubnetMask $Node1SubnetId
    $Node2SubnetMask = Get-SubnetMask $Node2SubnetId

    $arguments = '/QUIET /ACTION=CompleteFailoverCluster /InstanceName=MSSQLSERVER /INDICATEPROGRESS=FALSE /FAILOVERCLUSTERNETWORKNAME={0} /FAILOVERCLUSTERIPADDRESSES="IPv4;{1};Cluster Network 1;{2}" "IPv4;{3};Cluster Network 2;{4}" /CONFIRMIPDEPENDENCYCHANGE=TRUE /FAILOVERCLUSTERGROUP="SQL Server (MSSQLSERVER)" /INSTALLSQLDATADIR="C:\Program Files\Microsoft SQL Server" /SQLCOLLATION="SQL_Latin1_General_CP1_CI_AS" /SQLSYSADMINACCOUNTS={5} /INSTALLSQLDATADIR={6} /SQLUSERDBDIR={7} /SQLUSERDBLOGDIR={8} ' -f $FCIName, $Node1FciIp, $Node1SubnetMask, $Node2FciIp, $Node2SubnetMask, $AdminGroup, $sqlRootPath, $sqlDataPath, $sqlLogPath
    Invoke-Command -scriptblock {
    Start-Process -FilePath C:\SQLServerSetup\setup.exe -ArgumentList $Using:arguments -Wait -NoNewWindow
} -Credential $Credentials -ComputerName $HostName -Authentication credssp
} catch {
        $_ | Write-AWSLaunchWizardException
}