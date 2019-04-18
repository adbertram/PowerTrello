function New-TrelloCardChecklist {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[pscustomobject]$Card,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string[]]$Item
	)

	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$commonBody = @{
				key   = $trelloConfig.APIKey
				token = $trelloConfig.AccessToken
			}
			$chParams = @{
				Uri    = "$script:baseUrl/checklists"
				Method = 'POST'
				Body   = $commonBody + @{ idCard = $Card.id; name = $Name }
			}
			$checkList = Invoke-RestMethod @chParams
			foreach ($i in $Item) {
				$null = $checkList | New-TrelloCardChecklistItem -Name $i
			}
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}