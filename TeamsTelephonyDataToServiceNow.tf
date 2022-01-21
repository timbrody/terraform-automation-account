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