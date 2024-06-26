param($result)  

$Data = $result
$Password = ConvertTo-SecureString -String "PASSWORD" -AsPlainText -Force
$Credentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "USER", $Password

###
#
# MHS-DC
#    RADIUS / N.P.S (Check OneNote)
###
Import-PfxCertificate -CertStoreLocation "Cert:\LocalMachine\My" -FilePath $Data.ManagedItem.CertificatePath
[XML]$IASConfigurationFile = Get-Content ([Environment]::ExpandEnvironmentVariables("%SystemRoot%\System32\IAS\IAS.XML"))
$MHS_Staff = $IASConfigurationFile.SelectSingleNode("//RadiusProfiles//*[@name='MHS-Staff']")
$MHS_Staff.Properties.msEAPConfiguration.InnerText = $MHS_Staff.Properties.msEAPConfiguration.InnerText.Substring(0, 72) + $Data.ManagedItem.CertificateThumbprintHash.ToLower() + $MHS_Staff.Properties.msEAPConfiguration.InnerText.Substring(112)

$MHS_Student = $IASConfigurationFile.SelectSingleNode("//RadiusProfiles//*[@name='MHS-Student']")
$MHS_Student.Properties.msEAPConfiguration.InnerText = $MHS_Student.Properties.msEAPConfiguration.InnerText.Substring(0, 72) + $Data.ManagedItem.CertificateThumbprintHash.ToLower() + $MHS_Student.Properties.msEAPConfiguration.InnerText.Substring(112) 

$IASConfigurationFile.Save([Environment]::ExpandEnvironmentVariables("%SystemRoot%\System32\IAS\IAS.XML"))

Restart-Service -Name "IAS"

###
# MHS-Server
#    All IIS Websites
###
$MHS_Server_PSSession = New-PSSession -ComputerName "MHS-Server.MHS.LAN" -Credential $Credentials
Copy-Item -Path $Data.ManagedItem.CertificatePath -ToSession $MHS_Server_PSSession -Destination "C:\Windows\Temp\Cert.pfx"
Invoke-Command -Session $MHS_Server_PSSession -ScriptBlock {
    Import-PfxCertificate -CertStoreLocation "Cert:\LocalMachine\My" -FilePath "C:\Windows\Temp\Cert.pfx" | Out-Null
    

    Get-WebBinding -Protocol "https" -Port 443 | ForEach-Object {
        $_.AddSslCertificate((Get-PfxCertificate -FilePath "C:\Windows\Temp\Cert.pfx").Thumbprint, "My")
    }

    Restart-Service "W3SVC" 

    Remove-Item -Path "C:\Windows\Temp\Cert.pfx" -Force
}

###
# MHS-LIB
#    AccessIT
###
$MHS_Lib_PSSession = New-PSSession -ComputerName "MHS-Lib.MHS.LAN" -Credential $Credentials
Copy-Item -Path $Data.ManagedItem.CertificatePath -ToSession $MHS_Lib_PSSession -Destination "C:\Windows\Temp\Cert.pfx"
Invoke-Command -Session $MHS_Lib_PSSession -ScriptBlock {
    
    Import-PfxCertificate -CertStoreLocation "Cert:\LocalMachine\My" -FilePath "C:\Windows\Temp\Cert.pfx" -Exportable | Out-Null
    
    $AccessITPassword = ConvertTo-SecureString -String "PASSWORD" -AsPlainText -Force
    $AccessITCert = Get-ChildItem -Path "Cert:\LocalMachine\My" | Where-Object { $_.Thumbprint -eq (Get-PfxCertificate -FilePath "C:\Windows\Temp\Cert.pfx").Thumbprint }
    
    Export-PfxCertificate -Cert $AccessITCert -Password $AccessITPassword -FilePath "C:\Program Files\Access-It Software\Accessit\tomee\conf\library.pfx" | Out-Null
    
    Restart-Service "AccessItTomEE"

    Remove-Item -Path "C:\Windows\Temp\Cert.pfx" -Force
}

###
# MHS-Media
#    Jellyfin
###
$MHS_Media_PSSession = New-PSSession -ComputerName "MHS-MEDIA.MHS.LAN" -Credential $Credentials
Copy-Item -Path $Data.ManagedItem.CertificatePath -ToSession $MHS_Media_PSSession -Destination "C:\Program Files\Jellyfin\Server\Cert.pfx" -Force
Invoke-Command -Session $MHS_Media_PSSession -ScriptBlock { 
   Restart-Service "JellyfinServer"
}

###
# MHS-KAMAR
#    FileMaker Pro
###
$MHS_KAMAR_PSSession = New-PSSession -ComputerName "MHS-Kamar.mhs.lan" -Credential $Credentials
Copy-Item -Path $Data.ManagedItem.CertificatePath -ToSession $MHS_KAMAR_PSSession -Destination "C:\Windows\Temp\Cert.pfx" -Force
Invoke-Command -Session $MHS_KAMAR_PSSession -ScriptBlock {
    Start-Process -FilePath "openssl" -ArgumentList "pkcs12 -in C:\Windows\Temp\Cert.pfx -nocerts -legacy -out C:\Windows\Temp\mairehau.key -password pass: -passout pass:" 
   Start-Process -FilePath "openssl" -ArgumentList "pkcs12 -in C:\Windows\Temp\Cert.pfx -clcerts -nokeys -legacy -out C:\Windows\Temp\mairehau.crt -password pass: -passout pass:"

   Remove-Item "C:\Windows\Temp\Cert.pfx" -Force
    
    Start-Process -FilePath "fmsadmin" -ArgumentList "certificate import C:\Windows\Temp\mairehau.crt --keyfile C:\Windows\Temp\mairehau.key -y -u  -p " 
   # Start-Process -FilePath "fmsadmin" -ArgumentList "restart server -y -u  -p " -Wait
    Start-Sleep -Seconds 30 #Just to ensure that it has indeed restarted before opening the db.
  # Start-Process -FilePath "fmsadmin" -ArgumentList "open -y -u  -p "
 }



###
# MHS-PBX
#    FreePBX
#    Uses SSH! Check OneNote For Setup!
#    We Use A Seperate Task in Certify!
###
Set-Content -Path "C:\Scripts\Cert.txt" -Value $Data.ManagedItem.CertificatePath


Remove-PSSession -Session $MHS_Server_PSSession
Remove-PSSession -Session $MHS_Lib_PSSession
Remove-PSSession -Session $MHS_Media_PSSession
Remove-PSSession -Session $MHS_KAMAR_PSSession