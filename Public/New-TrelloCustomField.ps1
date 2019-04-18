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
				Uri    = "$script:baseUrl/customFields"
				Method = 'POST'
				Body   = $body
			}
			Invoke-RestMethod @invParams
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}