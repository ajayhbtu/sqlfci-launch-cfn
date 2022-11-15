[CmdletBinding()]
param(

    [Parameter(Mandatory = $true)]
    [string]$DomainDnsName,

    [Parameter(Mandatory = $true)]
    [string]$WSFCNode1PrivateIP2,

    [Parameter(Mandatory = $true)]
    [string]$WSFCNode2PrivateIP2,

    [Parameter(Mandatory = $true)]
    [string]$ClusterName,

    [Parameter(Mandatory = $true)]
    [string]$AdminSecret,

    [Parameter(Mandatory = $true)]
    [string]$StackName,

    [Parameter(Mandatory = $true)]
    [string]$DomainAdminUser,

    [Parameter(Mandatory = $true)]
    [string]$NodeName,

    [Parameter(Mandatory = $true)]
    [string]$NodeName2

)

try {
    Start-Transcript -Path C:\cfn\log\node1clusterconfig-part2.ps1.txt -Append
    $DomainNetBIOSName = 'ACCESS'
    #$DomainNetBIOSName = $env:USERDOMAIN
    $AdminGroup = 'BUILTIN\Administrators'
    # Creating Credential Object for Administrator
    $AdminUser = ConvertFrom-Json -InputObject (Get-SECSecretValue -SecretId $AdminSecret).SecretString
    $ClusterAdminUser = $DomainNetBIOSName + '\' + $AdminUser.username
    $Credentials = (New-Object PSCredential($ClusterAdminUser, (ConvertTo-SecureString $AdminUser.Password -AsPlainText -Force)))

    #https://docs.microsoft.com/en-us/sql/database-engine/install-windows/install-sql-server-from-the-command-prompt?view=sql-server-ver15

    $HostName = hostname

    Invoke-Command -scriptblock {

        param($ClusterName, $NodeName, $NodeName2, $WSFCNode1PrivateIP2, $WSFCNode2PrivateIP2)
        Cluster Node $NodeName  /ForceCleanup
        #Cluster Node 'blahblah' /ForceCleanup
        Cluster Node $NodeName2 /ForceCleanup
        New-Cluster -Name $ClusterName -Node $NodeName, $NodeName2 -StaticAddress $WSFCNode1PrivateIP2,$WSFCNode2PrivateIP2 -AdministrativeAccessPoint 'Dns' -NoStorage

    } -Credential $Credentials -ComputerName $HostName -Authentication credssp -ArgumentList $ClusterName, $NodeName, $NodeName2, $WSFCNode1PrivateIP2, $WSFCNode2PrivateIP2 -ErrorAction SilentlyContinue -ErrorVariable ProcessError

   If ($ProcessError) {
       
        Invoke-Command -scriptblock {

            param($ClusterName, $NodeName, $NodeName2, $WSFCNode1PrivateIP2, $WSFCNode2PrivateIP2)
            start-sleep 40
            Cluster Node $NodeName  /ForceCleanup
            Cluster Node $NodeName2 /ForceCleanup
            New-Cluster -Name $ClusterName -Node $NodeName, $NodeName2 -StaticAddress $WSFCNode1PrivateIP2,$WSFCNode2PrivateIP2 -AdministrativeAccessPoint 'Dns' -NoStorage

        } -Credential $Credentials -ComputerName $HostName -Authentication credssp -ArgumentList $ClusterName, $NodeName, $NodeName2, $WSFCNode1PrivateIP2, $WSFCNode2PrivateIP2 -ErrorAction Stop
    }
}
catch {

    $_ | Write-AWSLaunchWizardException

}