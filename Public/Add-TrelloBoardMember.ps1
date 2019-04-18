function Add-TrelloBoardMember {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[object]$Board,

		[Parameter(Mandatory, ParameterSetName = 'ByMemberId')]
		[ValidateNotNullOrEmpty()]
		[string]$MemberId,

		[Parameter(Mandatory, ParameterSetName = 'ByEmail')]
		[ValidateNotNullOrEmpty()]
		[string]$Email,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('admin', 'normal', 'observer')]
		[string]$Type = 'normal'
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$invParams = @{
				Method = 'PUT'
			}
			if ($PSBoundParameters.ContainsKey('MemberId')) {
				$uri = '{0}/boards/{1}/members/{2}?type={3}' -f $script:baseUrl, $Board.id, $MemberId, $Type
			} elseif ($PSBoundParameters.ContainsKey('Email')) {
				$uri = '{0}/boards/{1}/members?email={2}' -f $script:baseUrl, $Board.id, $Email
				$invParams.Headers = @{ type = $Type }
			}
			$uri += '&key={0}&token={1}' -f $trelloConfig.APIKey, $trelloConfig.AccessToken
			$invParams.Uri = $uri
			$null = Invoke-RestMethod @invParams
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}