$result = Get-Content -Path "C:\Scripts\Cert.txt"
 Set-Content C:\Scripts\User.txt -Value $(whoami)
###
# MHS-PBX
#    FreePBX
#    Uses SSH! Check OneNote For Setup!
###

$MHS_PBX_Session = New-PSSession root@PBX.MHS.LAN -SSHTransport -IdentityFilePath "C:\Scripts\FreePBX.ppk"
Copy-Item -Path $result -ToSession $MHS_PBX_Session -Destination "/tmp/Cert.pfx" -Force
Invoke-Command -Session $MHS_PBX_Session -ScriptBlock { 
     
    Invoke-Expression "openssl pkcs12 -in /tmp/Cert.pfx -nocerts -nodes -out /etc/asterisk/keys/mairehau.key -password pass: -passout pass: >/dev/null 2>&1"
    Invoke-Expression "openssl pkcs12 -in /tmp/Cert.pfx -out /etc/asterisk/keys/mairehau.crt -nodes -password pass: >/dev/null 2>&1" 
    Invoke-Expression "fwconsole certificate --import >/dev/null 2>&1"
    Invoke-Expression "fwconsole certificate --default=1 >/dev/null 2>&1"

    Copy-Item -Path "/etc/asterisk/keys/mairehau.key" -Destination "/etc/httpd/pki/webserver.key"
    Copy-Item -Path "/etc/asterisk/keys/mairehau.crt" -Destination "/etc/httpd/pki/webserver.crt"
    
    Invoke-Expression "systemctl restart httpd"
}

Remove-Item -Force -Path "C:\Scripts\Cert.txt"