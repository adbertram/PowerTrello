#Requires -Version 4
Set-StrictMode -Version Latest

$baseUrl = 'https://api.trello.com/1'
$ProjectName = 'PowerTrello'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Request-TrelloAccessToken {
	[CmdletBinding()]
	[OutputType('System.String')]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ApiKey,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Scope = 'read,write',

		[Parameter()]
		[ValidateSet('never', '1hour', '1day', '30days')]
		[string]$ExpirationTime = 'never',
	
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$ApplicationName = $ProjectName,
	
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[int]$AuthTimeout = 30
		
	)
	
	$ErrorActionPreference = 'Stop'
	try {
		$httpParams = @{
			'key'           = $apiKey
			'expiration'    = $ExpirationTime
			'scope'         = $Scope
			'response_type' = 'token'
			'name'          = $ApplicationName
			'return_url'    = 'https://trello.com'
		}
		
		$keyValues = @()
		$httpParams.GetEnumerator() | sort Name | foreach {
			$keyValues += "$($_.Key)=$($_.Value)"
		}
		
		$keyValueString = $keyValues -join '&'
		$authUri = "$baseUrl/authorize?$keyValueString"
		
		$IE = New-Object -ComObject InternetExplorer.Application
		$null = $IE.Navigate($authUri)
		$null = $IE.Visible = $true
		
		$timer = [System.Diagnostics.Stopwatch]::StartNew()
		while (($IE.LocationUrl -notmatch '^https://trello.com/token=') -and ($timer.Elapsed.TotalSeconds -lt $AuthTimeout)) {
			Start-Sleep -Seconds 1
		}
		$timer.Stop()
		
		if ($timer.Elapsed.TotalSeconds -ge $AuthTimeout) {
			throw 'Timeout waiting for user authorization.'
		}
		
		[regex]::Match($IE.LocationURL, 'token=(.+)').Groups[1].Value
		
	} catch {
		Write-Error $_.Exception.Message
	} finally {
		$null = $IE.Quit()	
	}
}

function Get-TrelloConfiguration {
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$RegistryKeyPath = "HKCU:\Software\$ProjectName",

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$ApiKey,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$AccessToken
	)
	
	$ErrorActionPreference = 'Stop'

	function decrypt([string]$TextToDecrypt) {
		$secure = ConvertTo-SecureString $TextToDecrypt
		$hook = New-Object system.Management.Automation.PSCredential("test", $secure)
		$plain = $hook.GetNetworkCredential().Password
		return $plain
	}

	try {
		if ($PSBoundParameters.ContainsKey('ApiKey') -and $PSBoundParameters.ContainsKey('AccessToken')) {
			$ak = $ApiKey
			$at = $AccessToken
		} elseif (-not (Test-Path -Path $RegistryKeyPath)) {
			throw "No $ProjectName configuration found in registry"
		} else {
			$keyValues = Get-ItemProperty -Path $RegistryKeyPath
			$ak = decrypt $keyValues.APIKey
			$at = decrypt $keyValues.AccessToken
		}
		$global:trelloConfig = [pscustomobject]@{
			'APIKey'      = $ak
			'AccessToken' = $at
			'String'      = "key=$ak&token=$at"	
		}
		$trelloConfig
	} catch {
		Write-Error $_.Exception.Message
	}
}

function Set-TrelloConfiguration {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ApiKey,
	
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$AccessToken,
	
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$RegistryKeyPath = "HKCU:\Software\$ProjectName"
	)

	function encrypt([string]$TextToEncrypt) {
		$secure = ConvertTo-SecureString $TextToEncrypt -AsPlainText -Force
		$encrypted = $secure | ConvertFrom-SecureString
		return $encrypted
	}
		
	if (-not (Test-Path -Path $RegistryKeyPath)) {
		New-Item -Path ($RegistryKeyPath | Split-Path -Parent) -Name ($RegistryKeyPath | Split-Path -Leaf) | Out-Null
	}
	
	$values = 'APIKey', 'AccessToken'
	foreach ($val in $values) {
		if ((Get-Item $RegistryKeyPath).GetValue($val)) {
			Write-Verbose "'$RegistryKeyPath\$val' already exists. Skipping."
		} else {
			Write-Verbose "Creating $RegistryKeyPath\$val"
			New-ItemProperty $RegistryKeyPath -Name $val -Value $(encrypt $((Get-Variable $val).Value)) -Force | Out-Null
		}
	}
}

function Invoke-PowerTrelloApiCall {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$PathParameters,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[hashtable]$QueryParameters,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$HttpMethod = 'GET'
	)

	$ErrorActionPreference = 'Stop'

	$body = @{
		'key'   = $trelloConfig.APIKey
		'token' = $trelloConfig.AccessToken
	}
	if ($PSBoundParameters.ContainsKey('QueryParameters')) {
		$body += $QueryParameters
	}

	$uri = '{0}/{1}' -f $baseUrl, $PathParameters

	Invoke-RestMethod -Method $HttpMethod -Uri $uri -Body $body
}

function Get-TrelloBoard {
	[CmdletBinding(DefaultParameterSetName = 'None')]
	param
	(
		[Parameter(ParameterSetName = 'ByName')]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		
		[Parameter(ParameterSetName = 'ById')]
		[ValidateNotNullOrEmpty()]
		[string]$Id,
	
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$IncludeClosedBoards
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$invApiParams = @{
				QueryParameter = @{}
			}
			if (-not $IncludeClosedBoards.IsPresent) {
				$invApiParams.QueryParameter.filter = 'open'
			}
			
			switch ($PSCmdlet.ParameterSetName) {
				'ByName' {
					$invApiParams.PathParameters = 'members/me/boards'
					$boards = Invoke-PowerTrelloApiCall @invApiParams
					$boards | where { $_.name -eq $Name }
				}
				'ById' {
					$invApiParams.PathParameters = "boards/$Id"
					Invoke-PowerTrelloApiCall @invApiParams
				}
				default {
					$invApiParams.PathParameters = 'members/me/boards'
					Invoke-PowerTrelloApiCall @invApiParams
				}
			}
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function New-TrelloBoard {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$TeamName,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('org', 'private', 'public')]
		[string]$Visibility = 'private'
	)

	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$body = @{
				key                   = $trelloConfig.APIKey
				token                 = $trelloConfig.AccessToken
				name                  = $Name
				defaultLists          = 'false'
				defaultLabels         = 'false'
				prefs_permissionLevel = $Visibility
			}
			if ($PSBoundParameters.ContainsKey('TeamName')) {
				$body.idOrganization = (Get-TrelloTeam -Name $TeamName).id
			}
			$invParams = @{
				Uri    = "$baseUrl/boards"
				Method = 'POST'
				Body   = $body
			}
			Invoke-RestMethod @invParams
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Remove-TrelloBoard {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[pscustomobject]$Board
	)

	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$invParams = @{
				Uri    = "$baseUrl/boards/$($Board.id)"
				Method = 'DELETE'
			}
			Invoke-RestMethod @invParams
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Enable-BoardPowerUp {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[pscustomobject]$Board,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('Custom Fields')]
		[string]$Name
	)

	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			switch ($Name) {
				'Custom Fields' {
					$pluginId = '56d5e249a98895a9797bebb9'
				}
				default {
					throw "Unrecognized input: [$_]"
				}
			}
			$body = @{
				key      = $trelloConfig.APIKey
				token    = $trelloConfig.AccessToken
				idPlugin = $pluginId
			}
			$invParams = @{
				Uri    = "$baseUrl/boards/$($Board.id)/boardPlugins"
				Method = 'POST'
				Body   = $body
			}
			$null = Invoke-RestMethod @invParams
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Get-TrelloList {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[Alias('id')]
		[string]$BoardId
		
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			Invoke-RestMethod -Uri "$baseUrl/boards/$BoardId/lists?$($trelloConfig.String)"
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Get-TrelloTeam {
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Name
	)
	
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$body = @{
				key   = $trelloConfig.APIKey
				token = $trelloConfig.AccessToken
			}
			$invParams = @{
				Uri  = '{0}/members/me/organizations?{1}' -f $baseUrl, $trelloConfig.String
				Body = $body
			}
			$teams = Invoke-RestMethod @invParams
			$whereFilter = { '*' }
			if ($PSBoundParameters.ContainsKey('Name')) {
				$whereFilter = { $_.displayName -eq $Name }
			}
			$teams.where($whereFilter)
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Get-TrelloTeamMember {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[pscustomobject]$Team
	)
	
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$body = @{
				key   = $trelloConfig.APIKey
				token = $trelloConfig.AccessToken
			}
			$invParams = @{
				Uri  = '{0}/organizations/{1}/members?{2}' -f $baseUrl, $Team.id, $trelloConfig.String
				Body = $body
			}
			Invoke-RestMethod @invParams
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function New-TrelloList {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$BoardId,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string[]]$Name,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Position
	)

	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$body = @{
				key     = $trelloConfig.APIKey
				token   = $trelloConfig.AccessToken
				idBoard = $BoardId
			}
			if ($PSBoundParameters.ContainsKey('Position')) {
				$body.pos = $Position
			}

			$invParams = @{
				Uri    = "$baseUrl/boards/$BoardId/lists"
				Method = 'POST'
			}
			foreach ($n in $Name) {
				$invParams.Body = ($body + @{ 'name' = $n })
				Invoke-RestMethod @invParams
			}
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Get-TrelloCard {
	[CmdletBinding(DefaultParameterSetName = 'None')]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[object]$Board,

		[Parameter(ParameterSetName = 'List')]
		[ValidateNotNullOrEmpty()]
		[object]$List,
		
		[Parameter(ParameterSetName = 'Name')]
		[ValidateNotNullOrEmpty()]
		[string]$Name,

		[Parameter(ParameterSetName = 'Id')]
		[ValidateNotNullOrEmpty()]
		[string]$Id,
		
		[Parameter(ParameterSetName = 'Label')]
		[ValidateNotNullOrEmpty()]
		[string]$Label,
	
		[Parameter(ParameterSetName = 'Due')]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('Today', 'Tomorrow', 'In7Days', 'In14Days')]
		[string]$Due,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$IncludeArchived,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$IncludeAllActivity
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$filter = 'open'
			if ($IncludeArchived.IsPresent) {
				$filter = 'all'
			}
			$cards = Invoke-RestMethod -Uri "$baseUrl/boards/$($Board.Id)/cards?customFieldItems=true&filter=$filter&$($trelloConfig.String)"
			if ($PSBoundParameters.ContainsKey('Label')) {
				$cards = $cards | where { if (($_.labels) -and $_.labels.Name -contains $Label) { $true } }
			} elseif ($PSBoundParameters.ContainsKey('Due')) {
				Write-Warning -Message 'Due functionality is not complete.'
			} elseif ($PSBoundParameters.ContainsKey('Name')) {
				$cards = $cards | where {$_.Name -eq $Name}
			} elseif ($PSBoundParameters.ContainsKey('Id')) {
				$cards = $cards | where {$_.idShort -eq $Id}
			} elseif ($PSBoundParameters.ContainsKey('List')) {
				$cards = $cards | where {$_.idList -eq $List.id }
			}

			$properties = @('*')
			if ($IncludeAllActivity.IsPresent) {
				$properties += @{n='Activity'; e={ Get-TrelloCardAction -Card $_ }}
			}
			$boardCustomFields = Get-TrelloCustomField -BoardId $Board.id
			$properties += @{n='CustomFields'; e={ 
					if ($_.Name -eq 'Using Custom Fields To Capture User Input For Your System Frontier Tools') {
						$foo = ''
					}
					if ('customFieldItems' -in $_.PSObject.Properties.Name) {
						$fieldObj = @{}
						$_.customFieldItems | foreach { 
							$cardField = $_
							$boardField = $boardCustomFields | Where { $_.id -eq $cardField.idCustomField }
							if ('value' -in $cardField.PSObject.Properties.Name) {
								if ('checked' -in $cardField.value.PSObject.Properties.Name) {
									if ($cardField.value.checked -eq 'true') {
										$val = $true
									} else {
										$val = $false
									}
								} else {
									$val = $cardField.value.text
								}
							} elseif ($cardFieldValue = $boardField.options | where { $_.id -eq $cardField.idValue }) {
								$val = $cardFieldValue.value.text
							}
							$fieldObj[$boardField.Name] = $val
						}
						[pscustomobject]$fieldObj
					}
				}
			}
			$cards | Select-Object -Property $properties
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Update-TrelloCard {
	[CmdletBinding(SupportsShouldProcess)]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[object]$Card,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Name,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Description,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$ListId
	)

	$ErrorActionPreference = 'Stop'

	$invParams = @{
		Body   = @{}
		Method = 'PUT'
	}

	$fieldMap = @{}
	if ($PSBoundParameters.ContainsKey('Name')) {
		$fieldMap.Name = 'name'
	}
	if ($PSBoundParameters.ContainsKey('Description')) {
		$fieldMap.Description = 'description'
	}
	if ($PSBoundParameters.ContainsKey('ListId')) {
		$fieldMap.ListId = 'idList'
	}
	$PSBoundParameters.GetEnumerator().where({$_.Key -ne 'Card'}).foreach({
			$trelloFieldName = $fieldMap[$_.Key]
			$invParams.Uri = '{0}/cards/{1}/{2}?value={3}&{4}' -f $baseUrl, $Card.id, $trelloFieldName, $_.Value, $trelloConfig.String
			Invoke-RestMethod @invParams
		})
}

function Move-TrelloCard {
	[CmdletBinding(SupportsShouldProcess)]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[object]$Card,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$NewListName
	)

	$ErrorActionPreference = 'Stop'

	if (-not ($list = (Get-TrelloList -BoardId $card.idBoard).where({ $_.name -eq $NewListName }))) {
		throw "The list [$($NewListName)] was not found."
	} else {
		$null = $Card | Update-TrelloCard -ListId $list.id
	}
	
}

function Get-TrelloLabel {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[object]$Board
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$uri = "$baseUrl/boards/{0}/labels?{1}" -f $Board.Id, $trelloConfig.String
			Invoke-RestMethod -Uri $uri
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function New-TrelloLabel {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[object]$Board,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('yellow', 'purple', 'blue', 'red', 'green', 'orange', 'black', 'sky', 'pink', 'lime', 'null')]
		[string]$Color = 'null'
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$body = @{
				key   = $trelloConfig.APIKey
				token = $trelloConfig.AccessToken
				name 	= $Name
				color = $Color
			}
			$invParams = @{
				Uri    = "{0}/boards/{1}/labels" -f $baseUrl, $Board.id
				Method = 'POST'
				Body   = $body
			}
			Invoke-RestMethod @invParams
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Add-TrelloCardComment {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[object]$Card,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Comment
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$uri = "$baseUrl/cards/{0}/actions/comments?{1}" -f $Card.Id, $trelloConfig.String
			Invoke-RestMethod -Uri $uri -Method Post -Body @{ text =$Comment }
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Add-TrelloBoardMember {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[object]$Board,

		[Parameter(Mandatory, ParameterSetName = 'ByMemberId')]
		[ValidateNotNullOrEmpty()]
		[string]$MemberId,

		[Parameter(Mandatory, ParameterSetName = 'ByEmail')]
		[ValidateNotNullOrEmpty()]
		[string]$Email,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('admin', 'normal', 'observer')]
		[string]$Type = 'normal'
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$invParams = @{
				Method = 'PUT'
			}
			if ($PSBoundParameters.ContainsKey('MemberId')) {
				$uri = '{0}/boards/{1}/members/{2}?type={3}' -f $baseUrl, $Board.id, $MemberId, $Type
			} elseif ($PSBoundParameters.ContainsKey('Email')) {
				$uri = '{0}/boards/{1}/members?email={2}' -f $baseUrl, $Board.id, $Email
				$invParams.Headers = @{ type = $Type }
			}
			$uri += '&key={0}&token={1}' -f $trelloConfig.APIKey, $trelloConfig.AccessToken
			$invParams.Uri = $uri
			$null = Invoke-RestMethod @invParams
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Get-TrelloTeamMember {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[object]$Team,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Name
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$invParams = @{
				Method = 'GET'
			}
			$pathParams = 'organizations/{0}/members' -f $Team.id
			if ($members = Invoke-PowerTrelloApiCall -PathParameters $pathParams) {
				$members | Add-Member -NotePropertyName 'teamId' -NotePropertyValue $Team.id
			}
			if ($PSBoundParameters.ContainsKey('Name')) {
				@($members).where({ $_.fullName -eq $Name })
			} else {
				$members
			}
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Add-TrelloTeamMember {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[object]$TeamMember,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('admin', 'normal')]
		[string]$Type = 'normal'
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$invParams = @{
				HttpMethod = 'PUT'
			}
			$invParams.PathParameters = 'organizations/{0}/members/{1}' -f $TeamMember.teamId, $TeamMember.id
			$invParams.QueryParameters = @{
				type = $Type
			}
			Invoke-PowerTrelloApiCall @invParams
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Add-TrelloCardMember {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[object]$Card,
	
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$MemberId
		
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$body = @{
				value = $MemberId
			}
			$uri = "$baseUrl/cards/{0}/idMembers?{1}" -f $Card.Id, $trelloConfig.String
			
			$null = Invoke-RestMethod -Uri $uri -Method POST -Body $body
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Get-TrelloBoardMember {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[Alias('Id')]
		[string]$BoardId
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			Invoke-RestMethod -Uri ("$baseUrl/boards/{0}/members?{1}" -f $BoardId, $trelloConfig.String)
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Get-TrelloCustomField {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[Alias('Id')]
		[string]$BoardId
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			Invoke-RestMethod -Uri ("$baseUrl/boards/{0}/customFields?{1}" -f $BoardId, $trelloConfig.String)
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Remove-TrelloCardMember {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[object]$Card,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$MemberId
		
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$uri = "$baseUrl/cards/{0}/idMembers/{1}?{2}" -f $Card.Id, $MemberId, $trelloConfig.String
			Invoke-RestMethod -Uri $uri -Method Delete
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function New-TrelloCardChecklist {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[pscustomobject]$Card,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string[]]$Item
	)

	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$commonBody = @{
				key   = $trelloConfig.APIKey
				token = $trelloConfig.AccessToken
			}
			$chParams = @{
				Uri    = "$baseUrl/checklists"
				Method = 'POST'
				Body   = $commonBody + @{ idCard = $Card.id; name = $Name}
			}
			$checkList = Invoke-RestMethod @chParams
			foreach ($i in $Item) {
				$null = $checkList | New-TrelloCardChecklistItem -Name $i
			}
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Get-TrelloCardChecklist {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[object]$Card,
	
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Name
		
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$checkLists = Invoke-RestMethod -Uri ("$baseUrl/cards/{0}/checklists?{1}" -f $Card.Id, $trelloConfig.String)
			if ($PSBoundParameters.ContainsKey('Name')) {
				$checkLists = $checkLists | Where-Object {$_.name -eq $Name}
			}
			foreach ($cl in $checklists) {
				$cl | Add-Member -NotePropertyName 'CardId' -NotePropertyValue $Card.id -PassThru
			}
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function New-TrelloCardChecklistItem {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[pscustomobject]$Checklist,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string[]]$Name
	)

	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$body = @{
				key   = $trelloConfig.APIKey
				token = $trelloConfig.AccessToken
			}
			$invParams = @{
				Uri    = "$baseUrl/checklists/{0}/checkItems" -f $Checklist.id
				Method = 'POST'
			}
			foreach ($i in $Name) {
				$invParams.Body = ($body + @{ 'name' = $i })
				Invoke-RestMethod @invParams
			}
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Get-TrelloCardChecklistItem {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[pscustomobject]$Checklist,
	
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Name
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			if ($PSBoundParameters.ContainsKey('Name')) {
				$items = $checklist.checkItems | where {$_.Name -eq $Name}
			} else {
				$items = $checklist.checkItems
			}
			foreach ($item in $items) {
				$item | Add-Member -NotePropertyName 'CheckListId' -NotePropertyValue $CheckList.id
				$item | Add-Member -NotePropertyName 'CardId' -NotePropertyValue $CheckList.CardId -PassThru
			}
			
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Set-TrelloCardChecklistItem {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[pscustomobject]$ChecklistItem,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Name
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$chParams = @{
				Uri    = '{0}/cards/{1}/checkItem/{2}?name={3}&{4}' -f $baseUrl, $ChecklistItem.CardId, $ChecklistItem.id, $Name, $trelloConfig.String
				Method = 'PUT'
			}
			$null = Invoke-RestMethod @chParams
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}


function Disable-TrelloCardChecklistItem {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[object]$Card,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[object]$Checklist,
		
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[pscustomobject]$ChecklistItem
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$params = @{
				'Uri'    = "$baseUrl/cards/{0}/checklist/{1}/checkItem/{2}?state=false&{3}" -f $Card.Id, $Checklist.Id, $ChecklistItem.Id, $trelloConfig.String
				'Method' = 'Put'
			}
			Invoke-RestMethod @params
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Enable-TrelloCardChecklistItem {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[object]$Card,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[object]$Checklist,
		
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[pscustomobject]$ChecklistItem
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$params = @{
				'Uri'    = "$baseUrl/cards/{0}/checklist/{1}/checkItem/{2}?state=true&{3}" -f $Card.Id, $Checklist.Id, $ChecklistItem.Id, $trelloConfig.String
				'Method' = 'Put'	
			}
			Invoke-RestMethod @params
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Remove-TrelloCardChecklistItem {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[pscustomobject]$ChecklistItem
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$params = @{
				'Uri'    = '{0}/cards/{1}/checkItem/{2}?{3}' -f $baseUrl, $CheckListItem.CardId, $ChecklistItem.Id, $trelloConfig.String
				'Method' = 'DELETE'
			}
			$null = Invoke-RestMethod @params
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}


function Add-TrelloCardAttachment {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[object]$Card,
	
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
		[string]$FilePath
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$fileName = $FilePath | Split-Path -Leaf
			$contents = Get-Content -Path $FilePath -Raw
			$params = @{
				'Uri'    = "$baseUrl/cards/{0}/attachments?file={1}&name={2}&{3}" -f $Card.Id, $contents, $fileName, $trelloConfig.String
				'Method' = 'Post'
			}
			$attachment = Invoke-RestMethod @params
			
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Get-TrelloCardAttachment {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[object]$Card,
	
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Name
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$params = @{
				'Uri' = "$baseUrl/cards/{0}/attachments?{1}" -f $Card.Id, $trelloConfig.String
			}
			$attachments = Invoke-RestMethod @params
			if ($PSBoundParameters.ContainsKey('Name')) {
				$attachments | Where-Object {$_.name -eq $Name}
			} else {
				$attachments	
			}
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Get-TrelloCardAction {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[object]$Card,
	
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('updateCard')] ## More are possible but haven't been tested
		[string]$ActionFilter,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('idList')]
		[string]$ActionFilterValue ## More exist but haven't been tested
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			if ($PSBoundParameters.ContainsKey('ActionFilter')) {
				$uri = "$baseUrl/cards/{0}/actions?filter={1}:{2}&filter=all&limit=1000&{3}" -f $Card.Id, $ActionFilter, $ActionFilterValue, $trelloConfig.String
			} else {
				$uri = "$baseUrl/cards/{0}/actions?filter=all&limit=1000&{1}" -f $Card.Id, $trelloConfig.String
			}
			Invoke-RestMethod -Uri $uri
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Get-TrelloBoardAction {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[object]$Board,
	
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('updateCard')] ## More are possible but haven't been tested
		[string]$ActionFilter,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('idList')]
		[string]$ActionFilterValue, ## More exist but haven't been tested,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[datetime]$Since
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			if ($PSBoundParameters.ContainsKey('ActionFilter')) {
				$uri = "$baseUrl/boards/{0}/actions?filter={1}:{2}&filter=all&fields=all&limit=1000&{3}" -f $Board.Id, $ActionFilter, $ActionFilterValue, $trelloConfig.String
			} elseif ($PSBoundParameters.ContainsKey('Since')) {
				$utcTime = $Since.ToUniversalTime().ToString('o')
				$uri = "$baseUrl/boards/{0}/actions?since={1}&filter=all&fields=all&limit=1000&{2}" -f $Board.Id, $utcTime, $trelloConfig.String
			} else {
				$uri = "$baseUrl/boards/{0}/actions?filter=all&fields=all&limit=1000&{1}" -f $Board.Id, $trelloConfig.String
			}
			Invoke-RestMethod -Uri $uri
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Set-TrelloCustomField {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[object]$Card,

		[Parameter(Mandatory)]
		[pscustomobject]$CustomFieldName,

		[Parameter(Mandatory)]
		[string]$CustomFieldValue
	)

	$ErrorActionPreference = 'Stop'

	$RestParams = @{
		Method      = 'PUT'
		ContentType = 'application/json'
	}

	if (-not ($cusField = (Get-TrelloCustomField -BoardId $Card.idBoard) | where {$_.name -eq $CustomFieldName})) {
		Write-Error -Message "Custom field [$($CustomFieldName)] could not be found on the board."
	} else {
		if ('options' -in $cusField.PSObject.Properties.Name) {
			$cusFieldId = ($cusField.options | where { $_.Value.text -eq $CustomFieldValue }).id
			$uri = '{0}/card/{1}/customField/{2}/item?{3}' -f $baseUrl, $Card.Id, $cusField.Id, $trelloConfig.String
			$body = (ConvertTo-Json @{ 
					'idValue' = $cusFieldid
				})
		} else {
			$uri = '{0}/card/{1}/customField/{2}/item?{3}' -f $baseUrl, $Card.Id, $cusField.id, $trelloConfig.String
			$body = (ConvertTo-Json @{ 'value' = @{ $cusField.type = $CustomFieldValue }})
		}

		$RestParams = @{
			Uri         = $uri
			Method      = 'PUT'
			ContentType = 'application/json'
			Body        = $body
		}

		$null = Invoke-RestMethod @RestParams
	}
	
}

function New-TrelloCustomField {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[pscustomobject]$Board,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Position = 'bottom',

		[Parameter()]
		[ValidateSet('number', 'date', 'text', 'checkbox', 'list')]
		[string]$Type,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$DisplayCardFront
	)

	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$body = @{
				key       = $trelloConfig.APIKey
				token     = $trelloConfig.AccessToken
				idModel   = $Board.id
				modelType = 'board'
				name      = $Name
				type      = $Type
				pos       = $Position
			}
			if ($PSBoundParameters.ContainsKey('DisplayCardFront')) {
				$body.display_cardFront = 'true'
			}
			$invParams = @{
				Uri    = "$baseUrl/customFields"
				Method = 'POST'
				Body   = $body
			}
			Invoke-RestMethod @invParams
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Get-TrelloCustomFieldOption {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[pscustomobject]$CustomField
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			if ('options' -notin $CustomField.PSObject.Properties.Name) {
				throw 'Custom field does not support options.'
			} else {
				$uri = '{0}/customField/{1}/options?{2}' -f $baseUrl, $CustomField.Id, $trelloConfig.String
				Invoke-RestMethod -Uri $uri
			}
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function New-TrelloCustomFieldOption {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[pscustomobject]$CustomField,

		[Parameter(Mandatory)]
		[string[]]$Value
	)

	$ErrorActionPreference = 'Stop'

	$RestParams = @{
		Method      = 'POST'
		ContentType = 'application/json'
	}

	if ('options' -in $CustomField.PSObject.Properties.Name) {
		$restParams.Uri = '{0}/customField/{1}/options?{2}' -f $baseUrl, $CustomField.Id, $trelloConfig.String
		foreach ($val in $Value) {
			$restParams.Body = (ConvertTo-Json @{ 'value' = @{ 'text' = $val } })

			$null = Invoke-RestMethod @RestParams
		}
	} else {
		throw 'Custom field does not support options.'
	}
}

function New-TrelloCard {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[Alias('Id')]
		[string]$ListId,
		
		[Parameter()]
		[string]$Name,

		[Parameter()]
		[string]$Description,

		[Parameter()]
		[datetime]$DueDate,

		[Parameter()]
		[string]$Position = 'bottom',

		[Parameter()]
		[string[]]$MemberId,

		[Parameter()]
		[string[]]$LabelId,

		[Parameter()]
		[string]$CustomFieldName,

		[Parameter()]
		[string]$CustomFieldValue,

		[Parameter()]
		[string]$urlSource,

		[Parameter()]
		[string]$fileSource,

		[Parameter()]
		[string]$idCardSource,

		[Parameter()]
		[string]$keepFromSource
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$NewCardHash = @{
				'idList' =$ListId
			}
			if(-not [string]::IsNullOrEmpty($Name)) {
				$NewCardHash['name'] = $Name
			}

			if(-not [string]::IsNullOrEmpty($Description)) {
				$NewCardHash['desc'] = $Description
			}

			if(-not [string]::IsNullOrEmpty($Position)) {
				$NewCardHash['pos'] = $Position
			}

			if(-not [string]::IsNullOrEmpty($MemberId)) {
				$NewCardHash['idMembers'] = $MemberId -join ','
			}

			if(-not [string]::IsNullOrEmpty($LabelId)) {
				$NewCardHash['idLabels'] = $LabelId -join ','
			}

			if(-not [string]::IsNullOrEmpty($urlSource)) {
				$NewCardHash['urlSource'] = $urlSource
			}

			if(-not [string]::IsNullOrEmpty($fileSource)) {
				$NewCardHash['fileSource'] = $fileSource
			}

			if(-not [string]::IsNullOrEmpty($idCardSource)) {
				$NewCardHash['idCardSource'] = $idCardSource
			}

			if(-not [string]::IsNullOrEmpty($keepFromSource)) {
				$NewCardHash['keepFromSource'] = $keepFromSource
			}
			if ($PSBoundParameters.ContainsKey('DueDate')) {
				$NewCardHash['due'] = $DueDate.ToShortDateString()
			}

			$RestParams = @{
				'uri'    = "$baseUrl/cards?$($trelloConfig.String)"
				'Method' = 'Post'
				'Body'   = $NewCardHash
			}

			$card = Invoke-RestMethod @RestParams

			if ($PSBoundParameters.ContainsKey('CustomFieldName')) {
				Set-TrelloCustomField -Card $card -CustomFieldName $CustomFieldName -CustomFieldValue $CustomFieldValue
			}
			$card
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}