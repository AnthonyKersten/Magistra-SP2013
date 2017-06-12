# Create a Full Magistra Legal Workplace with RDS deployment, AD, SQL 2014 and SharePoint 2013 farm with PowerShell DSC Extension

This template will create a SharePoint 2013 farm using the PowerShell DSC Extension it creates the following resources:

## Parameters
+	domainName: FQDN of the new domain to be created.
+	sharepointServiceAccountUserName: Username of the Sharepoint server service account to create.
+	adminUsername: Username of the local Administrator account of the new VMs and domain.
+	adminPassword: Password of the local Administrator account of the new VMs and domain.
+	sharepoint2013SP1DownloadLink: Direct download link for the SharePoint 2013 with SP1 ISO.
+	sharepoint2013ProductKey: Product key for SharePoint 2013 with SP1, required for SharePoint setup.
+	sqlInstallationISOUri: Direct download link for the SharePoint 2013 with SP1 ISO.
+	CustomerSuffix: 3-digit customersuffix.
+	RDSImageSKU: Remote Desktop image sku.
+	RDSCount: amount of Remote Desktop Session Host.
+	RDSvmSize: virtual machine type for the Remote Desktop Session Host.


<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FDennisSchouwenaars%2FMagistra%2Fmaster%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>

<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FDennisSchouwenaars%2FMagistra%2Fmaster%2Fazuredeploy.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>

## Deploying from Portal

+	Login into Azurestack portal
+	Click "New" -> "Custom" -> "Template deployment"
+	Copy conent in azuredeploy.json, Click "Edit Tempalte" and paste content, then Click "Save"
+	Fill the parameters
+	Click "Create new" to create new Resource Group
+	Click "Create"
