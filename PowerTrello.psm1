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
		[string]$RegistryKeyPath = "HKCU:\Software\$ProjectName"
	)
	
	$ErrorActionPreference = 'Stop'

	function decrypt([string]$TextToDecrypt) {
		$secure = ConvertTo-SecureString $TextToDecrypt
		$hook = New-Object system.Management.Automation.PSCredential("test", $secure)
		$plain = $hook.GetNetworkCredential().Password
		return $plain
	}

	try {
		if (-not (Test-Path -Path $RegistryKeyPath)) {
			Write-Verbose "No $ProjectName configuration found in registry"
		} else {
			$keyValues = Get-ItemProperty -Path $RegistryKeyPath
			$ak = decrypt $keyValues.APIKey
			$at = decrypt $keyValues.AccessToken
			$global:trelloConfig = [pscustomobject]@{
				'APIKey'      = $ak
				'AccessToken' = $at
				'String'      = "key=$ak&token=$at"	
			}
			$trelloConfig
		}
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
			$getParams = @{
				'key'   = $trelloConfig.APIKey
				'token' = $trelloConfig.AccessToken
			}
			if (-not $IncludeClosedBoards.IsPresent) {
				$getParams.filter = 'open'
			}
			
			$keyValues = @()
			$getParams.GetEnumerator() | foreach {
				$keyValues += "$($_.Key)=$($_.Value)"
			}
			
			$paramString = $keyValues -join '&'
			
			switch ($PSCmdlet.ParameterSetName) {
				'ByName' {
					$uri = "$baseUrl/members/me/boards"
					$boards = Invoke-RestMethod -Uri ('{0}?{1}' -f $uri, $paramString)
					$boards | where { $_.name -eq $Name }
				}
				'ById' {
					$uri = "$baseUrl/boards/$Id"
					Invoke-RestMethod -Uri ('{0}?{1}' -f $uri, $paramString)
				}
				default {
					$uri = "$baseUrl/members/me/boards"
					Invoke-RestMethod -Uri ('{0}?{1}' -f $uri, $paramString)
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
		[string]$Description
	)

	$ErrorActionPreference = 'Stop'

	$invParams = @{
		Body   = @{}
		Method = 'PUT'
	}

	$fieldMap = @{
		Name        = 'name'
		Description = 'desc'
	}
	$PSBoundParameters.GetEnumerator().where({$_.Key -ne 'Card'}).foreach({
			$trelloFieldName = $fieldMap[$_.Key]
			$invParams.Uri = '{0}/cards/{1}/{2}?value={3}&{4}' -f $baseUrl, $Card.id, $trelloFieldName, $_.Value, $trelloConfig.String
			Invoke-RestMethod @invParams
		})
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

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$MemberId,

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
			$body = @{
				key   = $trelloConfig.APIKey
				token = $trelloConfig.AccessToken
				type  = $Type
			}
			$invParams = @{
				Uri    = '{0}/boards/{1}/members/{2}' -f $baseUrl, $Board.id, $MemberId
				Method = 'PUT'
				Body   = $body
			}
			Invoke-RestMethod @invParams
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
			if ($Card.MemberId) {
				throw 'Existing members found on card. This is not supported yet.'
			} else {
				$uri = "$baseUrl/cards/{0}?MemberId={1}&{2}" -f $Card.Id, $MemberId, $trelloConfig.String	
			}
			
			Invoke-RestMethod -Uri $uri -Method Put
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

function Get-Checklist {
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
				$checkLists | Where-Object {$_.name -eq $Name}
			} else {
				$checkLists	
			}
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Get-ChecklistItem {
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
				$checklist.checkItems | where {$_.Name -eq $Name}
			} else {
				$checklist.checkItems
			}
			
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Disable-ChecklistItem {
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

function Enable-ChecklistItem {
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

function New-TrelloCustomFieldOption {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[Alias('Id')]
		[string]$BoardId,

		[Parameter(Mandatory)]
		[pscustomobject]$Name,

		[Parameter(Mandatory)]
		[string]$Value
	)

	$ErrorActionPreference = 'Stop'

	$RestParams = @{
		Method      = 'POST'
		ContentType = 'application/json'
	}

	if (-not ($cusField = (Get-TrelloCustomField -BoardId $BoardId) | where {$_.name -eq $Name})) {
		Write-Error -Message "Custom field [$($Name)] could not be found on the board."
	} else {
		if ('options' -in $cusField.PSObject.Properties.Name) {
			$uri = '{0}/customField/{1}/options?{2}' -f $baseUrl, $cusField.Id, $trelloConfig.String
			$body = (ConvertTo-Json @{ 
					'value' = @{ 'text' = $Value }
				})
		} else {
			Write-Error -Message 'Custom field does not support options.'
		}

		$RestParams += @{
			Uri 	= $uri
			Body = $body
		}

		$null = Invoke-RestMethod @RestParams
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

			$RestParams = @{
				'uri'    = "$baseUrl/cards?$($trelloConfig.String)"
				'Method' = 'Post'
				'Body'   = $NewCardHash
			}

			$card = Invoke-RestMethod @RestParams

			if ($PSBoundParameters.ContainsKey('CustomFieldName')) {
				Set-TrelloCustomField -Card $card -CustomFieldName $CustomFieldName -CustomFieldValue $CustomFieldValue
			}
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}