using namespace System.Net

param ($HttpRequest)

Write-Output "SFTP function started."

try {

  # Null potential return bodies
  $InputCheckBody = $null
  $HttpResponseBody = $null
  $ErrorMessageBody = $null

  # Check that we have expected inputs
  $ExpectedInputs = @("containername", "username", "firstname", "lastname", "company")

  foreach ($Input in $ExpectedInputs) {

    if (-not $HttpRequest.Body.$Input) {
      
      $InputMessage = "`n" + "Missing '$($Input)' input."
      $InputCheckBody += $InputMessage
      Write-Warning $InputMessage
    }
  }

  # Return BadRequest if any InputCheckBody created
  if ($InputCheckBody) {

    # Return HTTP response (BadRequest)
    Push-OutputBinding -Name HttpResponse -Value ([HttpResponseContext]@{
      StatusCode = [HttpStatusCode]::BadRequest
      Body = $InputCheckBody
    })
  }

  else {

    # Get storage account
    $StorageAccount = Get-AzStorageAccount -AccountName $env:StorageAccountName -ResourceGroupName $env:ResourceGroupName -ErrorAction Stop

    # Check if the encryption scope exists for the company
    $ScopeName = $HttpRequest.Body.company.ToLower().Replace("-","").Replace(" ","")
    $EncryptionScopes = Get-AzStorageEncryptionScope -StorageAccount $StorageAccount
    if ($EncryptionScopes -notcontains $ScopeName) {
        
      # Create a new encryption scope for the company
      Write-Output "Creating encryption scope '$($ScopeName)' for company $($HttpRequest.Body.company)"
      New-AzStorageEncryptionScope -StorageAccount $StorageAccount -EncryptionScopeName $ScopeName -StorageEncryption -ErrorAction Stop
    }
    
    # Create a new blob container
    $ContainerName = $HttpRequest.Body.containername.ToLower()
    New-AzStorageContainer -Context $StorageAccount.Context -Name $ContainerName -DefaultEncryptionScope $ScopeName -PreventEncryptionScopeOverride $True -ErrorAction Stop

    # Create permission scope, user and SSH password
    $PermissionScope = New-AzStorageLocalUserPermissionScope -ResourceName $ContainerName -Permission rwdl -Service blob -ErrorAction Stop
    $User = Set-AzStorageLocalUser -StorageAccount $StorageAccount -UserName $HttpRequest.Body.username.ToLower() -HomeDirectory $HttpRequest.Body.containername.ToLower() -PermissionScope $PermissionScope -ErrorAction Stop
    $SshPasswordObject = New-AzStorageLocalUserSshPassword -StorageAccount $StorageAccount -UserName $User.Name -ErrorAction Stop

    # Build Connection string 
    $ConnectionString = "$($StorageAccount.StorageAccountName).$($User.Name)@$($StorageAccount.StorageAccountName).blob.core.windows.net"

    # Add successful order entry to table
    Push-OutputBinding -Name StorageAccountTable -Value @{

      PartitionKey      = "Orders"
      RowKey            = (New-Guid).Guid
      ConnectionString  = $ConnectionString
      UserName          = $User.Name
      ContainerName     = $ContainerName
      FirstName         = $HttpRequest.Body.firstname
      LastName          = $HttpRequest.Body.lastname
      Company           = $HttpRequest.Body.company
    }

    # Create OK return body
    $HttpResponseBody = [ordered]@{

      ConnectionString  = $ConnectionString
      SshPassword       = $SshPasswordObject.SshPassword
      ContainerName     = $ContainerName
      FirstName         = $($HttpRequest.Body.firstname)
      LastName          = $($HttpRequest.Body.lastname)
    }
    Write-Output $HttpResponseBody

    # Return HTTP response (OK)
    Push-OutputBinding -Name HttpResponse -Value ([HttpResponseContext]@{
      StatusCode = [HttpStatusCode]::OK
      Body = $HttpResponseBody
    })
  }
}

catch {

  $ErrorMessageBody = $($_.Exception.Message)
  Write-Error $ErrorMessageBody

  # Return HTTP response (BadRequest)
  Push-OutputBinding -Name HttpResponse -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::BadRequest
    Body = $ErrorMessageBody
  })
}