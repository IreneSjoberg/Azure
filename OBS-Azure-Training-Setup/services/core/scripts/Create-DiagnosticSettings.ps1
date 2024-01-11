<#
  .NOTES
  Version: 1.0 - Author: Fredrik Eliasson (fredrik.eliasson@basefarm-orange.com) - Updated: 2024-01-07
#>

#Requires -Version 7
#Requires -Modules Az.Monitor

[CmdletBinding()]

param (

  [Parameter(Mandatory)][ValidateNotNullOrEmpty()][array]$ResourceIds,
  [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$DiagnosticSettingsName,
  [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$WorkspaceId,
  [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$StorageAccountId
)

try {
  
  # Check if input is in JSON format and convert if true
  if ($ResourceIds | Test-Json -ErrorAction SilentlyContinue) { $ResourceIds = $ResourceIds | ConvertFrom-Json }

  foreach ($ResourceId in $ResourceIds) {

    # Create empty array for Log Settings
    $LogSettingsObject = @()

    Write-Output "Getting categories for resource ID: $($ResourceId)"
    $LogCategoriesAll = Get-AzDiagnosticSettingCategory -ResourceId $ResourceId | Where-Object {$_.CategoryType -eq "Logs"}
    $LogCategoryGroups = $LogCategoriesAll.CategoryGroup | Select-Object -Unique

    # Default to using Category groups if existent
    if ($LogCategoryGroups) {

      foreach ($LogCategoryGroup in $LogCategoryGroups) {

        Write-Output "Adding Log settings for CategoryGroup $($LogCategoryGroup)"
        $LogSettingsObject += New-AzDiagnosticSettingLogSettingsObject -CategoryGroup $LogCategoryGroup -Enabled $True
      }
    }

    # If no Category groups found, use individual Categories
    elseif ($LogCategoriesAll) {

      foreach ($LogCategory in $LogCategoriesAll) {

        Write-Output "Adding Log settings for Category $($LogCategory.Name)"
        $LogSettingsObject += New-AzDiagnosticSettingLogSettingsObject -Category $LogCategory.Name -Enabled $True
      }
    }

    # Else write warning that we did not find any Log categories for the input resource id
    else {

      Write-Warning "Did not find any Log categories for Diagnostic Settings for resource ID:" + "`n" + "$($ResourceId)"
      Continue
    }

    # Create Logging Diagnostic Settings for resource ID
    New-AzDiagnosticSetting -ResourceId $ResourceId -Name $DiagnosticSettingsName -Log $LogSettingsObject -WorkspaceId $WorkspaceId -StorageAccountId $StorageAccountId | Format-List Name, Id, Log, WorkspaceId, StorageAccountId
  }
}

catch {

  Throw "$($_.Exception.Message)"
}
