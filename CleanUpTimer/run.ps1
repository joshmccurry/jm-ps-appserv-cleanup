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


function Get-PublishProfile($slotname, $webapp, $resourcegroupname){
    if($slotname -eq ""){
        return [xml]$pub_profile = Get-AzWebAppPublishingProfile -Name $webapp -ResourceGroupName $resourcegroupname
    }else{
        return [xml]$pub_profile = Get-AzWebAppSlotPublishingProfile -Name $webapp -Slot $slotname -ResourceGroupName $resourcegroupname
    }
}

function Remove-KuduLogFiles($slotname, $appName, $pub_profile){
    if ($slotname -eq ""){
        $apiUrl = "https://$appName.scm.azurewebsites.net/api/command"
    }else{
        $apiUrl = "https://$appName`-$slotname.scm.azurewebsites.net/api/command"
    }

    $_profile = $pub_profile.publishData.publishProfile | Where-Object publishMethod -eq "ZipDeploy"
    $password = ConvertTo-SecureString –String $_profile.userPWD -AsPlainText -Force
    $credential = New-Object –TypeName "System.Management.Automation.PSCredential" -ArgumentList $_profile.userName, $password
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $_profile.userName,$password)))

    $apiCommand = @{
        command = 'powershell.exe -command "Remove-Item -path d:\\home\\LogFiles\\* -recurse"'
        dir='d:\\home\\LogFiles'
    }
    Invoke-RestMethod -Method 'POST' -Uri $apiUrl -Headers @{Authorization = "Basic $base64AuthInfo" }`
     -Credential $credential -ContentType "application/json" -Body (ConvertTo-Json $apiCommand) -Verbose;
    
}

$appserviceplans = Get-AzAppServicePlan; 
#Get all plans as an array
foreach($plan in $appserviceplans){
    $webapps = (Get-AzWebApp -ResourceGroupName $plan.ResourceGroup | Where-Object {$_.ServerFarmId -ilike "*$plan"}).Name; 
    #Get all apps in plan
    foreach($app in $webapps){
        $slots = Get-AzWebAppSlot -ResourceGroupName $plan.ResourceGroup -Name $app.Name;
        #Get all slots for App
        foreach($slot in $slots){
            $_pub_profile = Get-PublishProfile($slot.Name, $app, $plan.ResourceGroup);
            Remove-KuduLogFiles($slot.Name, $app.Name, $_pub_profile);
        }
        $_pub_profile = Get-PublishProfile("", $app.Name, $plan.ResourceGroup);
        Remove-KuduLogFiles("",$app.Name, $_pub_profile);
    }
}