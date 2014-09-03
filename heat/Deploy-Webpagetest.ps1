#region Deployment of Web Page Test
Function Deploy-WebPagetest(){
    [CmdletBinding()]
    Param(
        [String]$DomainName = "localhost",
        [String]$Logfile = "C:\Windows\Temp\Deploy-WebPageTest.log",
        [String]$wpt_host =  $env:COMPUTERNAME,
        [String]$wpt_user = "webpagetest",
        [String]$wpt_password = "Passw0rd",
        [String]$driver_installer_file = "mindinst.exe",
        [String]$driver_installer_cert_file = "WPOFoundation.cer",
        [String]$wpt_agent_dir = "c:\wpt-agent",
        [String]$wpt_www_dir = "c:\wpt-www",
        [String]$wpt_temp_dir = "C:\wpt-temp"
    )
    #region Create Log File
    if (!( Test-Path $Logfile)){
        New-Item -Path "C:\Windows\Temp\Deploy-WebPageTest.log" -ItemType file
    }
    #endregion
    #region Write Log file
    Function WriteLog{
        Param ([string]$logstring)
        Add-content $Logfile -value $logstring
    }
    #endregion
    #region Variables
    $wpt_zip_url =  "https://github.com/WPO-Foundation/webpagetest/releases/download/WebPagetest-2.15/webpagetest_2.15.zip"
    $driver_installer_url = "http://9cecab0681d23f5b71fb-642758a7a3ed7927f3ce8478e9844e11.r45.cf5.rackcdn.com/mindinst.exe"
    $driver_installer_cert_url = "https://github.com/Linuturk/webpagetest/raw/master/webpagetest/powershell/WPOFoundation.cer"
    $wpi_msi_url = "http://download.microsoft.com/download/C/F/F/CFF3A0B8-99D4-41A2-AE1A-496C08BEB904/WebPlatformInstaller_amd64_en-US.msi"
    $vcpp_vc11_url = "http://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x86.exe"
    $apache_bin_url = "http://www.apachelounge.com/download/VC11/binaries/httpd-2.4.10-win32-VC11.zip"
    $php_bin_url = "http://windows.php.net/downloads/releases/php-5.4.32-Win32-VC9-x86.zip"
    $apache_conf_url = "https://gist.githubusercontent.com/hdansou/f55d1f148f8ee435e618/raw/8de1246c9922ce68d2d0ce45ac53af0d759e6ad4/httpd.conf" 
    $php_ini_url = "https://gist.githubusercontent.com/hdansou/fba02720b0b09f3d4a4d/raw/259120d5ccd1af3ac95f10a6b26121cd4ed068f5/php.ini"
    $wpt_zip_file = "webpagetest_2.15.zip"
    $wpi_msi_file = "WebPlatformInstaller_amd64_en-US.msi"
    $apache_bin_file = "httpd-2.4.10-win32-VC11.zip"
    $php_bin_file = "php-5.4.32-Win32-VC9-x86.zip"
    $vcpp_vc11_file = "vcredist_x86.exe"

    $webRoot = "$env:systemdrive\inetpub\wwwroot\"
    $webFolder = $webRoot + $DomainName
    $appPoolName = $DomainName
    $siteName = $DomainName
    $ftpName = "ftp_" + $DomainName
    $appPoolIdentity = "IIS AppPool\$appPoolName"
    #endregion


    function Set-WptFolders(){
    $wpt_folders = @($wpt_agent_dir,$wpt_www_dir,$wpt_temp_dir)
    foreach ($wpt_folder in $wpt_folders){
        New-Item $wpt_folder -type directory -Force > $null
    }
}
    function Download-File ($url, $localpath, $filename){
    if(!(Test-Path -Path $localpath)){
        New-Item $localpath -type directory > $null
    }
    Write-Output "[$(Get-Date)] Downloading $filename"
    $webclient = New-Object System.Net.WebClient;
    $webclient.DownloadFile($url, $localpath + "\" + $filename)
}
    function Unzip-File($fileName, $sourcePath, $destinationPath){
    Write-Output "[$(Get-Date)] Unzipping $filename to $destinationPath"
    $shell = new-object -com shell.application
    if (!(Test-Path "$sourcePath\$fileName")){
        throw "$sourcePath\$fileName does not exist"
    }
    New-Item -ItemType Directory -Force -Path $destinationPath -WarningAction SilentlyContinue
    $shell.namespace($destinationPath).copyhere($shell.namespace("$sourcePath\$fileName").items())
}
    function Install-MSI ($MsiPath, $MsiFile){
    $BuildArgs = @{
        FilePath = "msiexec"
        ArgumentList = "/quiet /passive /i " + $MsiPath + "\" + $MsiFile
        Wait = $true
    }
    Try {
        Write-Output "[$(Get-Date)] Installing $MsiFile"
        Start-Process @BuildArgs
    }
    Catch {
        throw "Error installing Web Platform Installer: $_"
    }
}
    function Replace-String ($filePath, $stringToReplace, $replaceWith){
    (get-content $filePath) | foreach-object {$_ -replace $stringToReplace, $replaceWith} | set-content $filePath
}
    function Set-WebPageTestUser ($Username, $Password){
    $Exists = [ADSI]::Exists("WinNT://./$Username")
    if ($Exists) {
        Write-Output "[$(Get-Date)] $Username user already exists."
    } Else {
        net user /add $Username
        net localgroup Administrators /add $Username
        $user = [ADSI]("WinNT://./$Username")
        $user.SetPassword($Password)
        $user.SetInfo()
        Write-Output "[$(Get-Date)] $Username created."
    }
}
    function Set-AutoLogon ($Username, $Password){
    $LogonPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    $CurrentVal = Get-ItemProperty -Path $LogonPath -Name AutoAdminLogon
    If ($CurrentVal.AutoAdminLogon -eq 1) {
        $CurrentUser = Get-ItemProperty -Path $LogonPath -Name DefaultUserName
        $CurrentPass = Get-ItemProperty -Path $LogonPath -Name DefaultPassword
        If ($CurrentUser.DefaultUserName -ne $Username -Or $CurrentPass.DefaultPassword -ne $Password) {
            Set-ItemProperty -Path $LogonPath -Name DefaultUserName -Value $Username
            Set-ItemProperty -Path $LogonPath -Name DefaultPassword -Value $Password
            Write-Output "[$(Get-Date)] Credentials Updated."
        }Else {
            Write-Output "[$(Get-Date)] AutoLogon already enabled."
        }
    }Else {
        Set-ItemProperty -Path $LogonPath -Name AutoAdminLogon -Value 1
        New-ItemProperty -Path $LogonPath -Name DefaultUserName -Value $Username
        New-ItemProperty -Path $LogonPath -Name DefaultPassword -Value $Password
        Write-Output "[$(Get-Date)] AutoLogon enabled."
    }
}
    function Set-DisableServerManager (){
    $CurrentState = Get-ScheduledTask -TaskName "ServerManager"
    If ($CurrentState.State -eq "Ready") {
        Get-ScheduledTask -TaskName "ServerManager" | Disable-ScheduledTask
        Write-Output "[$(Get-Date)] Server Manager disabled at logon."
    } Else {
        Write-Output "[$(Get-Date)] Server Manager already disabled at logon."
    }
}
    function Set-MonitorTimeout (){
    $CurrentVal = POWERCFG /QUERY SCHEME_BALANCED SUB_VIDEO VIDEOIDLE | Select-String -pattern "Current AC Power Setting Index:"
    If ($CurrentVal -like "*0x00000000*") {
        Write-Output "[$(Get-Date)] Display Timeout already set to Never."
    } Else {
        POWERCFG /CHANGE -monitor-timeout-ac 0
        Write-Output "[$(Get-Date)] Display Timeout set to Never."
    }
}
    function Set-DisableScreensaver (){
    $Path = 'HKCU:\Control Panel\Desktop'
    Try {
      $CurrentVal = Get-ItemProperty -Path $Path -Name ScreenSaveActive
      Write-Output "[$(Get-Date)] $CurrentVal"
    } Catch {
      $CurrentVal = False
    } Finally {
      if ($CurrentVal.ScreenSaveActive -ne 0) {
        Set-ItemProperty -Path $Path -Name ScreenSaveActive -Value 0
        Write-Output "[$(Get-Date)] Screensaver Disabled."
      } Else {
        Write-Output "[$(Get-Date)] Screensaver Already Disabled."
      }
    }
}
    function Set-DisableUAC (){
    $Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
    $CurrentVal = Get-ItemProperty -Path $Path -Name ConsentPromptBehaviorAdmin
    if ($CurrentVal.ConsentPromptBehaviorAdmin -ne 00000000) {
        Set-ItemProperty -Path $Path -Name "ConsentPromptBehaviorAdmin" -Value 00000000
        Write-Output "[$(Get-Date)] UAC Disabled."
    } Else {
        Write-Output "[$(Get-Date)] UAC Already Disabled."
    }
}
    function Set-DisableIESecurity (){
    $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    $CurrentVal = Get-ItemProperty -Path $AdminKey -Name "IsInstalled"
    if ($CurrentVal.IsInstalled -ne 0) {
        Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
        Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
        Write-Output "[$(Get-Date)] IE ESC Disabled."
    } Else {
        Write-Output "[$(Get-Date)] IE ESC Already Disabled."
    }
}
    function Set-StableClock (){
    $useplatformclock = bcdedit | Select-String -pattern "useplatformclock        Yes"
    if ($useplatformclock) {
        Write-Output "[$(Get-Date)] Platform Clock Already Enabled."
    } Else {
        bcdedit /set  useplatformclock true
        Write-Output "[$(Get-Date)] Platform Clock Enabled."
    }
}
    function Set-DisableShutdownTracker (){
    $Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Reliability'
    Try {
        $CurrentVal = Get-ItemProperty -Path $Path -Name ShutdownReasonUI
        Write-Output "[$(Get-Date)] $CurrentVal"
    } Catch {
        $CurrentVal = False
    } Finally {
        if ($CurrentVal.ShutdownReasonUI -ne 0) {
            New-ItemProperty -Path $Path -Name ShutdownReasonUI -Value 0
            Write-Output "[$(Get-Date)] Shutdown Tracker Disabled."
        }Else{
            Write-Output "[$(Get-Date)] Shutdown Tracker Already Disabled."
        }
    }
}
    Function Set-WebPageTestInstall ($tempDir,$AgentDir,$wwwDir){
    Copy-Item -Path $AgentDir\agent\* -Destination C:\wpt-agent -Recurse -Force
    Copy-Item -Path $AgentDir\www\* -Destination C:\wpt-www -Recurse -Force
}
    function Set-InstallAviSynth ($InstallDir){
    $Installed = Test-Path "C:\Program Files (x86)\AviSynth 2.5" -pathType container
    If ($Installed) {
        Write-Output "[$(Get-Date)] AviSynth already installed."
    } Else {
        & "$InstallDir\Avisynth_258.exe" /S
        Write-Output "[$(Get-Date)] AviSynth installed."
    }
}
    function Set-InstallDummyNet ($InstallDir){
    Download-File -url $driver_installer_url -localpath $InstallDir -filename $driver_installer_file
    Download-File -url $driver_installer_cert_url -localpath $InstallDir -filename $driver_installer_cert_file
    $testsigning = bcdedit | Select-String -pattern "testsigning Yes"
    if ($testsigning) {
        Write-Output "[$(Get-Date)] Test Signing Already Enabled."
    } Else {
        bcdedit /set TESTSIGNING ON
        Write-Output "[$(Get-Date)] Test Signing Enabled."
    }
    $dummynet = Get-NetAdapterBinding -Name public*
    if ($dummynet.ComponentID -eq "ipfw+dummynet"){
        If ($dummynet.Enabled ) {
            Write-Output "[$(Get-Date)] ipfw+dummynet binding on the public network adapter is already enabled."
        } Else {
            Enable-NetAdapterBinding -Name public0 -DisplayName ipfw+dummynet
            Disable-NetAdapterBinding -Name private0 -DisplayName ipfw+dummynet
        }
    }
    else{
        Write-Output "[$(Get-Date)]  $InstallDir\$driver_installer_cert_file"
        Import-Certificate -FilePath C:\wpt-agent\WPOFoundation.cer -CertStoreLocation Cert:\LocalMachine\TrustedPublisher
        cd $InstallDir
        .\mindinst.exe C:\wpt-agent\dummynet\64bit\netipfw.inf -i -s
        Enable-NetAdapterBinding -Name private0 -DisplayName ipfw+dummynet
        Write-Output "[$(Get-Date)] Enabled ipfw+dummynet binding on the private network adapter."
    }
}
    function Set-WebPageTestScheduledTask ($ThisHost, $User,$InstallDir){
    $GetTask = Get-ScheduledTask
    if ($GetTask.TaskName -match "wptdriver") {
        Write-Output "[$(Get-Date)] Task (wptdriver) already scheduled."
    } Else {
        $A = New-ScheduledTaskAction -Execute "$InstallDir\wptdriver.exe"
        $T = New-ScheduledTaskTrigger -AtLogon -User $User
        $S = New-ScheduledTaskSettingsSet
        $P = New-ScheduledTaskPrincipal -UserId "$ThisHost\$User" -LogonType ServiceAccount
        Register-ScheduledTask -TaskName "wptdriver" -Action $A -Trigger $T -Setting $S -Principal $P
        Write-Output "[$(Get-Date)] Task (wptdriver) scheduled."
    }
    $GetTask = Get-ScheduledTask
    if ($GetTask.TaskName -match "urlBlast") {
        Write-Output "[$(Get-Date)] Task (urlBlast) already scheduled."
    } Else {
        $A = New-ScheduledTaskAction -Execute "$InstallDir\urlBlast.exe"
        $T = New-ScheduledTaskTrigger -AtLogon -User $User
        $S = New-ScheduledTaskSettingsSet
        $P = New-ScheduledTaskPrincipal -UserId "$ThisHost\$User" -LogonType ServiceAccount
        Register-ScheduledTask -TaskName "urlBlast" -Action $A -Trigger $T -Setting $S -Principal $P
        Write-Output "[$(Get-Date)] Task (urlBlast) scheduled."
    }
}
    function Install-WebPlatformInstaller(){
    Write-Output "[$(Get-Date)] Installing Web Platform Installer."
    Download-File -url $wpi_msi_url -localpath $wpt_temp_dir -filename $wpi_msi_file
    Install-MSI -MsiPath $wpt_temp_dir -MsiFile $wpi_msi_file
}
    function Install-Apache (){
    Write-Output "[$(Get-Date)] Installing Apache."
    Download-File -url $vcpp_vc11_url -localpath $wpt_temp_dir -filename $vcpp_vc11_file
    Download-File -url $apache_bin_url -localpath $wpt_temp_dir -filename $apache_bin_file
    if ((Get-Service).Name -match "W3SVC"){
        Write-Output "[$(Get-Date)] IIS is present on this Server. Stoping and Disabling the service"
        Set-Service -Name W3SVC -StartupType Manual
        Stop-Service -Name W3SVC -Force
        Stop-Service -Name IISADMIN -Force
    }else{
        Write-Output "[$(Get-Date)] IIS is not present on this Server."
    }

    if ((Get-Service).Name -match "Apache2.4"){
        Write-Output "[$(Get-Date)] Apache is already installed and the service is configured."
    }else{
        & "$wpt_temp_dir\vcredist_x86.exe" /q /norestart
        Unzip-File -fileName $apache_bin_file -sourcePath $wpt_temp_dir -destinationPath $wpt_temp_dir
        Move-Item "$wpt_temp_dir\Apache24" "C:\Apache24" -Force

        $httpconf_path = 'C:\Apache24\conf\httpd.conf'
        $httpconf_old_servername = '^\#ServerName www\.example\.com\:80$'
        $httpconf_new_servername = "ServerName $($DomainName):80"
        Write-Output "[$(Get-Date)] The domain name is $DomainName."
        Replace-String -filePath $httpconf_path -stringToReplace $httpconf_old_servername -replaceWith $httpconf_new_servername
        
        #psEdit C:\Apache24\conf\httpd.conf
   
        #Write-Host "Check me out" -ForegroundColor DarkGreen
        & C:\Apache24\bin\httpd.exe -k install *> $null
        Start-Service -Name Apache2.4
    }
}
    function Install-PHP (){
    Write-Output "[$(Get-Date)] Installing PHP53."
    Download-File -url $php_bin_url -localpath $wpt_temp_dir -filename $php_bin_file
    Unzip-File -fileName $php_bin_file -sourcePath $wpt_temp_dir -destinationPath c:\php
    Download-File -url $php_ini_url -localpath $wpt_temp_dir -filename "php.ini"
    Copy-Item -Path $wpt_temp_dir\php.ini -Destination C:\php\ -Force
    Download-File -url $apache_conf_url -localpath $wpt_temp_dir -filename "httpd.conf"
    Copy-Item -Path C:\wpt-temp\httpd.conf -Destination C:\Apache24\conf\httpd.conf -Force
    Restart-Service -Name Apache2.4
}
    function Enable-WebServerFirewall(){
    write-host "[$(Get-Date)] Enabling port 80"
    netsh advfirewall firewall set rule group="World Wide Web Services (HTTP)" new enable=yes > $null
    write-host "[$(Get-Date)] Enabling port 443"
    netsh advfirewall firewall set rule group="Secure World Wide Web Services (HTTPS)" new enable=yes > $null
}
    function Clean-Deployment{
    #region Remove Automation initial firewall rule opener
    if((Test-Path -Path 'C:\Cloud-Automation')){
        Remove-Item -Path 'C:\Cloud-Automation' -Recurse > $null
    }
    #endregion
    #region Schedule Task to remove the Psexec firewall rule
    $DeletePsexec = {
        Remove-Item $MyINvocation.InvocationName
        $find_rule = netsh advfirewall firewall show rule "PSexec Port"
        if ($find_rule -notcontains 'No rules match the specified criteria.') {
            Write-Host "Deleting firewall rule"
            netsh advfirewall firewall delete rule name="PSexec Port" > $null
        }
    }
    $Cleaner = "C:\Windows\Temp\cleanup.ps1"
    Set-Content $Cleaner $DeletePsexec
    $ST_Username = "autoadmin"
    net user /add $ST_Username $FtpPassword
    net localgroup administrators $ST_Username /add
    $ST_Exec = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
    $ST_Arg = "-NoLogo -NonInteractive -WindowStyle Hidden -ExecutionPolicy ByPass C:\Windows\Temp\cleanup.ps1"
    $ST_A_Deploy_Cleaner = New-ScheduledTaskAction -Execute $ST_Exec -Argument $ST_Arg
    $ST_T_Deploy_Cleaner = New-ScheduledTaskTrigger -Once -At ((Get-date).AddMinutes(2))
    $ST_S_Deploy_Cleaner = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -WakeToRun -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances Parallel
    #$ST_ST_Deploy_Cleaner = New-ScheduledTask -Action $ST_A_Deploy_Cleaner -Trigger $ST_T_Deploy_Cleaner -Settings $ST_S_Deploy_Cleaner
    Register-ScheduledTask -TaskName "Clean Automation" -TaskPath \ -RunLevel Highest -Action $ST_A_Deploy_Cleaner -Trigger $ST_T_Deploy_Cleaner -Settings $ST_S_Deploy_Cleaner -User $ST_Username -Password $FtpPassword *>> $Logfile
    #endregion
}
    function Set-WptConfig (){
        Copy-Item -Path C:\wpt-www\settings\feeds.inc.sample -Destination C:\wpt-www\settings\feeds.inc -Force
        Copy-Item -Path C:\wpt-www\settings\locations.ini.sample -Destination C:\wpt-www\settings\locations.ini -Force
        Copy-Item -Path C:\wpt-www\settings\settings.ini.sample -Destination C:\wpt-www\settings\settings.ini -Force
        Copy-Item -Path C:\wpt-agent\urlBlast.ini.sample -Destination C:\wpt-agent\urlBlast.ini -Force
        Copy-Item -Path C:\wpt-agent\wptdriver.ini.sample -Destination C:\wpt-agent\wptdriver.ini -Force
    }
    function Set-ClosePort445 (){
    $CurrentVal = Get-NetFirewallRule
    if ($CurrentVal.InstanceID -match "PSexec Port" -and $CurrentVal.Enabled -eq "true") {
        Disable-NetFirewallRule -Name "PSexec Port"
        Write-Output "[$(Get-Date)] Port PSexec Port Disabled."
    } Elseif($CurrentVal.InstanceID -match "PSexec Port" -and $CurrentVal.Enabled -eq "false"){
        Write-Output "[$(Get-Date)] Port PSexec Port Already Disabled."
    }Else {
        Write-Output "[$(Get-Date)] Port PSexec Port rules does not exist."
    }
}

    #region => Main
    Set-WptFolders
    Download-File -url $wpt_zip_url -localpath $wpt_temp_dir -filename $wpt_zip_file
    Download-File -url $driver_installer_url -localpath $wpt_agent_dir -filename $driver_installer_file
    Download-File -url $driver_installer_cert_url -localpath $wpt_temp_dir -filename $driver_installer_cert_file
    Unzip-File -fileName $wpt_zip_file -sourcePath $wpt_temp_dir -destinationPath $wpt_agent_dir
    Set-WebPageTestUser -Username $wpt_user -Password $wpt_password
    Set-AutoLogon -Username $wpt_user -Password $wpt_password
    Set-DisableServerManager
    Set-MonitorTimeout
    Set-DisableScreensaver
    Set-DisableUAC
    Set-DisableIESecurity
    Set-StableClock
    Set-DisableShutdownTracker
    Set-WebPageTestInstall -tempDir $wpt_temp_dir -AgentDir $wpt_agent_dir
    Set-InstallAviSynth -InstallDir $wpt_agent_dir
    Set-InstallDummyNet -InstallDir $wpt_agent_dir
    Set-WebPageTestScheduledTask -ThisHost $wpt_host -User $wpt_user -InstallDir $wpt_agent_dir
    Install-WebPlatformInstaller
    Install-Apache
    Install-PHP
    Set-WptConfig
    Enable-WebServerFirewall
    #Clean-Deployment
    Set-ClosePort445
    #endregion
}
#endregion

#region MAIN : Deploy Web Pagge Test
#Delete myself from the filesystem during execution
#Remove-Item $MyINvocation.InvocationName

Deploy-WebPagetest
#Deploy-WebPagetest -DomainName "%%wptdomain" -wpt_user "%%wptusername" -wpt_password "%%wptpassword"
#endregion
