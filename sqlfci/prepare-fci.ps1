[CmdletBinding()]
param(

    [Parameter(Mandatory=$true)]
    [string]$AdminSecret,

	[Parameter(Mandatory=$true)]
    [string]$SqlUserSecret,

	[Parameter(Mandatory=$true)]
    [string]$MSSQLMediaBucket,

	[Parameter(Mandatory=$true)]
    [string]$MSSQLMediaKey,

	[Parameter(Mandatory=$true)]
    [string]$AMIID,

    [Parameter(Mandatory=$true)]
    [string]$DomainAdminUser

)

try{
Start-Transcript -Path C:\cfn\log\preparefci.ps1.txt -Append
$ErrorActionPreference = "Stop"
$HostName = hostname

$DomainNetBIOSName = $env:USERDOMAIN
# Creating Credential Object for Administrator
$AdminUser = ConvertFrom-Json -InputObject (Get-SECSecretValue -SecretId $AdminSecret).SecretString
$ClusterAdminUser = $DomainNetBIOSName+'\'+$AdminUser.username
$Credentials = (New-Object PSCredential($ClusterAdminUser,(ConvertTo-SecureString $AdminUser.Password -AsPlainText -Force)))

#Retrieving MSSQL service account
$SqlUser = ConvertFrom-Json -InputObject (Get-SECSecretValue -SecretId $SqlUserSecret).SecretString
$SqlUserName = $DomainNetBIOSName + '\' + $SqlUser.username
$SqlUserPassword = $SqlUser.password

if((get-ec2image $AMIID).UsageOperation -eq 'RunInstances:0002')
{
    #Acquiring MSSQL installation media from S3
$mediaIsoPath = 'c:\cfn\mssql-setup-media\SQL_server.iso'
$mediaExtractPath = 'C:\SQLServerSetup'
    try{
        Copy-S3Object -BucketName $MSSQLMediaBucket -Key $MSSQLMediaKey -LocalFile $mediaIsoPath
    }catch{
        $_ | Write-AWSLaunchWizardException
    }
#Mounting and extracting installation media files
New-Item -Path $mediaExtractPath -ItemType Directory
$mountResult = Mount-DiskImage -ImagePath $mediaIsoPath -PassThru
$volumeInfo = $mountResult | Get-Volume
$driveInfo = Get-PSDrive -Name $volumeInfo.DriveLetter
Copy-Item -Path ( Join-Path -Path $driveInfo.Root -ChildPath '*' ) -Destination $mediaExtractPath -Recurse
Dismount-DiskImage -ImagePath $mediaIsoPath
    #Prepare FCI installation
$arguments = '/ACTION="PrepareFailoverCluster" /IAcceptSQLServerLicenseTerms="True" /IACCEPTROPENLICENSETERMS="False" /SUPPRESSPRIVACYSTATEMENTNOTICE="True" /ENU="True" /QUIET="True" /UpdateEnabled="False" /USEMICROSOFTUPDATE="False" /SUPPRESSPAIDEDITIONNOTICE="True" /UpdateSource="MU" /FEATURES=SQLENGINE,REPLICATION,FULLTEXT,DQ /HELP="False" /INDICATEPROGRESS="False" /X86="False" /INSTANCENAME="MSSQLSERVER" /INSTALLSHAREDDIR="C:\Program Files\Microsoft SQL Server" /INSTALLSHAREDWOWDIR="C:\Program Files (x86)\Microsoft SQL Server" /INSTANCEID="MSSQLSERVER" /INSTANCEDIR="C:\Program Files\Microsoft SQL Server" /AGTSVCACCOUNT="{0}" /AGTSVCPASSWORD="{1}" /FILESTREAMLEVEL="0" /SQLSVCACCOUNT="{0}" /SQLSVCPASSWORD="{1}" /SQLSVCINSTANTFILEINIT="False" /FTSVCACCOUNT="NT Service\MSSQLFDLauncher" ' -f $SqlUserName, $SqlUserPassword
Invoke-Command -scriptblock {
    Start-Process -FilePath C:\SQLServerSetup\setup.exe -ArgumentList $Using:arguments -Wait -NoNewWindow
} -Credential $Credentials -ComputerName $HostName -Authentication credssp
}
else {
$arguments = '/ACTION="PrepareFailoverCluster" /IAcceptSQLServerLicenseTerms="True" /IACCEPTROPENLICENSETERMS="False" /SUPPRESSPRIVACYSTATEMENTNOTICE="True" /ENU="True" /QUIET="True" /UpdateEnabled="False" /USEMICROSOFTUPDATE="False" /UpdateSource="MU" /FEATURES=SQLENGINE,REPLICATION,FULLTEXT,DQ /HELP="False" /INDICATEPROGRESS="False" /X86="False" /INSTANCENAME="MSSQLSERVER" /INSTALLSHAREDDIR="C:\Program Files\Microsoft SQL Server" /INSTALLSHAREDWOWDIR="C:\Program Files (x86)\Microsoft SQL Server" /INSTANCEID="MSSQLSERVER" /INSTANCEDIR="C:\Program Files\Microsoft SQL Server" /AGTSVCACCOUNT="{0}" /AGTSVCPASSWORD="{1}" /FILESTREAMLEVEL="0" /SQLSVCACCOUNT="{0}" /SQLSVCPASSWORD="{1}" /SQLSVCINSTANTFILEINIT="False" /FTSVCACCOUNT="NT Service\MSSQLFDLauncher" ' -f $SqlUserName, $SqlUserPassword
Invoke-Command -scriptblock {
    Start-Process -FilePath C:\SQLServerSetup\setup.exe -ArgumentList $Using:arguments -Wait -NoNewWindow
} -Credential $Credentials -ComputerName $HostName -Authentication credssp
}
} catch {
        $_ | Write-AWSLaunchWizardException
}
