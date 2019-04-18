function Add-TrelloTeamMember {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[object]$TeamMember,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('admin', 'normal')]
		[string]$Type = 'normal'
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$invParams = @{
				HttpMethod = 'PUT'
			}
			$invParams.PathParameters = 'organizations/{0}/members/{1}' -f $TeamMember.teamId, $TeamMember.id
			$invParams.QueryParameters = @{
				type = $Type
			}
			Invoke-PowerTrelloApiCall @invParams
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}