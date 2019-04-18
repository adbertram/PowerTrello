function Remove-TrelloCardChecklistItem {
	[CmdletBinding()]
	param
	(
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
				'Uri'    = '{0}/cards/{1}/checkItem/{2}?{3}' -f $script:baseUrl, $CheckListItem.CardId, $ChecklistItem.Id, $trelloConfig.String
				'Method' = 'DELETE'
			}
			$null = Invoke-RestMethod @params
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}