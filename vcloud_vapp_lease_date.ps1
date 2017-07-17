$username="username"
$usernameIS="username@is"

$password="PASSWORD"  

$headers = @{}
$headers.Add("Accept","application/*+xml;version=1.5")
$headers.Add("Authorization" , "Basic "+[System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($usernameIS+":"+$password )))

$api = "https://vcloud.russia.local/api" 
$url = "$api/sessions"

#Auth
$WebResponse = Invoke-WebRequest -Method POST -Uri $url -Headers $headers

if ($WebResponse.StatusCode-eq 200){
    Write-Host "Auth Successful"
    
    $url = "$api/vApps/query?filter=ownerName==$username"
    $headers = @{
        "Accept"="application/*+xml;version=5.5"
        "x-vcloud-authorization"=$WebResponse.Headers["x-vcloud-authorization"]
    };

    #Get vApp list
    $vAppsList = Invoke-WebRequest -Method Get -Uri $url -Headers $headers
    
    
    if ($vAppsList.StatusCode -eq 200)    {
        $vapps = ([xml]$vAppsList.Content).GetElementsByTagName("VAppRecord") 
        
        Write-Host $vapps.VAppRecord.count " vApps Found";
        Write-Host $vapps.VAppRecord.name 
        
        foreach ($vapp in $vapps) {
            $body = @'
<?xml version="1.0" encoding="UTF-8"?>
<vcloud:LeaseSettingsSection
    xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1"
    xmlns:vcloud="http://www.vmware.com/vcloud/v1.5"
        href="
'@ + $vapp.href + @'
/leaseSettingsSection/"
    ovf:required="false"
    type="application/vnd.vmware.vcloud.leaseSettingsSection+xml">
    <ovf:Info>Lease settings section</ovf:Info>
    <vcloud:Link
        href="
'@ + $vapp.href + @'
/leaseSettingsSection/"
        rel="edit"
        type="application/vnd.vmware.vcloud.leaseSettingsSection+xml"/>
    <vcloud:DeploymentLeaseInSeconds>1209600</vcloud:DeploymentLeaseInSeconds>
    <vcloud:StorageLeaseInSeconds>1209600</vcloud:StorageLeaseInSeconds>
</vcloud:LeaseSettingsSection>
'@;
          
            $url = $vapp.href + "/leaseSettingsSection/";
            $headers = @{
                "Accept"="application/*+xml;version=5.5";
                "x-vcloud-authorization"=$WebResponse.Headers["x-vcloud-authorization"];
                "Content-Type"="application/vnd.vmware.vcloud.leaseSettingsSection+xml; charset=ISO-8859-1"
            };

            #Update
            $result = Invoke-WebRequest -Method Put -Uri $url -Headers $headers -Body $body
            if ($result.StatusCode-eq 202){
                Write-Host "Successfully updated  ",$vapp.name, "!!!"
            }Else {
                Write-Host $result.StatusCode
            }
        }
    }
}