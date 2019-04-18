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
				Uri    = "$script:baseUrl/boards/$BoardId/lists"
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