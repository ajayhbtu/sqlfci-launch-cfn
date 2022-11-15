[CmdletBinding()]
param(

	[Parameter(Mandatory=$true)]
    [string]$AMIID
)
try
{
    Start-Transcript -Path C:\cfn\log\uninstallsql.ps1.txt -Append
    $ErrorActionPreference = "Stop"
    If ((get-ec2image $AMIID).UsageOperation -eq 'RunInstances:0002')
    {
        Write-Output "SQL Server is BYOL. NO Uninstall required"
    }
    else
    {

        Write-Output "SQL LI AMI.Uninstalling SQL Server"
        $arguments = '/q /ACTION="Uninstall" /SUPPRESSPRIVACYSTATEMENTNOTICE="True" /FEATURES="SQLENGINE,AS,RS" /INSTANCENAME="MSSQLSERVER"'
        Start-Process -FilePath C:\SQLServerSetup\setup.exe -ArgumentList $arguments -Wait -NoNewWindow
    }
}catch{
            $_ | Write-AWSLaunchWizardException
}

