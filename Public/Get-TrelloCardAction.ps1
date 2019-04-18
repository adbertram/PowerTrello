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
				$uri = "$script:baseUrl/cards/{0}/actions?filter={1}:{2}&filter=all&limit=1000&{3}" -f $Card.Id, $ActionFilter, $ActionFilterValue, $trelloConfig.String
			} else {
				$uri = "$script:baseUrl/cards/{0}/actions?filter=all&limit=1000&{1}" -f $Card.Id, $trelloConfig.String
			}
			Invoke-RestMethod -Uri $uri
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}