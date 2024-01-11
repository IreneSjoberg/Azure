#Requires -Modules Az.Storage
#Requires -Modules Az.RecoveryServices
 
[CmdletBinding()]
 
param (
  [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$StorageAccountName,
  [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ResourceGroupName,
  [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$RecoveryServicesVault
)

try { 
  $StorageAccount = Get-AzStorageAccount -AccountName $StorageAccountName -ResourceGroupName $ResourceGroupName
  
  $Shares = Get-AzStorageShare -Context $StorageAccount.Context | Where-Object {$_.IsSnapShot -ne $True}

  $Vault = Get-AzRecoveryServicesVault -Name $RecoveryServicesVault

  Set-AzRecoveryServicesVaultContext -Vault $Vault
  $Policy = Get-AzRecoveryServicesBackupProtectionPolicy -VaultId $Vault.ID -WorkloadType AzureFiles

  $FileshareContainer = Get-AzRecoveryServicesBackupContainer -ContainerType AzureStorage

  $BackupItems = Get-AzRecoveryServicesBackupItem -WorkloadType $Policy.WorkloadType -VaultId $Vault.ID -Container $FileshareContainer
} 

catch {
  Throw "$($_.Exception.Message)"
}

if (-not $Shares) {
  Write-Output "No fileshares available"
}

else {
  foreach ($s in $Shares) {
    try {
      if ($BackupItems.FriendlyName -notcontains $s.Name) {
        Enable-AzRecoveryServicesBackupProtection -StorageAccountName $StorageAccountName -Name $s.name -Policy $Policy
      }
      else {
        Write-Output "Backup item already exists for $($s.Name)"
      }
    }
  
    catch {
      $BackupVaultError += "$($s.Name) - $($_.Exception.Message)"
    }
  }
}

if($BackupVaultError) {
  Write-Error $BackupVaultError
}
