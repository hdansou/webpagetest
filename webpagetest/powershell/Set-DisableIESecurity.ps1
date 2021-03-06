$AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
$UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"

$CurrentVal = Get-ItemProperty -Path $AdminKey -Name "IsInstalled"

if ($CurrentVal.IsInstalled -ne 0) {
  Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
  Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
  Write-Output "changed=yes comment='IE ESC Disabled.'"
} Else {
  Write-Output "changed=no comment='IE ESC Already Disabled.'"
}
