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
				Uri    = "$script:baseUrl/boards/$($Board.id)"
				Method = 'DELETE'
			}
			Invoke-RestMethod @invParams
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}