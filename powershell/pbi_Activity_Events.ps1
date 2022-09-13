param(          
    $configFilePath = ".\Config.json"
)

$ErrorActionPreference = "Stop"
$VerbosePreference = "SilentlyContinue"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Import-Module SqlServer
Import-Module MicrosoftPowerBIMgmt.Admin





########################################################################

# load config and connect to PBI service

########################################################################

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

Set-Location $currentPath

if (Test-Path $configFilePath)
{
	$config = Get-Content $configFilePath | ConvertFrom-Json
}
else
{
	throw "Cannot find config file '$configFilePath'"
}

$sqlDestServer = $config.SqlDestination.Server
$sqlDestDatabase = $config.SqlDestination.Database

$credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $config.ServicePrincipal.AppId, ($config.ServicePrincipal.AppSecret | ConvertTo-SecureString -AsPlainText -Force)

Connect-PowerBIServiceAccount -Tenant $config.ServicePrincipal.TenantId -ServicePrincipal -Credential $credential;





########################################################################

# drop raw tables if they exist

########################################################################

$qry = "
	DROP TABLE IF EXISTS [raw].[pbi-activityEvent];

	CREATE TABLE [raw].[pbi-activityEvent] (
		`"id`" uniqueidentifier NULL
		,`"creationTime`" datetime NULL
		,`"operation`" nvarchar(255) NULL
		,`"data`" nvarchar(max) NULL		
	);
";
Invoke-Sqlcmd -Query $qry -ServerInstance $sqlDestServer -Database $sqlDestDatabase





########################################################################

# activity event section

########################################################################

$dayN = -1
Do
{
    #Loop through the last 7 days
    $activities = Get-PowerBIActivityEvent -StartDateTime (Get-Date).AddDays($dayN).ToString("yyyy-MM-ddT00:00:00") -EndDateTime (Get-Date).AddDays($dayN).ToString("yyyy-MM-ddT23:59:59") | ConvertFrom-Json

	foreach($a in $activities) {
		$id = $a.Id;
		$creationTime = $a.CreationTime;
		$operation = $a.Operation;
		$data = $a | ConvertTo-Json;
		
		$qry = "
			INSERT INTO [raw].[pbi-activityEvent] (
				`"id`"
				,`"creationTime`"
				,`"operation`"
				,`"data`"
			)
			
			VALUES (
				'$id'
				,cast('$creationTime' AS DATETIME)
				,'$operation'
				,'$data'
			);
		";
		Invoke-Sqlcmd -Query $qry -ServerInstance $sqlDestServer -Database $sqlDestDatabase							
	}

    $dayN--
} While ($dayN -ge -7)


