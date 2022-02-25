variable "resource_group_name" {
    default = "team9-project"
}

variable "keyVaultConfig" {
    default = {
        existingRGName = "NDkeyvaultRG"
        existingVaultName = "statebox"
        localAdminPasswordSecret = "server2016DefaultPassword"
    }
}

variable "secretPasswordName" {
    default = "server2016DefaultPassword"
}

variable "vnetConfig" {
    default = {
        existingVnetName = "${var.resource_group_name}-vnet"
        existingVnetRG = var.resource_group_name
        sqlSubnet =  "10.0.0.4/24"
        dbSubnetName = "PwS3-Shared-DB-CRM"
    }
}

variable "location" {
    description= "The location of the template deployment"
    default =  "canadacentral"
}

variable "adminUsername" {
    description = "The name of the Administrator for the new VMs"
    default = "azureadmin"
}

variable "sqlServerConfig" {
    default = {
        clusterIp = "10.0.4.15"
        sqlLBIPAddress = "10.0.4.14"
        sqlLBName = "TST-SWB"
        sqlAOListenerPort = "1433"
        vmSize = "Standard_DS3_v2"
        vmName = "TST-SWB"
        sqlServerLicenseType = "AHUB"
        sqlpatchingConfig = {
            patchingEnabled = true
            dayOfWeek = "Sunday"
            maintenanceWindowStartingHour = "2"
            maintenanceWindowDuration = 60
        }
        sqlBackupConfig = {
            backupEnabled = true
            retentionPeriod = 30
            enableEncryption = true
            backupSystemDbs = true
            backupScheduleType = "Manual"
            fullBackupFrequency = "Daily"
            fullBackupStartTime = 2
            fullBackupWindowHours = 5
            logBackupFrequency = 60
            password = "Canada123!"
        }
        imageReference = {
            sqlImagePublisher = "MicrosoftSQLServer"
            offer = "SQL2016SP2-WS2016"
            sku = "Enterprise"
            version = "latest"
        }
        dataDisks = {
            numberOfSqlVMDisks = "2"
            diskSizeGB = "1024"
        }
        workloadType = "OLTP"
        sqlServerServiceAccountUserName = "svc-tstsql1"
        sqlStorageAccountName = "tstsqltest1stg"
        storageAccountTier = "Standard"
        storageAccountReplicationType = "LRS"
        diagBlobEncryptionEnabled = true
        sqlDatabases = "TestServer"
        sqlServerServiceAccountPasswordSecret = "sqlServerServiceAccountPassword"
        enableAcceleratedNetworking= true
    }
}

variable "witnessServerConfig" {
    default = {
        vmSize = "Standard_DS2_v2"
        vmName = "TST-SVR"
        imageReference = {
            publisher = "MicrosoftWindowsServer"
            offer = "WindowsServer"
            sku = "2016-Datacenter"
            version = "latest"
        }
        dataDisks = {
            diskSizeGB = "128"
        }
        sqlStorageAccountTier = "Standard"
        sqlStorageAccountReplicationType = "LRS"
        enableAcceleratedNetworking = true
    
    }
}

variable "backupConfig" {
    default = {
        existingBackupVaultRG = "AzPwS01-Shared-CRM-Backup-RG"
        existingBackupVaultName = "AzPwS01-Shared-CRM-Backup-Vault"
        existingBackupPolicy = "DailyBackupPolicy"
    }
}
variable "tagValues" {
    default = {
        "workload" = "Database"
        "owner" = "Nathaniel Davila"
        "businessUnit" = "Terraforming Mars"
        "costCenterOwner" = "Occupy Mars"
        "environment" = "Sandbox"
        "classification" = "Unclassified"
        "version" = "0.1"
    }
}

