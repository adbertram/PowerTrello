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
			foreach ($list in (Invoke-RestMethod -Uri "$script:baseUrl/boards/$BoardId/lists?$($trelloConfig.String)")) {
				$list
			}
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}