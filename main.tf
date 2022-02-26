# Template for SQL Server Cluster
# Note if running this many times for testing make sure to delete the AD and DNS objects
terraform {
  required_version = ">= 0.12.1"
  backend "azurerm" {
    storage_account_name = "${var.storage_account_name}"
    container_name       = "${var.container_name}"
    key                  = "${var.key}"
    access_key           = "${var.access_key}"
  }
}


locals {
  witnessName       = "${var.witnessServerConfig.vmName}001"
  vm1Name           = "${var.sqlServerConfig.vmName}001"
  vm2Name           = "${var.sqlServerConfig.vmName}002"
  backupStorageName = "sqlbck${random_string.random.result}stg"
  lbSettings = {
    sqlLBFE   = "${var.sqlServerConfig.sqlLBName}-lbfe"
    sqlLBBE   = "${var.sqlServerConfig.sqlLBName}-lbbe"
    sqlLBName = "${var.sqlServerConfig.sqlLBName}-lb"
  }

  SQLAOProbe = "SQLAlwaysOnEndPointProbe"

  vmSettings = {
    availabilitySets = {
      sqlAvailabilitySetName = "${var.sqlServerConfig.vmName}-avs"
    }
    rdpPort = 3389
  }
  sqlAOEPName       = "${var.sqlServerConfig.vmName}-hadr"
  sqlAOAGName       = "${var.sqlServerConfig.vmName}-ag"
  sqlAOListenerName = "${var.sqlServerConfig.vmName}-lis"
  sharePath         = "${var.sqlServerConfig.vmName}-fsw"
  clusterName       = "${var.sqlServerConfig.vmName}-cl"
  sqlwNicName       = "${var.witnessServerConfig.vmName}-nic"
  keyVaultId        = "${data.azurerm_key_vault.keyvaultsecrets.id}"
}


resource "random_string" "random" {
  length  = 8
  special = false
  upper   = false
  keepers = {
    #generate new ID only when a new resource group is creted
    resource_group = "${var.resource_group_name}"
  }
}

#Create the diagnostic storage account
resource "azurerm_storage_account" "sqldiag" {
  name                     = "sqldiag${random_string.random.result}stg"
  resource_group_name      = "${var.resource_group_name}"
  location                 = "${var.location}"
  tags                     = "${var.tagValues}"
  account_kind             = "Storage"
  account_tier             = "${var.sqlServerConfig.storageAccountTier}"
  account_replication_type = "${var.sqlServerConfig.storageAccountReplicationType}"
  //enable_blob_encryption = "${var.sqlServerConfig.diagBlobEncryptionEnabled}"
}

#Create the storage account that will hold the SQL Backups
resource "azurerm_storage_account" "sqlbackup" {
  name                     = "${local.backupStorageName}"
  location                 = "${var.location}"
  resource_group_name      = "${var.resource_group_name}"
  tags                     = "${var.tagValues}"
  account_tier             = "${var.sqlServerConfig.storageAccountTier}"
  account_replication_type = "${var.sqlServerConfig.storageAccountReplicationType}"
  // enable_blob_encryption = "${var.sqlServerConfig.sqlBackupConfig.enableEncryption}"
}

#Create the SQL Load Balencer
resource "azurerm_lb" "sqlLB" {
  name                = local.lbSettings.sqlLBName
  location            = "${var.location}"
  resource_group_name = "${var.resource_group_name}"
  frontend_ip_configuration {
    name                          = local.lbSettings.sqlLBFE
    private_ip_address_allocation = "Static"
    private_ip_address            = "${var.sqlServerConfig.sqlLBIPAddress}"
    subnet_id                     = data.azurerm_subnet.subnet.id
  }

}

#Create the load balencer backend pool
resource "azurerm_lb_backend_address_pool" "sqlLBBE" {
  resource_group_name = "${var.resource_group_name}"
  loadbalancer_id     = "${azurerm_lb.sqlLB.id}"
  name                = local.lbSettings.sqlLBBE
}

#Add the first VM to the load balencer
resource "azurerm_network_interface_backend_address_pool_association" "sqlvm1BEAssoc" {
  network_interface_id    = "${module.sqlvm1.Nic0.id}"
  ip_configuration_name   = "${module.sqlvm1.Nic0.ip_configuration[0].name}"
  backend_address_pool_id = "${azurerm_lb_backend_address_pool.sqlLBBE.id}"
}

#Add the second VM to the load balencer
resource "azurerm_network_interface_backend_address_pool_association" "sqlvm2BEAssoc" {
  network_interface_id    = "${module.sqlvm2.Nic0.id}"
  ip_configuration_name   = "${module.sqlvm2.Nic0.ip_configuration[0].name}"
  backend_address_pool_id = "${azurerm_lb_backend_address_pool.sqlLBBE.id}"
}

#Create the load balencer rules
resource "azurerm_lb_rule" "sqlLBRule" {
  resource_group_name            = "${var.resource_group_name}"
  loadbalancer_id                = "${azurerm_lb.sqlLB.id}"
  name                           = "${local.lbSettings.sqlLBName}-lbr"
  protocol                       = "Tcp"
  frontend_port                  = 1433
  backend_port                   = 1433
  frontend_ip_configuration_name = local.lbSettings.sqlLBFE
  probe_id                       = "${azurerm_lb_probe.sqlLBProbe.id}"
}

#Create a health probe for the load balencer
resource "azurerm_lb_probe" "sqlLBProbe" {
  resource_group_name = "${var.resource_group_name}"
  loadbalancer_id     = "${azurerm_lb.sqlLB.id}"
  name                = local.SQLAOProbe
  port                = 59999
  protocol            = "Tcp"
  interval_in_seconds = 5
  number_of_probes    = 2
}

#Create the primary SQL server
module "sqlvm1" {
  source = "github.com/Quaternioneer/terraform-azurerm-basicwindowsvm"

  name                    = "${local.vm1Name}"
  location                = "${var.location}"
  resource_group_name     = "${var.resource_group_name}"
  admin_username          = "${var.adminUsername}"
  admin_password          = "${data.azurerm_key_vault_secret.localAdminPasswordSecret.value}"
  nic_subnetName          = "${data.azurerm_subnet.subnet.name}"
  nic_vnetName            = "${data.azurerm_virtual_network.vnet.name}"
  nic_resource_group_name = "${var.vnetConfig.existingVnetRG}"
  availability_set_id     = "${azurerm_availability_set.sqlAS.id}"
  public_ip               = false
  vm_size                 = "${var.sqlServerConfig.vmSize}"
  data_disk_sizes_gb      = ["${var.sqlServerConfig.dataDisks.diskSizeGB}", "${var.sqlServerConfig.dataDisks.diskSizeGB}"]
  storage_image_reference = {
    publisher = "${var.sqlServerConfig.imageReference.sqlImagePublisher}"
    offer     = "${var.sqlServerConfig.imageReference.offer}"
    sku       = "${var.sqlServerConfig.imageReference.sku}"
    version   = "${var.sqlServerConfig.imageReference.version}"
  }
}

#Create the secondary SQL Server
module "sqlvm2" {
  source = "github.com/Quaternioneer/terraform-azurerm-basicwindowsvm"

  name                    = "${local.vm2Name}"
  location                = "${var.location}"
  resource_group_name     = "${var.resource_group_name}"
  admin_username          = "${var.adminUsername}"
  admin_password          = "${data.azurerm_key_vault_secret.localAdminPasswordSecret.value}"
  nic_subnetName          = "${data.azurerm_subnet.subnet.name}"
  nic_vnetName            = "${data.azurerm_virtual_network.vnet.name}"
  nic_resource_group_name = "${var.vnetConfig.existingVnetRG}"
  availability_set_id     = "${azurerm_availability_set.sqlAS.id}"
  public_ip               = false
  vm_size                 = "${var.sqlServerConfig.vmSize}"
  data_disk_sizes_gb      = ["${var.sqlServerConfig.dataDisks.diskSizeGB}", "${var.sqlServerConfig.dataDisks.diskSizeGB}"]
  storage_image_reference = {
    publisher = "${var.sqlServerConfig.imageReference.sqlImagePublisher}"
    offer     = "${var.sqlServerConfig.imageReference.offer}"
    sku       = "${var.sqlServerConfig.imageReference.sku}"
    version   = "${var.sqlServerConfig.imageReference.version}"
  }

}

#Create the SQL Witness.  Could be switched for a blob storage if desired
module "sqlvmw" {
  source = "github.com/Quaternioneer/terraform-azurerm-basicwindowsvm"

  name                    = "${var.witnessServerConfig.vmName}001"
  location                = "${var.location}"
  resource_group_name     = "${var.resource_group_name}"
  admin_username          = "${var.adminUsername}"
  admin_password          = "${data.azurerm_key_vault_secret.localAdminPasswordSecret.value}"
  nic_subnetName          = "${data.azurerm_subnet.subnet.name}"
  nic_vnetName            = "${data.azurerm_virtual_network.vnet.name}"
  nic_resource_group_name = "${var.vnetConfig.existingVnetRG}"
  availability_set_id     = "${azurerm_availability_set.sqlAS.id}"
  public_ip               = false
  vm_size                 = "${var.witnessServerConfig.vmSize}"
  data_disk_sizes_gb      = ["${var.witnessServerConfig.dataDisks.diskSizeGB}", "${var.witnessServerConfig.dataDisks.diskSizeGB}"]
  storage_image_reference = {
    publisher = "${var.witnessServerConfig.imageReference.publisher}"
    offer     = "${var.witnessServerConfig.imageReference.offer}"
    sku       = "${var.witnessServerConfig.imageReference.sku}"
    version   = "${var.witnessServerConfig.imageReference.version}"
  }
}

#Create the SQL Availiability Sets for hardware and update redundancy
resource "azurerm_availability_set" "sqlAS" {
  name                = "${var.sqlServerConfig.vmName}-avs"
  location            = "${var.location}"
  resource_group_name = "${var.resource_group_name}"
  managed             = true
}

