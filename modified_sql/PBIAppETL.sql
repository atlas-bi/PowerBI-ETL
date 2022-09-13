SELECT
	cast(app.id AS nvarchar(50)) AS "id"
	,cast(concat( 
		rpt.capacityName
		,'||' 
		,'powerbi://api.powerbi.com/v1.0/myorg/' + rpt.workspaceName
		,'||' 
		,'Power BI App'
		,'||' 
		,app.id
		,'||||'     
	) AS nvarchar(4000)) AS BizKey 
	,cast(replace(app.name, '[App] ', '') AS nvarchar(255)) AS "name"
	,cast(app.description AS nvarchar(max)) AS "description"
	,cast(usr.samAccountName AS nvarchar(50)) AS "createdBySamAccountName"
	,cast(usr.domain AS nvarchar(50)) AS "createdByDomain"
	,cast(usr.userPrincipalName AS nvarchar(255)) AS "createdByUserPrincipalName"
	,cast(
		coalesce(
			nullif(
				concat(
					(SELECT TOP(1) u.LogonDomain FROM atlas_ldap.dbo.Users AS u WHERE u.DomainName = cast(usr.domain AS nvarchar(50)))
					,'\'
					,cast(usr.samAccountName AS nvarchar(50))
				)
				,'\'
			)
			,usr2.account
			,app.publishedBy
		)AS nvarchar(100)
	) AS "createdBy"
	,cast(left(app.lastUpdate, 19) AS datetime) AS "createdDateTime"
	,cast(usr.samAccountName AS nvarchar(50)) AS "modifiedBySamAccountName"
	,cast(usr.domain AS nvarchar(50)) AS "modifiedByDomain"
	,cast(usr.userPrincipalName AS nvarchar(255)) AS "modifiedByUserPrincipalName"
	,cast(
		coalesce(
			nullif(
				concat(
					(SELECT TOP(1) u.LogonDomain FROM atlas_ldap.dbo.Users AS u WHERE u.DomainName = cast(usr.domain AS nvarchar(50)))
					,'\'
					,cast(usr.samAccountName AS nvarchar(50))
				)
				,'\'
			)
			,usr2.account
			,app.publishedBy
		)AS nvarchar(100)
	) AS "modifiedBy"
	,cast(left(app.lastUpdate, 19) AS datetime) AS "modifiedDateTime"
	,cast(left(rpt.webUrl, 75) AS nvarchar(500)) AS "webUrl"
	--,rpt.reportType	
	,cast('Power BI App' AS nvarchar(50)) AS "reportType"
	,cast(rpt.appId AS nvarchar(50)) AS "appId"
	,cast(rpt.workspaceId AS nvarchar(50)) AS "workspaceId"
	,cast(rpt.workspaceName AS nvarchar(255)) AS "workspaceName"
	,cast(rpt.workspaceConnection AS nvarchar(500)) AS "workspaceConnection"
	,cast('app' AS nvarchar(50)) AS "source"
	,cast(rpt.capacityId AS nvarchar(50)) AS "capacityId"
	,cast(rpt.capacityName AS nvarchar(50)) AS "capacityName"
	,cast(N'Y' AS nchar(1)) AS "defaultVisibilityYN"
FROM [raw].[pbi-app] AS app

	CROSS APPLY (
		SELECT TOP(1)
			r.capacityName
			,r.workspaceName
			,r.webUrl
			,r.appId
			,r.workspaceId
			,r.workspaceConnection
			,r.capacityId
		FROM [raw].[PbiReport] AS r
		WHERE
			r.appId = app.id
	) AS rpt

	OUTER APPLY (
		SELECT TOP(1)
			u.domain
			,u.samAccountName
			,u.userPrincipalName
		FROM [raw].[pbi-workspaceUser] AS u
		WHERE
			u.displayName = app.publishedBy
	) AS usr

	OUTER APPLY (
		SELECT TOP(1)
			cast(
				nullif(
					concat(
						u.LogonDomain
						,'\'
						,u.SamAccountName
					)
					,'\'
				) AS nvarchar(100)
			) AS "account"
		FROM [atlas_ldap].[dbo].[Users] AS u
		WHERE
			u.FirstName IN (SELECT value FROM string_split(app.publishedBy, ' '))
			AND u.LastName IN (SELECT value FROM string_split(app.publishedBy, ' '))
			AND u.LogonDomain = ?
	) AS usr2

WHERE
	app.id IN (SELECT rpt.appId from [raw].[PbiReport] AS rpt);