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
				$uri = "$script:baseUrl/boards/{0}/actions?filter={1}:{2}&filter=all&fields=all&limit=1000&{3}" -f $Board.Id, $ActionFilter, $ActionFilterValue, $trelloConfig.String
			} elseif ($PSBoundParameters.ContainsKey('Since')) {
				$utcTime = $Since.ToUniversalTime().ToString('o')
				$uri = "$script:baseUrl/boards/{0}/actions?since={1}&filter=all&fields=all&limit=1000&{2}" -f $Board.Id, $utcTime, $trelloConfig.String
			} else {
				$uri = "$script:baseUrl/boards/{0}/actions?filter=all&fields=all&limit=1000&{1}" -f $Board.Id, $trelloConfig.String
			}
			Invoke-RestMethod -Uri $uri
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}