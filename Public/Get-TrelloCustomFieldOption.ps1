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
				$pathParams = "customField/$($CustomField.Id)/options"

				## Add the custom field ID in the output to support piping to Remove-TrelloCustomFieldId
				$properties = @(
					'*',
					@{ 'Name' = 'customFieldId'; Expression = { $CustomField.id } }
				)
				Invoke-PowerTrelloApiCall -PathParameters $pathParams | Select-Object -Property $properties
			}
		} catch {
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}