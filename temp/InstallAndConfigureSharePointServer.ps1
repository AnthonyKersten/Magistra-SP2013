#
# Copyright="© Microsoft Corporation. All rights reserved."
#

configuration InstallAndConfigureSharePointServer
{

    param
    (
        [Parameter(Mandatory)]
        [String]$DomainName,
		
		[String]$primaryAdIpAddress = "10.0.0.4",

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$SharePointSetupUserAccountcreds,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$SharePointFarmAccountcreds,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$SharePointFarmPassphrasecreds,
        
        [parameter(Mandatory)]
        [String]$DatabaseName,

        [parameter(Mandatory)]
        [String]$AdministrationContentDatabaseName,

        [parameter(Mandatory)]
        [String]$DatabaseServer,
        
        [parameter(Mandatory)]
        [String]$Configuration,
		
		[parameter(Mandatory)]
		[String]$InstallSourceDrive,
		
		[parameter(Mandatory)]
		[String]$InstallSourceFolderName,
		
		[parameter(Mandatory)]
		[String]$ProductKey,
		
		[parameter(Mandatory)]
		[String]$SPDLLink,
		
        [Int]$RetryCount=30,
        [Int]$RetryIntervalSec=60
    )

        Write-Verbose "AzureExtensionHandler loaded continuing with configuration"

        [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)
        [System.Management.Automation.PSCredential ]$FarmCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($SharePointFarmAccountcreds.UserName)", $SharePointFarmAccountcreds.Password)
        [System.Management.Automation.PSCredential ]$SPsetupCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($SharePointSetupUserAccountcreds.UserName)", $SharePointSetupUserAccountcreds.Password)

        # Install Sharepoint Module
        $ModuleFilePath="$PSScriptRoot\SharePointServer.psm1"
        $ModuleName = "SharepointServer"
        $PSModulePath = $Env:PSModulePath -split ";" | Select -Index 1
        $ModuleFolder = "$PSModulePath\$ModuleName"
        if (-not (Test-Path  $ModuleFolder -PathType Container)) {
            mkdir $ModuleFolder
        }
        Copy-Item $ModuleFilePath $ModuleFolder -Force
		$currentDNS = (Get-DnsClientServerAddress -InterfaceAlias Ethernet -Family IPv4).ServerAddresses
    	$newdns = @($primaryAdIpAddress) + $currentDNS
    	Set-DnsClientServerAddress -InterfaceAlias Ethernet -ServerAddresses $currentDNS
		ipconfig /flushdns
		ipconfig /registerdns
		
		# Get the disk number of the data disk
		$dataDisk = Get-Disk | where{$_.PartitionStyle -eq "RAW"}
		$dataDiskNumber = $dataDisk[0].Number
		
        Enable-CredSSPNTLM -DomainName $DomainName

        Import-DscResource -ModuleName xComputerManagement, xActiveDirectory, xDisk, cConfigureSharepoint, xCredSSP, cDisk, xNetworking, xSharePoint, xPendingReboot, xDownloadFile, xDownloadISO, xWindowsUpdate  
    
        Node localhost
        {
            xWaitforDisk Disk2
            {
                DiskNumber = $dataDiskNumber
                RetryIntervalSec =$RetryIntervalSec
                RetryCount = $RetryCount
            }
            cDiskNoRestart SPDataDisk
            {
                DiskNumber = $dataDiskNumber
                DriveLetter = "F"
                DependsOn = "[xWaitforDisk]Disk2"
            }
            xCredSSP Server 
            { 
                Ensure = "Present" 
                Role = "Server" 
            } 
            xCredSSP Client 
            { 
                Ensure = "Present" 
                Role = "Client" 
                DelegateComputers = "*.$Domain", "localhost"
            }
            WindowsFeature ADPS
            {
                Name = "RSAT-AD-PowerShell"
                Ensure = "Present"
                DependsOn = "[cDiskNoRestart]SPDataDisk"
            }
			
			xHotFix RemoveDotNetFourSix
			{
				Ensure = "Absent"
				Path = "https://download.microsoft.com/download/E/4/1/E4173890-A24A-4936-9FC9-AF930FE3FA40/NDP461-KB3102436-x86-x64-AllOS-ENU.exe"
				Id = "KB3102467"
				DependsOn = '[WindowsFeature]ADPS'
			}
			
			WindowsFeature DotNet
			{
				Name = "Net-Framework-Core"
				Ensure = 'Present'
				DependsOn = '[xHotFix]RemoveDotNetFourSix'
			}
			
			xDownloadISO DownloadSPImage
        	{
            	SourcePath = $SPDLLink
            	DestinationDirectoryPath = "C:\SharePoint2013"
            	DependsOn = '[WindowsFeature]DotNet'
        	}
			
			xDownloadFile AppFabricKBDL
			{
				SourcePath = "https://download.microsoft.com/download/7/B/5/7B51D8D1-20FD-4BF0-87C7-4714F5A1C313/AppFabric1.1-RTM-KB2671763-x64-ENU.exe"
				FileName = "AppFabric1.1-RTM-KB2671763-x64-ENU.exe"
				DestinationDirectoryPath = "C:\SharePoint2013\prerequisiteinstallerfiles"
				DependsOn = "[xDownloadISO]DownloadSPImage"
				
			}
			
			xDownloadFile MicrosoftIdentityExtensionsDL
			{
				SourcePath = "http://download.microsoft.com/download/0/1/D/01D06854-CA0C-46F1-ADBA-EBF86010DCC6/rtm/MicrosoftIdentityExtensions-64.msi"
				FileName = "MicrosoftIdentityExtensions-64.msi"
				DestinationDirectoryPath = "C:\SharePoint2013\prerequisiteinstallerfiles"
				DependsOn = "[xDownloadFile]AppFabricKBDL"
				
			}
			
			xDownloadFile MSIPCDL
			{
				SourcePath = "http://download.microsoft.com/download/9/1/D/91DA8796-BE1D-46AF-8489-663AB7811517/setup_msipc_x64.msi"
				FileName = "setup_msipc_x64.msi"
				DestinationDirectoryPath = "C:\SharePoint2013\prerequisiteinstallerfiles"
				DependsOn = "[xDownloadFile]MicrosoftIdentityExtensionsDL"
				
			}
			
			xDownloadFile SQLNCLIDL
			{
				SourcePath = "https://download.microsoft.com/download/F/7/B/F7B7A246-6B35-40E9-8509-72D2F8D63B80/sqlncli_amd64.msi"
				FileName = "sqlncli.msi"
				DestinationDirectoryPath = "C:\SharePoint2013\prerequisiteinstallerfiles"
				DependsOn = "[xDownloadFile]MSIPCDL"
				
			}
			
			xDownloadFile SynchronizationDL
			{
				SourcePath = "http://download.microsoft.com/download/E/0/0/E0060D8F-2354-4871-9596-DC78538799CC/Synchronization.msi"
				FileName = "Synchronization.msi"
				DestinationDirectoryPath = "C:\SharePoint2013\prerequisiteinstallerfiles"
				DependsOn = "[xDownloadFile]SQLNCLIDL"
				
			}
			
			xDownloadFile WcfDataServices5DL
			{
				SourcePath = "http://download.microsoft.com/download/8/F/9/8F93DBBD-896B-4760-AC81-646F61363A6D/WcfDataServices.exe"
				FileName = "WcfDataServices5.exe"
				DestinationDirectoryPath = "C:\SharePoint2013\prerequisiteinstallerfiles"
				DependsOn = "[xDownloadFile]SynchronizationDL"
				
			}
			
			xDownloadFile WcfDataServices56DL
			{
				SourcePath = "http://download.microsoft.com/download/1/C/A/1CAA41C7-88B9-42D6-9E11-3C655656DAB1/WcfDataServices.exe"
				FileName = "WcfDataServices56.exe"
				DestinationDirectoryPath = "C:\SharePoint2013\prerequisiteinstallerfiles"
				DependsOn = "[xDownloadFile]WcfDataServices5DL"
				
			}
			
			xDownloadFile KBDL
			{
				SourcePath = "http://download.microsoft.com/download/D/7/2/D72FD747-69B6-40B7-875B-C2B40A6B2BDD/Windows6.1-KB974405-x64.msu"
				FileName = "Windows6.1-KB974405-x64.msu"
				DestinationDirectoryPath = "C:\SharePoint2013\prerequisiteinstallerfiles"
				DependsOn = "[xDownloadFile]WcfDataServices56DL"
				
			}
			
			xDownloadFile AppFabricDL
			{
				SourcePath = "http://download.microsoft.com/download/A/6/7/A678AB47-496B-4907-B3D4-0A2D280A13C0/WindowsServerAppFabricSetup_x64.exe"
				FileName = "WindowsServerAppFabricSetup_x64.exe"
				DestinationDirectoryPath = "C:\SharePoint2013\prerequisiteinstallerfiles"
				DependsOn = "[xDownloadFile]KBDL"
				
			}

            xWaitForADDomain DscForestWait 
            { 
                DomainName = $DomainName 
                DomainUserCredential= $DomainCreds
                RetryCount = $RetryCount 
                RetryIntervalSec = $RetryIntervalSec 
                DependsOn = "[xDownloadFile]AppFabricDL"      
            }

            xComputer DomainJoin
            {
                Name = $env:COMPUTERNAME
                DomainName = $DomainName
                Credential = $DomainCreds
                DependsOn = "[xWaitForADDomain]DscForestWait" 
            }
			
			xSPInstallPrereqs SharePointPrereqInstall
			{
				InstallerPath     = "$($InstallSourceDrive)\$($InstallSourceFolderName)\prerequisiteinstaller.exe"
				OnlineMode        = $true
				SQLNCli           = "$($InstallSourceDrive)\$($InstallSourceFolderName)\prerequisiteinstallerfiles\sqlncli.msi"
				IDFX              = "$($InstallSourceDrive)\$($InstallSourceFolderName)\prerequisiteinstallerfiles\Windows6.1-KB974405-x64.msu"
				Sync              = "$($InstallSourceDrive)\$($InstallSourceFolderName)\prerequisiteinstallerfiles\Synchronization.msi"
				AppFabric         = "$($InstallSourceDrive)\$($InstallSourceFolderName)\prerequisiteinstallerfiles\WindowsServerAppFabricSetup_x64.exe"
				IDFX11            = "$($InstallSourceDrive)\$($InstallSourceFolderName)\prerequisiteinstallerfiles\MicrosoftIdentityExtensions-64.msi"
				MSIPCClient       = "$($InstallSourceDrive)\$($InstallSourceFolderName)\prerequisiteinstallerfiles\setup_msipc_x64.msi"
				WCFDataServices   = "$($InstallSourceDrive)\$($InstallSourceFolderName)\prerequisiteinstallerfiles\WcfDataServices5.exe"
				KB2671763         = "$($InstallSourceDrive)\$($InstallSourceFolderName)\prerequisiteinstallerfiles\AppFabric1.1-RTM-KB2671763-x64-ENU.exe"
				WCFDataServices56 = "$($InstallSourceDrive)\$($InstallSourceFolderName)\prerequisiteinstallerfiles\WcfDataServices56.exe"
				Ensure = "Present"
				DependsOn = "[xComputer]DomainJoin"
			}
			
			xPendingReboot AfterPrereqInstall
        	{
            	Name = "AfterPrereqInstall"
            	DependsOn = "[xSPInstallPrereqs]SharePointPrereqInstall"
        	}
			
			xSPInstall SharePointInstall
        	{
            	BinaryDir  = "$($InstallSourceDrive)\$($InstallSourceFolderName)"
            	ProductKey = $ProductKey
            	Ensure     = "Present"
            	DependsOn = "[xComputer]DomainJoin", "[xPendingReboot]AfterPrereqInstall"
        	}
			
			xPendingReboot AfterSPInstall
        	{
            	Name = "AfterSPInstall"
            	DependsOn = "[xSPInstall]SharePointInstall"
        	}

            xADUser CreateSetupAccount
            {
                DomainAdministratorCredential = $DomainCreds
                DomainName = $DomainName
                UserName = $SharePointSetupUserAccountcreds.UserName
                Password =$SharePointSetupUserAccountcreds
                Ensure = "Present"
                DependsOn = "[WindowsFeature]ADPS", "[xComputer]DomainJoin", "[xPendingReboot]AfterSPInstall"
            }

            Group AddSetupUserAccountToLocalAdminsGroup
            {
                GroupName = "Administrators"
                Credential = $DomainCreds
                MembersToInclude = "${DomainName}\$($SharePointSetupUserAccountcreds.UserName)"
                Ensure="Present"
                DependsOn = "[xAdUser]CreateSetupAccount"
            }

            xADUser CreateFarmAccount
            {
                DomainAdministratorCredential = $DomainCreds
                DomainName = $DomainName
                UserName = $SharePointFarmAccountcreds.UserName
                Password =$FarmCreds
                Ensure = "Present"
                DependsOn = "[WindowsFeature]ADPS", "[xComputer]DomainJoin"
            }
        
            cConfigureSharepoint ConfigureSharepointServer
            {
                DomainName=$DomainName
                DomainAdministratorCredential=$DomainCreds
                DatabaseName=$DatabaseName
                AdministrationContentDatabaseName=$AdministrationContentDatabaseName
                DatabaseServer=$DatabaseServer
                SetupUserAccountCredential=$SPsetupCreds
                FarmAccountCredential=$SharePointFarmAccountcreds
                FarmPassphrase=$SharePointFarmPassphrasecreds
                Configuration=$Configuration
                DependsOn = "[xADUser]CreateFarmAccount","[xADUser]CreateSetupAccount", "[Group]AddSetupUserAccountToLocalAdminsGroup", "[xPendingReboot]AfterSPInstall"
            }
            LocalConfigurationManager 
            {
                ConfigurationMode = 'ApplyOnly'
                RebootNodeIfNeeded = $true 
            }
        }
   
}

function Enable-CredSSPNTLM
{ 
    param(
        [Parameter(Mandatory=$true)]
        [string]$DomainName
    )
    
    # This is needed for the case where NTLM authentication is used

    Write-Verbose 'STARTED:Setting up CredSSP for NTLM'
   
    Enable-WSManCredSSP -Role client -DelegateComputer localhost, *.$DomainName -Force -ErrorAction SilentlyContinue
    Enable-WSManCredSSP -Role server -Force -ErrorAction SilentlyContinue

    if(-not (Test-Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation -ErrorAction SilentlyContinue))
    {
        New-Item -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows -Name '\CredentialsDelegation' -ErrorAction SilentlyContinue
    }

    if( -not (Get-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation -Name 'AllowFreshCredentialsWhenNTLMOnly' -ErrorAction SilentlyContinue))
    {
        New-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation -Name 'AllowFreshCredentialsWhenNTLMOnly' -value '1' -PropertyType dword -ErrorAction SilentlyContinue
    }

    if (-not (Get-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation -Name 'ConcatenateDefaults_AllowFreshNTLMOnly' -ErrorAction SilentlyContinue))
    {
        New-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation -Name 'ConcatenateDefaults_AllowFreshNTLMOnly' -value '1' -PropertyType dword -ErrorAction SilentlyContinue
    }

    if(-not (Test-Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -ErrorAction SilentlyContinue))
    {
        New-Item -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation -Name 'AllowFreshCredentialsWhenNTLMOnly' -ErrorAction SilentlyContinue
    }

    if (-not (Get-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Name '1' -ErrorAction SilentlyContinue))
    {
        New-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Name '1' -value "wsman/$env:COMPUTERNAME" -PropertyType string -ErrorAction SilentlyContinue
    }

    if (-not (Get-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Name '2' -ErrorAction SilentlyContinue))
    {
        New-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Name '2' -value "wsman/localhost" -PropertyType string -ErrorAction SilentlyContinue
    }

    if (-not (Get-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Name '3' -ErrorAction SilentlyContinue))
    {
        New-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Name '3' -value "wsman/*.$DomainName" -PropertyType string -ErrorAction SilentlyContinue
    }

    Write-Verbose "DONE:Setting up CredSSP for NTLM"
}

