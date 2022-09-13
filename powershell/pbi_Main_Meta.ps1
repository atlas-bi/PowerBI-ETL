param(          
    $configFilePath = ".\Config.json"
)

$ErrorActionPreference = "Stop"
$VerbosePreference = "SilentlyContinue"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Import-Module SqlServer
Import-Module MicrosoftPowerBIMgmt.Profile





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

Invoke-Sqlcmd -Query "DROP TABLE IF EXISTS [raw].[pbi-workspace];" -ServerInstance $sqlDestServer -Database $sqlDestDatabase;
Invoke-Sqlcmd -Query "DROP TABLE IF EXISTS [raw].[pbi-workspaceReport];" -ServerInstance $sqlDestServer -Database $sqlDestDatabase;
Invoke-Sqlcmd -Query "DROP TABLE IF EXISTS [raw].[pbi-workspaceUser];" -ServerInstance $sqlDestServer -Database $sqlDestDatabase;
Invoke-Sqlcmd -Query "DROP TABLE IF EXISTS [raw].[pbi-report];" -ServerInstance $sqlDestServer -Database $sqlDestDatabase;
Invoke-Sqlcmd -Query "DROP TABLE IF EXISTS [raw].[pbi-dataset];" -ServerInstance $sqlDestServer -Database $sqlDestDatabase;
Invoke-Sqlcmd -Query "DROP TABLE IF EXISTS [raw].[pbi-app];" -ServerInstance $sqlDestServer -Database $sqlDestDatabase;
Invoke-Sqlcmd -Query "DROP TABLE IF EXISTS [raw].[pbi-capacity];" -ServerInstance $sqlDestServer -Database $sqlDestDatabase;





########################################################################

# workspace section

########################################################################

#get the groups/workspaces - Active only
#limit results to 500 at a time

$topN = 500;
$iteration = 0;
$skipN = $topN * $iteration;
$filter = "type eq 'Workspace' and state eq 'Active'";

#$baseUrl = "https://api.powerbi.com/v1.0/myorg/admin/groups/?%24top=" + $topN + "&%24expand=reports,users&%24filter=" + $filter + "&%24skip=";
$baseUrl = "https://api.powerbi.com/v1.0/myorg/admin/groups/?%24top=" + $topN + "&%24expand=reports&%24filter=" + $filter + "&%24skip=";
$url = $baseUrl + $skipN;

$result = Invoke-PowerBIRestMethod -Url $url -Method Get;
$groups = ($result | ConvertFrom-Json).value;

$workspaceList = @();
$workspaceReportList = @();
$workspaceUserList = @();

while ($true) {
	
	if ($groups.Count -eq 0) {
		break;
	}

	foreach($grp in $groups) {
		$reports = $grp.reports;
		#$users = $grp.users;
				
		$workspaceList += New-Object psobject -Property @{
			id = $grp.id
			name = $grp.name
			description = $grp.description
			isOnDedicatedCapacity = $grp.isOnDedicatedCapacity
			isReadOnly = $grp.isReadOnly
			capacityId = $grp.capacityId
			state = $grp.state
			type = $grp.type
		};

		foreach($rpt in $reports) {
			$workspaceReportList += New-Object psobject -Property @{
				reportId = $rpt.id
				workspaceId = $grp.id
			};			
		}
		
		foreach($usr in $users) {
			$workspaceUserList += New-Object psobject -Property @{
				identifier = $usr.identifier
				emailAddress = $usr.emailAddress
				groupUserAccessRight = $usr.groupUserAccessRight
				displayName = $usr.displayName
				principalType = $usr.principalType
				graphId = $usr.graphId
				workspaceId = $grp.id
				userPrincipalName = $null
				samAccountName = $null
				domain = $null	
			};			
		}	
	}
	
	$iteration++;
	$skipN = $topN * $iteration;
	
	$url = $baseUrl + $skipN;
	$result = Invoke-PowerBIRestMethod -Url $url -Method Get;
	$groups = ($result | ConvertFrom-Json).value;
	
}


########################################################################

# reports section

########################################################################


$topN = 500;
$iteration = 0;
$skipN = $topN * $iteration;
#$filter = "";

$baseUrl = "https://api.powerbi.com/v1.0/myorg/admin/reports/?%24top=" + $topN + "&%24skip=";
$url = $baseUrl + $skipN;


$reportList = @();

$result = Invoke-PowerBIRestMethod -Url $url -Method Get; 
$reports = ($result | ConvertFrom-Json).value;

while ($true) {
	
	if ($reports.Count -eq 0) {
		break;
	}

	foreach($rpt in $reports) {
		$reportList += New-Object psobject -Property @{
			id = $rpt.id
			name = $rpt.name
			description = $rpt.description
			embedUrl = $rpt.embedUrl
			webUrl = $rpt.webUrl
			reportType = $rpt.reportType
			sensitivityLabel = $rpt.sensitivityLabel
			createdBy = $rpt.createdBy
			createdDateTime = $rpt.createdDateTime
			createdByDomain = $null
			createdBySamAccountName = $null
			createdByUserPrincipalName = $null
			modifiedBy = $rpt.modifiedBy
			modifiedDateTime = $rpt.modifiedDateTime
			modifiedByDomain = $null
			modifiedBySamAccountName = $null
			modifiedByUserPrincipalName = $null	
			appId = $rpt.appId
			datasetId = $rpt.datasetId
		};			
	}
	
	$iteration++;
	$skipN = $topN * $iteration;
	
	$url = $baseUrl + $skipN;
	$result = Invoke-PowerBIRestMethod -Url $url -Method Get;
	$reports = ($result | ConvertFrom-Json).value;

}





########################################################################

# dataset section

########################################################################


$topN = 500;
$iteration = 0;
$skipN = $topN * $iteration;
#$filter = "";

$baseUrl = "https://api.powerbi.com/v1.0/myorg/admin/datasets/?%24top=" + $topN + "&%24skip=";
$url = $baseUrl + $skipN;



$datasetList = @();

$result = Invoke-PowerBIRestMethod -Url $url -Method Get; 
$datasets = ($result | ConvertFrom-Json).value;

while ($true) {
	
	if ($datasets.Count -eq 0) {
		break;
	}

	foreach($ds in $datasets) {
		$datasetList += New-Object psobject -Property @{
			id = $ds.id
			name = $ds.name
			description = $ds.description
			ContentProviderType = $ds.ContentProviderType
			CreateReportEmbedURL = $ds.CreateReportEmbedURL
			CreatedDate = $ds.CreatedDate
			IsEffectiveIdentityRequired = $ds.IsEffectiveIdentityRequired
			IsEffectiveIdentityRolesRequired = $ds.IsEffectiveIdentityRolesRequired
			IsOnPremGatewayRequired = $ds.IsOnPremGatewayRequired
			IsRefreshable = $ds.IsRefreshable
			QnaEmbedURL = $ds.QnaEmbedURL
			addRowsAPIEnabled = $ds.addRowsAPIEnabled
			configuredBy = $ds.configuredBy
			schemaMayNotBeUpToDate = $ds.schemaMayNotBeUpToDate
			schemaRetrievalError = $ds.schemaRetrievalError
			sensitivityLabel = $ds.sensitivityLabel
			webUrl = $ds.webUrl
		};			
	}
	
	$iteration++;
	$skipN = $topN * $iteration;
	
	$url = $baseUrl + $skipN;
	$result = Invoke-PowerBIRestMethod -Url $url -Method Get;
	$datasets = ($result | ConvertFrom-Json).value;

}






########################################################################

# app section

########################################################################


$topN = 500;
$iteration = 0;
$skipN = $topN * $iteration;
#$filter = "";

$baseUrl = "https://api.powerbi.com/v1.0/myorg/admin/apps/?%24top=" + $topN + "&%24skip=";
$url = $baseUrl + $skipN;



$appList = @();

$result = Invoke-PowerBIRestMethod -Url $url -Method Get; 
$apps = ($result | ConvertFrom-Json).value;

while ($true) {
	
	if ($apps.Count -eq 0) {
		break;
	}

	foreach($app in $apps) {
		$appList += New-Object psobject -Property @{
			id = $app.id
			name = $app.name
			description = $app.description
			lastUpdate = $app.lastUpdate
			publishedBy = $app.publishedBy
		};			
	}
	
	$iteration++;
	$skipN = $topN * $iteration;
	
	$url = $baseUrl + $skipN;
	$result = Invoke-PowerBIRestMethod -Url $url -Method Get;
	$apps = ($result | ConvertFrom-Json).value;

}






########################################################################

# capacity section

########################################################################

$baseUrl = "https://api.powerbi.com/v1.0/myorg/admin/capacities";
$url = $baseUrl;

$capacityList = @();

$result = Invoke-PowerBIRestMethod -Url $url -Method Get; 
$capacities = ($result | ConvertFrom-Json).value;


foreach($cap in $capacities) {
	$capacityList += New-Object psobject -Property @{
		id = $cap.id
		displayName = $cap.displayName
		sku = $cap.sku
		state = $cap.state
		capacityUserAccessRight = $cap.capacityUserAccessRight
		region = $cap.region
	};			
}
	





Write-SqlTableData -DatabaseName $sqlDestDatabase -SchemaName "raw" -TableName "pbi-workspace" -ServerInstance $sqlDestServer -InputData $workspaceList -Force;
Write-SqlTableData -DatabaseName $sqlDestDatabase -SchemaName "raw" -TableName "pbi-workspaceReport" -ServerInstance $sqlDestServer -InputData $workspaceReportList -Force;
Write-SqlTableData -DatabaseName $sqlDestDatabase -SchemaName "raw" -TableName "pbi-workspaceUser" -ServerInstance $sqlDestServer -InputData $workspaceUserList -Force;
Write-SqlTableData -DatabaseName $sqlDestDatabase -SchemaName "raw" -TableName "pbi-report" -ServerInstance $sqlDestServer -InputData $reportList -Force;
Write-SqlTableData -DatabaseName $sqlDestDatabase -SchemaName "raw" -TableName "pbi-dataset" -ServerInstance $sqlDestServer -InputData $datasetList -Force;
Write-SqlTableData -DatabaseName $sqlDestDatabase -SchemaName "raw" -TableName "pbi-app" -ServerInstance $sqlDestServer -InputData $appList -Force;
Write-SqlTableData -DatabaseName $sqlDestDatabase -SchemaName "raw" -TableName "pbi-capacity" -ServerInstance $sqlDestServer -InputData $capacityList -Force;



