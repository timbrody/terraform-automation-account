# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.65"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "stuosjftdbtfstate"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }


  required_version = ">= 1.1.0"
}

locals {
  environment = terraform.workspace
  service     = "telephony"
  servicenow_instances = {
    "dev"  = "sotondev"
    "pprd" = "sotonpprd"
    "prod" = "sotonproduction"
  }
  servicenow_instance_name = lookup(local.servicenow_instances, local.environment)
}

variable "servicenow_user_name" {
  type        = string
  default     = ""
  description = "ServiceNow user name with import_set_loader and import_transform roles"
  sensitive   = true
}
variable "servicenow_password" {
  type        = string
  default     = ""
  description = "ServiceNow password"
  sensitive   = true
}
variable "teams_user_name" {
  type        = string
  default     = ""
  description = "MS Teams administrator user name"
  sensitive   = true
}
variable "teams_password" {
  type        = string
  default     = ""
  description = "MS Teams password"
  sensitive   = true
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.environment}-${local.service}"
  location = "uksouth"
}

resource "azurerm_automation_account" "aa" {
  name                = "aa-${local.environment}-${local.service}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Basic"
}

resource "azurerm_automation_module" "MicrosoftTeams" {
  name                    = "MicrosoftTeams"
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.aa.name
  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/MicrosoftTeams"
  }
}

resource "azurerm_automation_schedule" "twohours" {
  name                    = "EveryTwoHours"
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.aa.name
  frequency               = "Hour"
  interval                = 2
  timezone                = "Etc/UTC"
  description             = "Run every two hours"
}

resource "azurerm_automation_schedule" "sixhours" {
  name                    = "EverySixHours"
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.aa.name
  frequency               = "Hour"
  interval                = 6
  timezone                = "Etc/UTC"
  description             = "Run every six hours"
}


resource "azurerm_automation_credential" "servicenow" {
  name                    = "ServiceNow"
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.aa.name
  username                = var.servicenow_user_name
  password                = var.servicenow_password
  description             = "Credential for ServiceNow"
}

resource "azurerm_automation_credential" "teams" {
  name                    = "Teams"
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.aa.name
  username                = var.teams_user_name
  password                = var.teams_password
  description             = "Credential for Teams"
}

resource "azurerm_automation_variable_string" "servicenow_instance" {
  name                    = "ServiceNowInstanceName"
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.aa.name
  value                   = local.servicenow_instance_name
}


data "local_file" "TeamsTelephonyDataToServiceNow" {
  filename = "${path.module}/TeamsTelephonyDataToServiceNow.ps1"
}

resource "azurerm_automation_runbook" "TeamsTelephonyDataToServiceNow" {
  name                    = "TeamsTelephonyDataToServiceNow"
  location                = azurerm_resource_group.rg.location
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.aa.name
  log_verbose             = "false"
  log_progress            = "false"
  description             = "Retrieve Teams telephony data and import into ServiceNow CMDB"
  runbook_type            = "PowerShell"
  content                 = data.local_file.TeamsTelephonyDataToServiceNow.content
}

resource "azurerm_automation_job_schedule" "TeamsTelephonyDataToServiceNow_sched" {
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.aa.name
  schedule_name           = azurerm_automation_schedule.sixhours.name
  runbook_name            = azurerm_automation_runbook.TeamsTelephonyDataToServiceNow.name
  depends_on              = [azurerm_automation_schedule.sixhours]
}