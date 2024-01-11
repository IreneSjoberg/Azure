$uniqueIdentifier = Get-Date -Format "yyyyMMddHHmmss"
$Containername = "fs-$uniqueIdentifier"

$Uri = "https://theazures-func.azurewebsites.net/api/SFTP-function?code=Oq2W-LvF2b9u4dqp-OFDUs8YYIjNKi6bHHdTLRjDBS-SAzFuqfxEDA=="
$Headers = @{
    "Content-Type" = "application/json"
}
$Body = @{
    Containername = $Containername
    Username = "john4"
    FirstName = "irene"
    LastName = "Sjöberg"
    Company = "johnnys"
} | ConvertTo-Json -Compress

Invoke-RestMethod -Uri $Uri -Method Post -Headers $Headers -Body $Body