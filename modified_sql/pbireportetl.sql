(
	/*
		this set represents reports identified to be workspace-only reports not associated to an app
	*/
	SELECT DISTINCT
		cast(rpt.id AS nvarchar(50)) AS "id"
		,cast(concat( 
			cap.displayName
			,'||' 
			,'powerbi://api.powerbi.com/v1.0/myorg/' + ws.name
			,'||' 
			,case when (rpt.reportType = 'PowerBIReport') then 'Power BI Report' when (rpt.reportType = 'PaginatedReport') then 'Power BI Paginated Report' end
			,'||' 
			,rpt.id
			,'||||'     
		) AS nvarchar(4000)) AS BizKey 
		,cast(rpt.name AS nvarchar(255)) AS "name"
		,cast(rpt.description AS nvarchar(max)) AS "description"
		,cast(rpt.createdBySamAccountName AS nvarchar(50)) AS "createdBySamAccountName"
		,cast(rpt.createdByDomain AS nvarchar(50)) AS "createdByDomain"
		,cast(rpt.createdByUserPrincipalName AS nvarchar(255)) AS "createdByUserPrincipalName"
		,cast(
			nullif(
				concat(
					(SELECT TOP(1) u.LogonDomain FROM atlas_ldap.dbo.Users AS u WHERE u.DomainName = cast(rpt.createdByDomain AS nvarchar(50)))
					,'\'
					,cast(rpt.createdBySamAccountName AS nvarchar(50))
				)
				,'\'
			) AS nvarchar(100)
		) AS "createdBy"
		,cast(rpt.createdDateTime AS datetime) AS "createdDateTime"
		,cast(rpt.modifiedBySamAccountName AS nvarchar(50)) AS "modifiedBySamAccountName"
		,cast(rpt.modifiedByDomain AS nvarchar(50)) AS "modifiedByDomain"
		,cast(rpt.modifiedByUserPrincipalName AS nvarchar(255)) AS "modifiedByUserPrincipalName"	
		,cast(
			nullif(
				concat(
					(SELECT TOP(1) u.LogonDomain FROM atlas_ldap.dbo.Users AS u WHERE u.DomainName = cast(rpt.modifiedByDomain AS nvarchar(50)))
					,'\'
					,cast(rpt.modifiedBySamAccountName AS nvarchar(50))
				)
				,'\'
			) AS nvarchar(100)
		) AS "modifiedBy"
		,cast(rpt.modifiedDateTime AS datetime) AS "modifiedDateTime"
		,cast(rpt.webUrl AS nvarchar(500)) AS "webUrl"
		--,rpt.reportType	
		,cast(
			case
				when (rpt.reportType = 'PowerBIReport') then 'Power BI Report'
				when (rpt.reportType = 'PaginatedReport') then 'Power BI Paginated Report'
			end AS nvarchar(50)
		) AS "reportType"
		,cast(rpt.appId AS nvarchar(50)) AS "appId"
		,cast(ws.id AS nvarchar(50)) AS "workspaceId"
		,cast(ws.name AS nvarchar(255)) AS "workspaceName"
		,cast('powerbi://api.powerbi.com/v1.0/myorg/' + ws.name AS nvarchar(500)) AS "workspaceConnection"
		,cast('report' AS nvarchar(50)) AS "source"
		,cast(cap.id AS nvarchar(50)) AS "capacityId"
		,cast(cap.displayName AS nvarchar(50)) AS "capacityName"
		,cast(N'Y' AS nchar(1)) AS "defaultVisibilityYN"
	FROM (

		/*
			this set represents workspace only reports with a refreshable dataset
		*/
		SELECT
			rpt.name
		FROM [raw].[pbi-report] AS rpt

			INNER JOIN [raw].[pbi-workspaceReport] AS wsRpt ON
				rpt.id = wsRpt.reportId

			INNER JOIN [raw].[pbi-workspace] AS ws ON
				wsRpt.workspaceId = ws.id

			INNER JOIN [raw].[pbi-capacity] AS cap ON
				ws.capacityId = cap.id

			LEFT JOIN [raw].[pbi-dataset] AS ds ON
				rpt.datasetId = ds.id
	
		WHERE
			ws.isOnDedicatedCapacity = 1			
			AND (
				(rpt.reportType = 'PaginatedReport' AND ds.id IS NULL)	-- paginated reports do not have an associated dataset
				OR ds.IsRefreshable = 1
			)
			AND rpt.appId IS NULL	-- exclude reports published to an app
					
		/*
			set operator to exclude any workspace reports found to be published to an app - 
			set operation is based off the name of the report (presuming workspace reports and reports published to an app are named the same)
		*/
		EXCEPT

		/*
			this set represents app reports with a refreshable dataset
		*/
		SELECT
			replace(rpt.name, '[App] ', '') AS name
		FROM [atlas_staging].[raw].[pbi-report] AS rpt

			INNER JOIN [raw].[pbi-workspaceReport] AS wsRpt ON
				rpt.id = wsRpt.reportId

			INNER JOIN [raw].[pbi-workspace] AS ws ON
				wsRpt.workspaceId = ws.id

			INNER JOIN [raw].[pbi-capacity] AS cap ON
				ws.capacityId = cap.id

			LEFT JOIN [raw].[pbi-dataset] AS ds ON
				rpt.datasetId = ds.id
	
		WHERE
			ws.isOnDedicatedCapacity = 1			
			AND (
				(rpt.reportType = 'PaginatedReport' AND ds.id IS NULL)	-- paginated reports do not have an associated dataset
				OR ds.IsRefreshable = 1									-- dataset is on a refresh schedule
			)
			AND rpt.appId IS NOT NULL		-- report is published to an app
		
	) AS dsWsRpt

		INNER JOIN [raw].[pbi-report] AS rpt ON
			dsWsRpt.name = rpt.name

		INNER JOIN [raw].[pbi-workspaceReport] AS wsRpt ON
			rpt.id = wsRpt.reportId

		INNER JOIN [raw].[pbi-workspace] AS ws ON
			wsRpt.workspaceId = ws.id

		INNER JOIN [raw].[pbi-capacity] AS cap ON
			ws.capacityId = cap.id

		LEFT JOIN [raw].[pbi-dataset] AS ds ON
			rpt.datasetId = ds.id

	WHERE
		ws.isOnDedicatedCapacity = 1			
		AND (
			(rpt.reportType = 'PaginatedReport' AND ds.id IS NULL)	-- paginated reports do not have an associated dataset
			OR ds.IsRefreshable = 1									-- dataset is on a refresh schedule
		)
		AND rpt.appId IS NULL		-- exclude reports published to an app
)		


/* include reports published to an app */
UNION


(
	/*
		this set represents app reports with a refreshable dataset
	*/
	SELECT DISTINCT
		cast(rpt.id AS nvarchar(50)) AS "id"
		,cast(concat( 
			cap.displayName
			,'||' 
			,'powerbi://api.powerbi.com/v1.0/myorg/' + ws.name
			,'||' 
			,case when (rpt.reportType = 'PowerBIReport') then 'Power BI Report' when (rpt.reportType = 'PaginatedReport') then 'Power BI Paginated Report' end
			,'||' 
			,rpt.id
			,'||||'     
		) AS nvarchar(4000)) AS BizKey 
		,cast(replace(rpt.name, '[App] ', '') AS nvarchar(255)) AS "name"
		,cast(rpt.description AS nvarchar(max)) AS "description"
		,cast(rpt.createdBySamAccountName AS nvarchar(50)) AS "createdBySamAccountName"
		,cast(rpt.createdByDomain AS nvarchar(50)) AS "createdByDomain"
		,cast(rpt.createdByUserPrincipalName AS nvarchar(255)) AS "createdByUserPrincipalName"
		,cast(
			nullif(
				concat(
					(SELECT TOP(1) u.LogonDomain FROM atlas_ldap.dbo.Users AS u WHERE u.DomainName = cast(rpt.createdByDomain AS nvarchar(50)))
					,'\'
					,cast(rpt.createdBySamAccountName AS nvarchar(50))
				)
				,'\'
			) AS nvarchar(100)
		) AS "createdBy"
		,cast(rpt.createdDateTime AS datetime) AS "createdDateTime"
		,cast(rpt.modifiedBySamAccountName AS nvarchar(50)) AS "modifiedBySamAccountName"
		,cast(rpt.modifiedByDomain AS nvarchar(50)) AS "modifiedByDomain"
		,cast(rpt.modifiedByUserPrincipalName AS nvarchar(255)) AS "modifiedByUserPrincipalName"	
		,cast(
			nullif(
				concat(
					(SELECT TOP(1) u.LogonDomain FROM atlas_ldap.dbo.Users AS u WHERE u.DomainName = cast(rpt.modifiedByDomain AS nvarchar(50)))
					,'\'
					,cast(rpt.modifiedBySamAccountName AS nvarchar(50))
				)
				,'\'
			) AS nvarchar(100)
		) AS "modifiedBy"
		,cast(rpt.modifiedDateTime AS datetime) AS "modifiedDateTime"
		,cast(rpt.webUrl AS nvarchar(500)) AS "webUrl"
		--,rpt.reportType	
		,cast(
			case
				when (rpt.reportType = 'PowerBIReport') then 'Power BI Report'
				when (rpt.reportType = 'PaginatedReport') then 'Power BI Paginated Report'
			end AS nvarchar(50)
		) AS "reportType"
		,cast(rpt.appId AS nvarchar(50)) AS "appId"
		,cast(ws.id AS nvarchar(50)) AS "workspaceId"
		,cast(ws.name AS nvarchar(255)) AS "workspaceName"
		,cast('powerbi://api.powerbi.com/v1.0/myorg/' + ws.name AS nvarchar(500)) AS "workspaceConnection"
		,cast('report' AS nvarchar(50)) AS "source"
		,cast(cap.id AS nvarchar(50)) AS "capacityId"
		,cast(cap.displayName AS nvarchar(50)) AS "capacityName"
		,cast(N'Y' AS nchar(1)) AS "defaultVisibilityYN"
	FROM [raw].[pbi-report] AS rpt

		INNER JOIN [raw].[pbi-workspaceReport] AS wsRpt ON
			rpt.id = wsRpt.reportId

		INNER JOIN [raw].[pbi-workspace] AS ws ON
			wsRpt.workspaceId = ws.id

		INNER JOIN [raw].[pbi-capacity] AS cap ON
			ws.capacityId = cap.id

		LEFT JOIN [raw].[pbi-dataset] AS ds ON
			rpt.datasetId = ds.id
	
	WHERE
		ws.isOnDedicatedCapacity = 1			
		AND (
			(rpt.reportType = 'PaginatedReport' AND ds.id IS NULL)	-- paginated reports do not have an associated dataset
			OR ds.IsRefreshable = 1									-- dataset is on a refresh schedule
		)
		AND rpt.appId IS NOT NULL		-- report is published to an app
)