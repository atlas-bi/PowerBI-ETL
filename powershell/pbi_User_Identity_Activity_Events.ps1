param(          
    $configFilePath = ".\Config.json"
)

$ErrorActionPreference = "Stop"
$VerbosePreference = "SilentlyContinue"

Add-Type -AssemblyName System.Web

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Import-Module SqlServer





########################################################################

# function declarations

########################################################################


function Get-AuthToken
{
   [cmdletbinding()]
    param
    (
        [string]
        $authority = "https://login.microsoftonline.com",
        [string]
        $tenantid,
        [string]
        $appid,
        [string]
        $appsecret ,
        [string]
        $resource         
	)

    write-verbose "getting authentication token"
    
    $granttype = "client_credentials"    

    $tokenuri = "$authority/$tenantid/oauth2/token?api-version=1.0"

    $appsecret = [System.Web.HttpUtility]::urlencode($appsecret)

    $body = "grant_type=$granttype&client_id=$appid&resource=$resource&client_secret=$appsecret"    

    $token = invoke-restmethod -method post -uri $tokenuri -body $body

    $accesstoken = $token.access_token    

    write-output $accesstoken

}




########################################################################

# load config

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






########################################################################

# get the auth token

########################################################################

Write-Host "Getting OAuth Token..."

$authtoken = Get-AuthToken -resource "https://graph.microsoft.com" -appid $config.ServicePrincipal.AppId -appsecret $config.ServicePrincipal.AppSecret -tenantid $config.ServicePrincipal.TenantId

$graphurl = "https://graph.microsoft.com/v1.0"

$headers = @{
	'Content-Type'= "application/json"
	'Authorization'= "Bearer $authToken"
}    





########################################################################

# get identity info and update the local db
#
# basic idea is the following:
# 		use the user identifier from the PowerBI data;
#		make a call to MS Graph API to get the UPN (UserPrincipalName), on prem SamAccountName and on prem Domain name for the user;
#		persist the data locally in the raw table;
#		the userSamAccountName and userDomain will be used later on when staging the PBI users;

########################################################################

Write-Host "Caling Graph API to get user identity info..."

$userUpns = Invoke-Sqlcmd -Query "SELECT DISTINCT pbiAE.userId AS upn FROM [raw].[PbiActivityEvent] AS pbiAE WHERE pbiAE.userId IS NOT NULL;" -ServerInstance $sqlDestServer -Database $sqlDestDatabase;

foreach($usr in $userUpns) {
	$usrUpn = $usr["upn"];	
	try {
		$url = "$graphUrl/users/" + $usrUpn + "?`$select=UserPrincipalName,onPremisesUserPrincipalName,onPremisesSamAccountName,onPremisesDomainName"
		#write-host $url
		$result = Invoke-RestMethod -Method Get -Uri $url -Headers $headers;
		$identity = $result;
		
		$upn = $identity.userPrincipalName;
		#$upn = $identity.onPremisesUserPrincipalName;
		$san = $identity.onPremisesSamAccountName;
		$dn = $identity.onPremisesDomainName;
		
		$sql = "UPDATE [raw].[PbiActivityEvent] SET userPrincipalName = '$upn', userSamAccountName = '$san', userDomain = '$dn' WHERE userId = '$usrUpn';";
		Invoke-Sqlcmd -Query $sql -ServerInstance $sqlDestServer -Database $sqlDestDatabase;		
	}
	catch [System.Net.WebException]
    {
        $ex = $_.Exception;
		
		$throwError = $false;
		try {
			$statusCode = $ex.Response.StatusCode
			if ($statusCode -eq "NotFound") {
				Write-Host "Skipping record: Could not find identity: $usrUpn";				
			}
			else {
				$throwError = $true;
			}
		}
		catch {
			$throwError = $true;
		}
		finally {
			if ($throwError) {
				throw $ex;
			}	
		}      		
    }
}


