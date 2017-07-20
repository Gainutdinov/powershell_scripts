function WaitBar {
param ($lap)
for ($i; $i -le $lap;$i++)
    {
    start-sleep -s 1
    Write-Progress -Activity "Waiting..." -Status "Seconds elapsed $i" -PercentComplete ($i/$lap*100)
    }
}

$host.ui.RawUI.WindowTitle = "...::: User Lockout Monitoring :::..."

#Import-Module ActiveDirectory -ErrorAction Stop
Add-PSSnapin Quest.ActiveRoles.ADManagement
#$PSDefaultParameterValues = @{"*-AD*:Server"='xxxxxxxxx'}
Connect-QADService xxxxxxxxxxx|Out-Null  

$acc_domain = 'COMPANY'

#Send email, paste necessary email addresses

[string[]]$email_To  = [IO.File]::ReadAllText(($env:USERPROFILE)+"\Desktop\CopyThisFolderToYourDesktop\recepient.txt")
[string[]]$email_Cc  = ''
[string[]]$email_Bcc = ''

while($true) 
{
    $DCCounter = 0 
    $LockedOutStats = @()
    $timer = 300
    cls
    while ($true)
    {
        $logon_id = Read-Host "Logon Id"
        if ($logon_id -ne "") 
            {
            $TUser = get-qaduser -SamAccountName $logon_id
	        if ($TUser -eq $null)
	            {
		            Write-host "   User not found" -ForegroundColor red
                    pause
                    continue   
	            }
	        if ($TUser.count -gt 1)
	            {	
		            Write-host "   Multiple users found. Check manually" -ForegroundColor red
                    pause
                    continue
	            }
            write-host "Logon Id succesfully found in AD"
            pause
            break
            }
    }

    while (!$(Get-QADUser -Identity $logon_id).AccountIsLockedOut)
    {
        #we will wait and check account every $timer seconds       
        Get-Date
        write-host "waiting for the next $timer seconds..." 
        #start-sleep -s $timer
        WaitBar -lap $timer 
    }

    $DomainControllers = Get-ADDomainController -Filter *
    $PDCEmulator = ($DomainControllers | Where-Object {$_.OperationMasterRoles -contains "PDCEmulator"})
    $UserInfo = Get-ADUser -Identity $logon_id  -Server $PDCEmulator.Hostname -Properties AccountLockoutTime -ErrorAction Stop
    $LockoutTime=[datetime]$UserInfo.AccountLockoutTime
    $CurrentTime=(GET-DATE)
    

    #Get all domain controllers in domain        
    Foreach($DC in $DomainControllers)
        {
        #$DCCounter++
        #Write-Progress -Activity "Contacting DCs for lockout info" -Status "Querying $($DC.Hostname)" -PercentComplete (($DCCounter/$DomainControllers.Count) * 100)
        Try
            {
            $UserInfo = Get-ADUser -Identity $logon_id  -Server $DC.Hostname -Properties AccountLockoutTime,LastBadPasswordAttempt,BadPwdCount,LockedOut -ErrorAction Stop
            }
        Catch
            {
            Write-Warning $_
            Continue
            }
        If($UserInfo.LastBadPasswordAttempt)
            {    
            $LockedOutStats += New-Object -TypeName PSObject -Property @{
                    Name                   = $UserInfo.SamAccountName
                    SID                    = $UserInfo.SID.Value
                    LockedOut              = $UserInfo.LockedOut
                    BadPwdCount            = $UserInfo.BadPwdCount
                    BadPasswordTime        = $UserInfo.BadPasswordTime            
                    DomainController       = $DC.Hostname
                    AccountLockoutTime     = $UserInfo.AccountLockoutTime
                    LastBadPasswordAttempt = ($UserInfo.LastBadPasswordAttempt).ToLocalTime()
                }          
            }#end if
        }#end foreach DCs
    $file_name = $logon_id + '_' + (Get-Date -Format "yyyy-MMM-d HH-m-s") + '.txt'
    $current_path = ($env:USERPROFILE) + '\Desktop\CopyThisFolderToYourDesktop\LockOutLogs'
    New-Item ($current_path + '\' + $file_name) -type file | Out-Null
    $LockedOutStats | Format-Table -Property Name,LockedOut,DomainController,BadPwdCount,AccountLockoutTime,LastBadPasswordAttempt -AutoSize
    $LockedOutStats | Format-Table -Property Name,LockedOut,DomainController,BadPwdCount,AccountLockoutTime,LastBadPasswordAttempt -AutoSize | Out-File ($current_path + '\' + $file_name) -Width 120
    $logon_id + '_' + (Get-Date -Format "yyyy-MMM-d HH-m-s")
    $temp = """    
        Hi Team,
    Please be informed that account $logon_id was locked out. 
        PSA
        Kind Regards"""

    Send-MailMessage -SmtpServer "SmtpServer.orgname.co.org" -To $email_To   -from "Your@mail.com" -subject "User $logon_id was locked out" -Body $temp -Attachments ($current_path + '\' + $file_name)

    write-Host "
        Email was sent to $email_To
        Account " -nonewline; Write-Host "$logon_id"  -foregroundcolor black -backgroundcolor yellow -nonewline;
        Write-Host " was locked out
        PSA in email or in a log file $file_name"

    pause

}