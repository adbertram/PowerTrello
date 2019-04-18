function Get-TrelloCardChecklistItem {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[pscustomobject]$Checklist,
	
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Name
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			if ($PSBoundParameters.ContainsKey('Name')) {
				$items = $checklist.checkItems | where { $_.Name -eq $Name }
			} else {
				$items = $checklist.checkItems
			}
			foreach ($item in $items) {
				$item | Add-Member -NotePropertyName 'CheckListId' -NotePropertyValue $CheckList.id
				$item | Add-Member -NotePropertyName 'CardId' -NotePropertyValue $CheckList.CardId -PassThru
			}
			
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}