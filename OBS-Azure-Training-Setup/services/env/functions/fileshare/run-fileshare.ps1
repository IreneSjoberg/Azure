using namespace System.Net

param ($HttpRequest)

Write-Output "Fileshare function started."

try {

  # Null potential return bodies
  $InputCheckBody = $null
  $HttpResponseBody = $null
  $ErrorMessageBody = $null

  # Check that we have expected inputs
  $ExpectedInputs = @("filesharename", "firstname", "lastname")

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

    # Create a new file share
    $StorageShare = New-AzStorageShare -Name $HttpRequest.Body.filesharename.ToLower() -Context $StorageAccount.Context -ErrorAction Stop

    # Add successful order entry to table
    Push-OutputBinding -Name StorageAccountTable -Value @{

      PartitionKey    = "Orders"
      RowKey          = (New-Guid).Guid
      FileshareName   = $StorageShare.ShareClient.Name
      ShareUri        = $StorageShare.ShareClient.Uri
      FirstName       = $HttpRequest.Body.firstname
      LastName        = $HttpRequest.Body.lastname
    }

    # Create OK return body
    $HttpResponseBody = [ordered]@{

      FileshareName   = $StorageShare.ShareClient.Name
      ShareUri        = $StorageShare.ShareClient.Uri
      FirstName       = $($HttpRequest.Body.firstname)
      LastName        = $($HttpRequest.Body.lastname)
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