$uniqueIdentifier = Get-Date -Format "yyyyMMddHHmmss"
$fileShareName = "fs-$uniqueIdentifier"

$Uri = "https://theazures-func.azurewebsites.net/api/fileshare-function?code=yzWL3kZKOtqQGq0e0c6oNQWf45tbIIau7O1w3CXE4yp8AzFuqd70cQ=="
$Headers = @{
    "Content-Type" = "application/json"
}
$Body = @{
    fileShareName = $fileShareName
    firstName = "irene"
    lastName = "johnsson"
} | ConvertTo-Json -Compress

Invoke-RestMethod -Uri $Uri -Method Post -Headers $Headers -Body $Body