function Set-TrelloCustomField {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[object]$Card,

		[Parameter(Mandatory)]
		[pscustomobject]$CustomFieldName,

		[Parameter(Mandatory)]
		[string]$CustomFieldValue
	)

	$ErrorActionPreference = 'Stop'

	$RestParams = @{
		Method      = 'PUT'
		ContentType = 'application/json'
	}

	if (-not ($cusField = (Get-TrelloCustomField -BoardId $Card.idBoard) | where { $_.name -eq $CustomFieldName })) {
		Write-Error -Message "Custom field [$($CustomFieldName)] could not be found on the board."
	} else {
		if ('options' -in $cusField.PSObject.Properties.Name) {
			$cusFieldId = ($cusField.options | where { $_.Value.text -eq $CustomFieldValue }).id
			$uri = '{0}/card/{1}/customField/{2}/item?{3}' -f $script:baseUrl, $Card.Id, $cusField.Id, $trelloConfig.String
			$body = (ConvertTo-Json @{ 
					'idValue' = $cusFieldid
				})
		} else {
			$uri = '{0}/card/{1}/customField/{2}/item?{3}' -f $script:baseUrl, $Card.Id, $cusField.id, $trelloConfig.String
			$body = (ConvertTo-Json @{ 'value' = @{ $cusField.type = $CustomFieldValue } })
		}

		$RestParams = @{
			Uri         = $uri
			Method      = 'PUT'
			ContentType = 'application/json'
			Body        = $body
		}

		$null = Invoke-RestMethod @RestParams
	}
	
}