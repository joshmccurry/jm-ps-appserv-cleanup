# Input bindings are passed in via param block.
param($Timer)

# Get the current universal time in the default string format
$currentUTCtime = (Get-Date).ToUniversalTime()

# The 'IsPastDue' porperty is 'true' when the current function invocation is later than scheduled.
if ($Timer.IsPastDue) {
    Write-Host "PowerShell timer is running late!"
}

# Write an information log with the current time.
Write-Host "PowerShell timer trigger function ran! TIME: $currentUTCtime"

$webapps = Get-AzWebApp; 
#Get all apps in plan
foreach($app in $webapps){
    $webappName = $app.Name;
    Write-Host "Removing Log Files from AppName: $webappName";
    $slots = Get-AzWebAppSlot -ResourceGroupName $app.ResourceGroup -Name $app.Name;
    #Get all slots for App
    foreach($slot in $slots){
        $slotName = ($slot.Name -split '/')[1];
        Write-Host "Getting Publish Profile for $slotName";
        [xml]$pub_profile = Get-AzWebAppSlotPublishingProfile -Name $app.Name -Slot $slotName -ResourceGroupName $app.ResourceGroup
        $_profile = $pub_profile.publishData.publishProfile | Where-Object publishMethod -eq "ZipDeploy"
        $password = ConvertTo-SecureString –String $_profile.userPWD -AsPlainText -Force
        $credential = New-Object –TypeName "System.Management.Automation.PSCredential" -ArgumentList $_profile.userName, $password
        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $_profile.userName,$password)))
        
        Write-Host "Removing Log Files from slot: $slotName";
        $apiUrl = "https://$webappName-$slotname.scm.azurewebsites.net/api/command"
        $apiCommand = @{
            command = 'powershell.exe -command "Get-ChildItem -Path d:\\home\\LogFiles\\Application\\* -Recurse -File | Where LastWriteTime  -lt  (Get-Date).AddDays(-60) | Remove-Item -Force"'
            dir='d:\\home\\LogFiles'
        }
        Write-Host "Sending Command to $apiUrl";
        $response = Invoke-RestMethod -Method 'POST' -Uri $apiUrl -Headers @{Authorization = "Basic $base64AuthInfo" }`
        -Credential $credential -ContentType "application/json" -Body (ConvertTo-Json $apiCommand) -Verbose;
        Write-Host $response;
    }

    Write-Host "Getting Publish Profile for $webappName";
    [xml]$pub_profile = Get-AzWebAppPublishingProfile -Name $app.Name -ResourceGroupName $app.ResourceGroup
    $_profile = $pub_profile.publishData.publishProfile | Where-Object publishMethod -eq "ZipDeploy"
    $password = ConvertTo-SecureString –String $_profile.userPWD -AsPlainText -Force
    $credential = New-Object –TypeName "System.Management.Automation.PSCredential" -ArgumentList $_profile.userName, $password
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $_profile.userName,$password)))

    $apiUrl = "https://$webappName.scm.azurewebsites.net/api/command";
    $apiCommand = @{
        command = 'powershell.exe -command "Get-ChildItem -Path d:\\home\\LogFiles\\Application\\* -Recurse -File | Where LastWriteTime  -lt  (Get-Date).AddDays(-60) | Remove-Item -Force"'
        dir='d:\\home\\LogFiles\\Application'
    }
    Write-Host "Sending Command to $apiUrl";
    $response = Invoke-RestMethod -Method 'POST' -Uri $apiUrl -Headers @{Authorization = "Basic $base64AuthInfo" }`
     -Credential $credential -ContentType "application/json" -Body (ConvertTo-Json $apiCommand) -Verbose;
    Write-Host $response;
}