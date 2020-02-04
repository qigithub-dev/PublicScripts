
<#
        .LINK  
        
        .DESCRIPTION
            Installs Dell Command Update if not installed
            Update Dell drivers using the Dell Command Update.
        
        .NOTES
           ===========================================================================
            Created with:   Visual Studio Code
            Created on:     12/3/2018
            Created by:     Dave Klatka
            Organization:   Quality IP
            Filename:       DellCommandUpdate.ps1

            Revisions:      Creation Date:  12/3/2018 v1.0.0

                            Update Date:    12/3/2018  v1.0.1
                            Purpose/Change: added Log reporting

                            Update Date:    12/4/2018  v1.0.2
                            urpose/Change: debugged Log reporting
           ===========================================================================
 #>

Function Set-DellCommandexe {
    if ($null -ne (Get-ChildItem 'C:\Program Files (x86)\Dell\CommandUpdate\dcu-cli.exe' -ErrorAction SilentlyContinue)) {
        $Script:Executable = "C:\Program Files (x86)\Dell\CommandUpdate\dcu-cli.exe"
    }
    elseif ($null -ne (Get-ChildItem 'C:\Program Files\Dell\CommandUpdate\dcu-cli.exe' -ErrorAction SilentlyContinue)) {
        $Script:Executable = "C:\Program Files\Dell\CommandUpdate\dcu-cli.exe"
    }
    else {
        $Script:Executable = ""
    }
}
Function Install-DellCommand { 
    Remove-DellCommand

    if (!(Test-Path $env:ProgramData\chocolatey\bin\choco.exe -ErrorAction SilentlyContinue)) {
        New-Item $env:ALLUSERSPROFILE\choco-cache -ItemType Directory -Force 
        $env:TEMP = "$env:ALLUSERSPROFILE\choco-cache" 
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString("https://qi-host.nyc3.digitaloceanspaces.com/AutoMate/Software/Chocolatey/Chocolatey.ps1"))
        Start-Sleep -Seconds 30
    }
    Start-Process -filepath C:\ProgramData\chocolatey\choco.exe -argumentlist "Install DellCommandUpdate -ignore-checksums -y" -wait
    Set-DellCommandexe
}

Function Remove-DellCommand {
    $WinVersion = ([System.Environment]::OSVersion.Version).Major
    if ($WinVersion -eq "10") {
        if ((Get-AppxPackage | Where-Object { $_.name -eq "dellInc.Dellcommandupdate" } | Select-Object name -expandproperty name) -eq "DellInc.DellCommandUpdate") {
            Get-AppxPackage | Where-Object { $_.name -eq "dellInc.Dellcommandupdate" } | Remove-AppxPackage
        }
    }

    $array = @()
    $UninstallKey = "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall" 
    $reg = [microsoft.win32.registrykey]::OpenRemoteBaseKey('LocalMachine', $env:COMPUTERNAME) 
    $regkey = $reg.OpenSubKey($UninstallKey) 
    $subkeys = $regkey.GetSubKeyNames() 
    foreach ($key in $subkeys) {

        $thisKey = $UninstallKey + "\\" + $key 
        $thisSubKey = $reg.OpenSubKey($thisKey) 
        $obj = New-Object PSObject
        $obj | Add-Member -MemberType NoteProperty -Name "DisplayName" -Value $($thisSubKey.GetValue("DisplayName"))
        $obj | Add-Member -MemberType NoteProperty -Name "DisplayVersion" -Value $($thisSubKey.GetValue("DisplayVersion"))
        $obj | Add-Member -MemberType NoteProperty -Name "InstallLocation" -Value $($thisSubKey.GetValue("InstallLocation"))
        $obj | Add-Member -MemberType NoteProperty -Name "Publisher" -Value $($thisSubKey.GetValue("Publisher"))
        $obj | Add-Member -MemberType NoteProperty -Name "SilentUninstall" -Value $($thisSubKey.GetValue("QuietUninstallString"))
        $obj | Add-Member -MemberType NoteProperty -Name "UninstallString" -Value $($thisSubKey.GetValue("UninstallString"))
        $array += $obj
    }
    $uninstaller = $array | Where-Object { $_.DisplayName -like "Dell Command | Update*" } | Select-Object UninstallString -ExpandProperty UninstallString
    if (($array | Where-Object { $_.DisplayName -like "Dell Command | Update*" } | Select-Object DisplayVersion -ExpandProperty DisplayVersion) -like "3*") {
        $Uninstaller = $uninstaller.split(" ")
        $param = $uninstaller[1], "/qn", "/norestart"
        
        Write-Output "---Removing Command 3.0 Win 10 config----"
        Start-Process $uninstaller[0] -argumentList $param -NoNewWindow
        Wait-Process -name msiexec -Timeout 300 -ErrorAction SilentlyContinue
    }
}

function Invoke-DellDriverUpdate {
    $Log = "$ScriptPath\logs\DellCommandUpdate.log"
    if (Test-Path -path $Log) {
        Remove-Item -Path $Log
    }
    $Arguments = "&""$Executable"" /applyUpdates"

    start-process powershell -ArgumentList "-executionpolicy bypass -command $Arguments" -NoNewWindow;

    #start-process -FilePath 'powershell' -ArgumentList $Arguments -NoNewWindow
    start-sleep -Seconds 1
} 

if ((get-wmiobject win32_computersystem).Manufacturer -match 'Dell') {
    #$RunLog = "$ScriptPath\logs\DellCommand\ActivityLog.xml"
    Set-DellCommandexe
    if ($Executable.length -le 0) {
        Install-DellCommand
        Invoke-DellDriverUpdate
    }
    else {
        ((Get-ItemProperty $Executable).VersionInfo.productVersion) -match '(3\.1)\.'
        if ($matches[1] -lt 3.1) {
            Install-DellCommand
        }
        Invoke-DellDriverUpdate
    }
}
else {
    Update-LogBox "Dell Hardware Not Detected"
}