function New-TrelloCustomFieldOption {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[pscustomobject]$CustomField,

		[Parameter(Mandatory)]
		[string[]]$Value
	)

	$ErrorActionPreference = 'Stop'

	$RestParams = @{
		Method      = 'POST'
		ContentType = 'application/json'
	}

	if ('options' -in $CustomField.PSObject.Properties.Name) {
		$restParams.Uri = '{0}/customField/{1}/options?{2}' -f $script:baseUrl, $CustomField.Id, $trelloConfig.String
		foreach ($val in $Value) {
			$restParams.Body = (ConvertTo-Json @{ 'value' = @{ 'text' = $val } })

			$null = Invoke-RestMethod @RestParams
		}
	} else {
		throw 'Custom field does not support options.'
	}
}