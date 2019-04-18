function Get-TrelloCustomFieldOption {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[pscustomobject]$CustomField
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			if ('options' -notin $CustomField.PSObject.Properties.Name) {
				throw 'Custom field does not support options.'
			} else {
				$uri = '{0}/customField/{1}/options?{2}' -f $script:baseUrl, $CustomField.Id, $trelloConfig.String
				Invoke-RestMethod -Uri $uri
			}
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}