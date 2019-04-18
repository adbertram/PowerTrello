function New-TrelloCardChecklistItem {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[pscustomobject]$Checklist,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string[]]$Name
	)

	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$body = @{
				key   = $trelloConfig.APIKey
				token = $trelloConfig.AccessToken
			}
			$invParams = @{
				Uri    = "$script:baseUrl/checklists/{0}/checkItems" -f $Checklist.id
				Method = 'POST'
			}
			foreach ($i in $Name) {
				$invParams.Body = ($body + @{ 'name' = $i })
				Invoke-RestMethod @invParams
			}
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}