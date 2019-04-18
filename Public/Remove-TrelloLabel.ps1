function Remove-TrelloLabel {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[pscustomobject]$Label
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$invParams = @{
				Uri    = '{0}/labels/{1}?{2}' -f $script:baseUrl, $Label.id, $trelloConfig.String
				Method = 'DELETE'
			}
			$null = Invoke-RestMethod @invParams
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}