using namespace System.Net

# Input bindings are passed in via param block.
param($Request)

# Write to the Azure Functions log stream.
$Message = "PowerShell HTTP trigger function processed a request."
Write-Output $Message

# Parse the request body and extract parameters
$requestBody = $Request.Body
$parameters = @("Containername", "Username", "Firstname", "Lastname", "Company")

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
        $Message = "Received user input: Containername = '$($requestBody.Containername)', Username = '$($requestBody.Username)', Firstname = '$($requestBody.Firstname)', Lastname = '$($requestBody.Lastname)', Companyname = '$($requestBody.Company)'"
        Write-Output $Message

        # Connect AzAccount 
        Connect-AzAccount -Identity

        # Fetch Azure StorageAccount Context from PS object..?
        $storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -AccountName $storageAccountName



        # Check if the encryption scope exists for the company
        $scopeName = "Scope$($requestBody.Company)".ToLower()
        $encyptionScopes = Get-AzStorageEncryptionScope -ResourceGroupName $resourceGroupName -StorageAccountName $storageAccountName
        Write-Output "ENCRYPTIONSCOPES COMMING HERE:"
        $encyptionScopes
        if ($encyptionScopes -notcontains $scopeName) {
            # Create a new encryption scope for the company
            New-AzStorageEncryptionScope -ResourceGroupName $resourceGroupName -StorageAccountName $storageAccountName -EncryptionScopeName $scopeName -StorageEncryption
        }

        # Create a new blob container
        New-AzStorageContainer -Name $requestBody.Containername -Context $storageAccount.Context -DefaultEncryptionScope $scopeName -PreventEncryptionScopeOverride $true -ErrorAction Stop
        

        # Set up permissions
        $permissionScope = New-AzStorageLocalUserPermissionScope -Permission rwdl -Service blob -ResourceName $requestBody.Containername -ErrorAction Stop
        Write-Output "PERMISSIONSCOPE COMMING HERE:"
        $permissionScope
        # Set up local SFTP user
        $localuser = Set-AzStorageLocalUser -ResourceGroupName $resourceGroupName -StorageAccountName $storageAccountName -UserName $requestBody.Username -HomeDirectory $requestBody.Containername -PermissionScope $permissionScope 
        Write-Output "LOCAL SFTP USER COMMING HERE:"
        $localuser
        # Set up SSH password
        $sshPasswordObject = New-AzStorageLocalUserSshPassword -ResourceGroupName $resourceGroupName -StorageAccountName $storageAccountName -UserName $localuser.Name
        Write-Output "PASSWORD COMMING HERE:"
        $sshPasswordObject
        # Build Connection string 
        $ConnectionString = "$($storageAccountName).$($localuser.Name)@$($storageAccountName).blob.core.windows.net"

        # Create body message
        $body = "This HTTP triggered function executed successfully.`nBlob container $($requestBody.Containername) created successfully for $($requestBody.Firstname) $($requestBody.LastName)."

        $bodyMessage = [ordered]@{
            Message = $body
            Username = $localuser.Name
            SsHpassword = $sshPasswordObject.SshPassword
            ConnectionString = $ConnectionString
        }

        # Write message to the log stream
        Write-Output "HTTP body respone:"
        Write-Output $bodyMessage

        # Associate values to output bindings by calling 'Push-OutputBinding'.
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body = $bodyMessage
        })

        # Create the rowkey
        $rowKey = [System.Guid]::NewGuid().ToString()
        
        # Push data to storage account table
        Write-Output "Pushing data to storage account table"     

        Push-OutputBinding -Name tableOutput -Value @{
            PartitionKey = "SFTPkey"
            RowKey = $rowKey
            Containername = $requestBody.Containername
            Username = $requestBody.Username
            FirstName = $requestBody.FirstName
            LastName = $requestBody.LastName
            Company = $requestBody.Company
        }
    }
    catch {
        $body = "Error during function execution: $($_.Exception.Message)"

        # Associate values to output bindings by calling 'Push-OutputBinding'.
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body = $body
        })

        Write-Error $body
    }
}