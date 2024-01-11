#Requires -Modules Az.Storage, Az.RecoveryServices
 
[CmdletBinding()]
 
param (
  [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$RecoveryServicesVaultId,
  [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$StorageAccountId
)

try { 
  
  # Get RSV vault and set context 
  $Vault = Get-AzRecoveryServicesVault -Name $RecoveryServicesVaultId.Split("/")[8] -ResourceGroupName $RecoveryServicesVaultId.Split("/")[4]
  Set-AzRecoveryServicesVaultContext -Vault $Vault

  # Get RSV backup policy, backup container and backed up items
  $Policy = Get-AzRecoveryServicesBackupProtectionPolicy -VaultId $Vault.ID -WorkloadType AzureFiles
  $FileshareContainer = Get-AzRecoveryServicesBackupContainer -ContainerType AzureStorage
  $BackupItems = Get-AzRecoveryServicesBackupItem -WorkloadType $Policy.WorkloadType -VaultId $Vault.ID -Container $FileshareContainer

  # Get storage account
  $StorageAccount = Get-AzStorageAccount -AccountName $StorageAccountId.Split("/")[8] -ResourceGroupName $StorageAccountId.Split("/")[4] -ErrorAction Stop
  
  # Get all fileshares in storage account that are not snapshots
  $Shares = Get-AzStorageShare -Context $StorageAccount.Context | Where-Object {$_.IsSnapShot -ne $True}

  foreach ($Share in $Shares) {

    try {

      if ($BackupItems.FriendlyName -notcontains $Share.Name) {
        
        Write-Output "Enabling backup for share $($Share.Name)"
        Enable-AzRecoveryServicesBackupProtection -StorageAccountName $StorageAccount.StorageAccountName -Name $Share.name -Policy $Policy
      }
      else {

        Write-Output "Backup item already exists for $($Share.Name)"
      }
    }

    catch {

      $BackupVaultError += "$($Share.Name) - $($_.Exception.Message)"
    }
  }

  if ($BackupVaultError) {
    
    Write-Error $BackupVaultError
  }
} 

catch {

  Throw "$($_.Exception.Message)"
}