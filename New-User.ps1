#####
###
### New User Script
### 
### Create Home Folder / Set Permissions
### Email Johnathon That It Completed.
###
#####


$Users = Get-ADUser -Filter * -SearchBase "OU=Students,OU=KAMAR,DC=mhs,DC=lan" -Properties HomeDirectory, DisplayName
$Log = New-Object System.Collections.Generic.List[string]

foreach($Student in $Users)
{
    if($Student.DistinguishedName -NotLike "*OU=Left*")
    {
        if((Test-Path ("\\MHS-Server\Student\"+$Student.SamAccountName)) -eq $false)
        {
            $Log.Add("Made '"+$Student.SamAccountName+"' a home folder.")
            New-Item -Path ("\\MHS-Server\Student\"+$Student.SamAccountName) -ItemType Directory
            $Permissions = New-Object System.Security.AccessControl.FileSystemAccessRule($Student.SamAccountName,"FullControl","ContainerInherit,ObjectInherit","None","Allow")
            $Acl = Get-Acl ("\\MHS-Server\Student\"+$Student.SamAccountName)
            $Acl.SetAccessRule($Permissions)
            $Acl | Set-Acl ("\\MHS-Server\Student\"+$Student.SamAccountName)
        }
    }
}
if($Log.Count -eq 0)
{
    $Log.Add("No Folders Created.")
}

Send-MailMessage -From "SVC_TASKS@mairehau.school.nz" -Body ($Log | Out-String) -To "markhamJ@Mairehau.school.nz" -SmtpServer "smtp.n4l.co.nz" -Subject "H Drive Creation Log"