function Invoke-PowerTrelloApiCall {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$PathParameters,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[hashtable]$QueryParameters,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$HttpMethod = 'GET'
	)

	$ErrorActionPreference = 'Stop'

	$body = @{
		'key'   = $trelloConfig.APIKey
		'token' = $trelloConfig.AccessToken
	}
	if ($PSBoundParameters.ContainsKey('QueryParameters')) {
		$body += $QueryParameters
	}

	$uri = '{0}/{1}' -f $script:baseUrl, $PathParameters

	(Invoke-RestMethod -Method $HttpMethod -Uri $uri -Body $body)
}