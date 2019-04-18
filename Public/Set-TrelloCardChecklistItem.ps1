function Set-TrelloCardChecklistItem {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[pscustomobject]$ChecklistItem,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Name
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$chParams = @{
				Uri    = '{0}/cards/{1}/checkItem/{2}?name={3}&{4}' -f $script:baseUrl, $ChecklistItem.CardId, $ChecklistItem.id, $Name, $trelloConfig.String
				Method = 'PUT'
			}
			$null = Invoke-RestMethod @chParams
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}