function Get-TrelloBoardLabel {
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
			$uri = "$script:baseUrl/boards/{0}/labels/?{1}&labels=all&limit=1000" -f $Board.Id, $trelloConfig.String
			Invoke-RestMethod -Uri $uri
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}