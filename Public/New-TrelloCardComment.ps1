function New-TrelloCardComment {
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
			$uri = "$script:baseUrl/cards/{0}/actions/comments?{1}" -f $Card.Id, $trelloConfig.String
			Invoke-RestMethod -Uri $uri -Method Post -Body @{ text =$Comment }
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}