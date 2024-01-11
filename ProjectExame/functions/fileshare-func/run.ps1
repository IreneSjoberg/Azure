using namespace System.Net

# Input bindings are passed in via param block.
param($Request)

# Write to the Azure Functions log stream.
$Message = "PowerShell HTTP trigger function processed a request."
Write-Output $Message

# Parse the request body and extract parameters
$requestBody = $Request.Body
$parameters = @("FileShareName", "FirstName", "LastName")
# Add a CreationDate property with the current date and time
$requestBody.CreationDate = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"

# Access values from environment variables
$storageAccountName = $env:StorageAccountName
$resourceGroupName = $env:ResourceGroupName

# Initialize a flag variable to track missing parameters
$missingParameter = $false

foreach ($param in $parameters) {

    if (-not $requestBody.$param) {       
        $body += "Missing $($param) input `n"

        # Set the flag to true if any parameter is missing
        $missingParameter = $true
    }
}

# Check if any parameter is missing and exit if true
if ($missingParameter) {
    # Write to the Azure Functions log stream.
    $Message = "Request body invalid"
    Write-Output $Message

    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::BadRequest
        Body = "`n" + $body
    })
}

# All parameters are valid, continue with the rest of the code
else {
    try {
        # Write to the Azure Functions log stream
        $Message = "Received user input: FirstName = '$($requestBody.FirstName)', '$($requestBody.LastName)'"
        Write-Output $Message

        # Connect AzAccount
        Connect-AzAccount -Identity

        # Fetch Azure StorageAccount Context from PS object
        $storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -AccountName $storageAccountName

        # Create a new file share
        New-AzStorageShare -Name $requestBody.FileShareName -Context $storageAccount.Context -ErrorAction Stop

        # Respond with a success message
        $Body = "This HTTP triggered function executed successfully.`nFile share $($requestBody.FileShareName) created in $($storageAccountName) successfully for $($requestBody.FirstName) $($requestBody.LastName)."
                
        # Generate the Share URL based on your storage account and file share name
        $shareUrl = "https://$($storageAccountName).file.core.windows.net/$($requestBody.FileShareName)"
        
        # Write success message to the log stream
        $Message = "This HTTP triggered function executed successfully. File share '$($requestBody.FileShareName)' created successfully for '$($requestBody.FirstName)' '$($requestBody.LastName)'."
        Write-Output $Message

        # Create the rowkey
        $rowKey = [System.Guid]::NewGuid().ToString()

        # Push data to storage account table
        Write-Output "Pushing data to storage account table"

        Push-OutputBinding -Name tableOutput -Value @{
            PartitionKey = "filesharekey"
            RowKey = $rowKey
            FirstName = $requestBody.FirstName
            LastName = $requestBody.LastName
            FileShareName = $requestBody.FileShareName
            CreationDate = $requestBody.CreationDate
        }

        # Create body message
        $bodyMessage = @{
            Message = $body
            ShareUrl = $shareUrl
        }

        Write-Output "HTTP body response:"
        Write-Output $bodyMessage

        # Associate values to output bindings by calling 'Push-OutputBinding'.
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body = $bodyMessage
        })
    }
    catch {
        $Body = "Error during function execution: $($_.Exception.Message)"

        # Associate values to output bindings by calling 'Push-OutputBinding'.
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body = $Body
        })

        Write-Error $Body
    }
}