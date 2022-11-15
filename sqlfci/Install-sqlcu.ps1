<#
        .SYNOPSIS
        Installs SQL Cumulative Update

        .DESCRIPTION
        -Installs and updates SQL to the latest CU. The CU' are downloaded from the following S3 bucket
        https://s3.amazonaws.com/sqlspandcu/
        - The script looks at the S3 bucket based on the version of SQL installed on the machine and downloads the file from the "LATEST" folder.

        .EXAMPLE
        Install-Sqlcu.ps1
#>
#-----------------------------------------------------
#MAIN
#-----------------------------------------------------
 # Setting up working directory
    $ErrorActionPreference = "Stop"
    Start-Transcript -Path 'C:\cfn\log\installsqlcu.ps1.txt' -Append
    if (test-path C:\cfn\sqlspcu\state.txt)
    {
        remove-item C:\cfn\sqlspcu\state.txt -Force
    }

    #Getting the SQL Version to set CU path
    $inst = (get-itemproperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server').InstalledInstances
    $path = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL').$inst
    $ver=(Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$path\Setup").Version
    if ($ver.Split(".")[0] -eq 13)
    {
        $workingdirectory = "C:\cfn\sqlspcu\13"
        $cufilename = 'sql2016sp2cu16.exe'
    }
    elseif ($ver.Split(".")[0] -eq 14)
    {
        $workingdirectory = "C:\cfn\sqlspcu\14"
        $cufilename = 'sql2017cu28.exe'
    }
    elseif ($ver.Split(".")[0] -eq 15)
    {
        $workingdirectory = "C:\cfn\sqlspcu\15"
        $cufilename = 'sql2019cu14.exe'
    }
    else
    {
        Write-output "SQL Server CU not applicable"
    }

    $statefile = New-Item -Path $workingdirectory -ItemType "File" -Name "state.txt" -Value 0

    $targetdirectory = Join-Path $workingDirectory $cufilename
    # Read file version
    $cufile = Get-Item $targetdirectory
        try
        {
            $arguments = "/Q /IAcceptSQLServerLicenseTerms /Action=Patch /AllInstances"
            Start-Process -FilePath $cufile.FullName -ArgumentList $arguments -Wait -NoNewWindow -WorkingDirectory $workingDirectory
            # Check CU version post install
        }
        catch
        {
            $_ | Write-AWSLaunchWizardException
        }
    if ((get-content $statefile) -eq 1)
    {
        remove-item $workingdirectory -Recurse -Force
    }
