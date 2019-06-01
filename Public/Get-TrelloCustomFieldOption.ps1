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
				$pathParams = "/customField/$($CustomField.Id)/options"
				Invoke-PowerTrelloApiCall -PathParameters $pathParams
			}
		} catch {
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}