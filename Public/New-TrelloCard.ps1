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
		[date]$StartDate,

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

   			if ($PSBoundParameters.ContainsKey('StartDate')) {
				$NewCardHash['start'] = $StartDate.ToShortDateString()
			}

			$RestParams = @{
				'uri'    = "$script:baseUrl/cards?$($trelloConfig.String)"
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
