function Get-TrelloCardChecklist {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[object]$Card,
	
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Name
		
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$checkLists = Invoke-RestMethod -Uri ("$script:baseUrl/cards/{0}/checklists?{1}" -f $Card.Id, $trelloConfig.String)
			if ($PSBoundParameters.ContainsKey('Name')) {
				$checkLists = $checkLists | Where-Object { $_.name -eq $Name }
			}
			foreach ($cl in $checklists) {
				$cl | Add-Member -NotePropertyName 'CardId' -NotePropertyValue $Card.id -PassThru
			}
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}