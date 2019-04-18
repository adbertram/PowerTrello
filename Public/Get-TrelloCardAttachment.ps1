function Get-TrelloCardAttachment {
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
			$params = @{
				'Uri' = "$script:baseUrl/cards/{0}/attachments?{1}" -f $Card.Id, $trelloConfig.String
			}
			$attachments = Invoke-RestMethod @params
			if ($PSBoundParameters.ContainsKey('Name')) {
				$attachments | Where-Object { $_.name -eq $Name }
			} else {
				$attachments	
			}
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}