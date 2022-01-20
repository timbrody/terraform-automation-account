# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.65"
    }
  }

  required_version = ">= 1.1.0"
}

variable "resource_group_name" {
  type        = string
  default     = "rg-aa-uos-jf-servicenow"
  description = "description"
}


variable "automation_account_name" {
  type        = string
  default     = "aa-uos-jf-servicenow"
  description = "Automation account name"
}


provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = "uksouth"
}

resource "azurerm_automation_account" "aa" {
  name                = var.automation_account_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Basic"
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