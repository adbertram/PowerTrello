function Remove-TrelloCustomFieldOption {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[pscustomobject]$CustomFieldOption
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$pathParams = "customField/$($CustomField.Id)/options/$($CustomFieldOption._id)"
			Invoke-PowerTrelloApiCall -PathParameters $pathParams -HttpMethod 'DELETE'
		} catch {
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}