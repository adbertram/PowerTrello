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
		$httpParams.GetEnumerator() | Sort-Object Name | ForEach-Object {
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
			$getParams.GetEnumerator() | ForEach-Object {
				$keyValues += "$($_.Key)=$($_.Value)"
			}
			
			$paramString = $keyValues -join '&'
			
			switch ($PSCmdlet.ParameterSetName) {
				'ByName' {
					$uri = "$baseUrl/members/me/boards"
					$boards = Invoke-RestMethod -Uri ('{0}?{1}' -f $uri, $paramString)
					$boards | Where-Object { $_.name -eq $Name }
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

function Get-TrelloCard {
	[CmdletBinding(DefaultParameterSetName = 'None')]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[object]$Board,
		
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
		[string]$Due
		
		
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$cards = Invoke-RestMethod -Uri "$baseUrl/boards/$($Board.Id)/cards?$($trelloConfig.String)"
			if ($PSBoundParameters.ContainsKey('Label')) {
<<<<<<< HEAD
				$cards | where { if (($_.labels) -and $_.labels.Name -contains $Label) { $true } }
			} elseif ($PSBoundParameters.ContainsKey('Due')) {
				$cards
			} elseif ($PSBoundParameters.ContainsKey('Name')) {
				$cards | where {$_.Name -eq $Name}
			} elseif ($PSBoundParameters.ContainsKey('Id')) {
				$cards | where {$_.idShort -eq $Id}
			} else {
=======
				$cards | Where-Object { if (($_.labels) -and $_.labels.Name -contains $Label) { $true } }
			}
			elseif ($PSBoundParameters.ContainsKey('Due'))
			{
				$cards
			}
			elseif ($PSBoundParameters.ContainsKey('Name'))
			{
				$cards | Where-Object {$_.Name -eq $Name}
			}
			elseif ($PSBoundParameters.ContainsKey('Id'))
			{
				$cards | Where-Object {$_.idShort -eq $Id}
			}
			else
			{
>>>>>>> 74b67e451e4e37867039a65aa6d4d283ec8585f9
				$cards
			}
		} catch {
			Write-Error $_.Exception.Message
		}
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

function Set-TrelloList {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[Alias('Id')]
		[string]$CardId,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ListId
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$uri = "$baseUrl/cards/{0}?idList={1}&{2}" -f $CardId, $ListId, $trelloConfig.String
			Invoke-RestMethod -Uri $uri -Method Put
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
			if ($Card.idMembers) {
				throw 'Existing members found on card. This is not supported yet.'
			} else {
				$uri = "$baseUrl/cards/{0}?idMembers={1}&{2}" -f $Card.Id, $MemberId, $trelloConfig.String	
			}
			
			Invoke-RestMethod -Uri $uri -Method Put
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Get-TrelloMember {
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
<<<<<<< HEAD
				$checkLists | where {$_.name -eq $Name}
			} else {
=======
				$checkLists | Where-Object {$_.name -eq $Name}
			}
			else
			{
>>>>>>> 74b67e451e4e37867039a65aa6d4d283ec8585f9
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
<<<<<<< HEAD
				$checklist.checkItems | where {$_.Name -eq $Name}
			} else {
=======
				$checklist.checkItems | Where-Object {$_.Name -eq $Name}
			}
			else
			{
>>>>>>> 74b67e451e4e37867039a65aa6d4d283ec8585f9
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
<<<<<<< HEAD
				$attachments | where {$_.name -eq $Name}
			} else {
=======
				$attachments | Where-Object {$_.name -eq $Name}
			}
			else
			{
>>>>>>> 74b67e451e4e37867039a65aa6d4d283ec8585f9
				$attachments	
			}
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function New-TrelloList {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[Alias('Id')]
		[string]$BoardId,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,

		[Parameter()]
		[string]$idListSource,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$position = 'top'
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
<<<<<<< HEAD
	process {
		try {
			$NewListHash = @{
				'name'    =$Name
				'idBoard' = $BoardId
				'pos'     = $position
			}
			if(-not [string]::IsNullOrEmpty($idListSource)) {
				$NewListHash['idListSource'] = $idListSource
			}

			$RestParams = @{
				'uri'    = "$baseUrl/lists?$($trelloConfig.String)"
				'Method' = 'Post'
				'Body'   = $NewListHash
			}

=======
	process
	{
		try
		{
            $NewListHash = @{
                'name'=$Name
                'idBoard' = $BoardId
                'pos' = $position
            }
            if(-not [string]::IsNullOrEmpty($idListSource))
            {
                $NewListHash['idListSource'] = $idListSource
            }

            $RestParams = @{
                'uri' = "$baseUrl/lists?$($trelloConfig.String)"
                'Method' = 'Post'
                'Body' = $NewListHash
            }
			
>>>>>>> 74b67e451e4e37867039a65aa6d4d283ec8585f9
			Invoke-RestMethod @RestParams
		} catch {
			Write-Error $_.Exception.Message
		}
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
		[string]$idMembers,

		[Parameter()]
		[string]$idLabels,

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
<<<<<<< HEAD
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

			if(-not [string]::IsNullOrEmpty($idMembers)) {
				$NewCardHash['idMembers'] = $idMembers
			}

			if(-not [string]::IsNullOrEmpty($idLabels)) {
				$NewCardHash['idLabels'] = $idLabels
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

=======
	process
	{
		try
		{
            $NewCardHash = @{
                'idList'=$ListId
            }
            if(-not [string]::IsNullOrEmpty($Name))
            {
                $NewCardHash['name'] = $Name
            }

            if(-not [string]::IsNullOrEmpty($Description))
            {
                $NewCardHash['desc'] = $Description
            }

            if(-not [string]::IsNullOrEmpty($Position))
            {
                $NewCardHash['pos'] = $Position
            }

            if(-not [string]::IsNullOrEmpty($idMembers))
            {
                $NewCardHash['idMembers'] = $idMembers
            }

            if(-not [string]::IsNullOrEmpty($idLabels))
            {
                $NewCardHash['idLabels'] = $idLabels
            }

            if(-not [string]::IsNullOrEmpty($urlSource))
            {
                $NewCardHash['urlSource'] = $urlSource
            }

            if(-not [string]::IsNullOrEmpty($fileSource))
            {
                $NewCardHash['fileSource'] = $fileSource
            }

            if(-not [string]::IsNullOrEmpty($idCardSource))
            {
                $NewCardHash['idCardSource'] = $idCardSource
            }

            if(-not [string]::IsNullOrEmpty($keepFromSource))
            {
                $NewCardHash['keepFromSource'] = $keepFromSource
            }

            $RestParams = @{
                'uri' = "$baseUrl/cards?$($trelloConfig.String)"
                'Method' = 'Post'
                'Body' = $NewCardHash
            }
			
>>>>>>> 74b67e451e4e37867039a65aa6d4d283ec8585f9
			Invoke-RestMethod @RestParams
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Add-TrelloChecklist {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)]
		[object]$Card,
		[string]$Name
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
<<<<<<< HEAD
		try {
			if(!($Name)) {
				$Name = "Checklist"
			}
			$uri = "$baseUrl/checklists?idCard={0}&name={1}&{2}" -f $Card.Id, $Name, $trelloConfig.String
=======
		try
		{
            if(!($Name))
            {
                $Name = "Checklist"
            }
			$uri = "$baseUrl/checklists?idCard={0}&name={1}&{2}" -f $Card.Id,$Name,$trelloConfig.String
>>>>>>> 74b67e451e4e37867039a65aa6d4d283ec8585f9
			Invoke-RestMethod -Uri $uri -Method Post
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function Add-TrelloChecklistItem {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)]
		[string]$checklistId,
		[Parameter(Mandatory)]
		[string]$Name
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
<<<<<<< HEAD
		try {
			if(!($Name)) {
				$Name = "Checklist"
			}
			$uri = "$baseUrl/checklists/{0}/checkItems?name={1}&{2}" -f $checklistId, $Name, $trelloConfig.String
=======
		try
		{
            if(!($Name))
            {
                $Name = "Checklist"
            }
			$uri = "$baseUrl/checklists/{0}/checkItems?name={1}&{2}" -f $checklistId,$Name,$trelloConfig.String
>>>>>>> 74b67e451e4e37867039a65aa6d4d283ec8585f9
			Invoke-RestMethod -Uri $uri -Method Post
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}

function New-TrelloBoard
{
    [CmdletBinding()]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Name
	)

    begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
            $params = @{
				'key' = $trelloConfig.APIKey
				'token' = $trelloConfig.AccessToken
                'name' = $Name
			}
			Invoke-RestMethod -Uri "$baseUrl/boards" -Method Post -Body $params
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}

function Close-TrelloBoardList
{
    [CmdletBinding()]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$ListId
	)

    begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
            $params = @{
				'key' = $trelloConfig.APIKey
				'token' = $trelloConfig.AccessToken
                'closed' = 'true'
            }
            $json = $params | ConvertTo-Json
			$null = Invoke-RestMethod -Uri "$baseUrl/lists/$ListId" -Method Put -Body $json -ContentType 'application/json'
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}

}

function Rename-TrelloBoardList
{
    [CmdletBinding()]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$ListId,
        [Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$NewName
	)

    begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
            $params = @{
				'key' = $trelloConfig.APIKey
				'token' = $trelloConfig.AccessToken
                'name' = $NewName
            }
            $json = $params | ConvertTo-Json
			$null = Invoke-RestMethod -Uri "$baseUrl/lists/$ListId" -Method Put -Body $json -ContentType 'application/json'
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}


function Rename-TrelloBoardCard
{
    [CmdletBinding()]
  param
    (
      [Parameter(Mandatory, ValueFromPipeline)]
      [ValidateNotNullOrEmpty()]
      [object]$Board,
      [ValidateNotNullOrEmpty()]
      [string]$NewName,
      [ValidateNotNullOrEmpty()]
      [string]$Id
	)


    begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
            $uri = "$baseUrl/cards/{0}?name={1}&idBoard={2}&{3}" -f $Id, $NewName, $($Board.Id), $trelloConfig.String
            Invoke-RestMethod -Uri $uri -Method Put
		}
		catch
		{
			Write-Error $_.Exception.Message
		}
	}
}
