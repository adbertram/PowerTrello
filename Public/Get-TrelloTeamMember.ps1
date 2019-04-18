function Get-TrelloTeamMember {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[object]$Team,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Name
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$invParams = @{
				Method = 'GET'
			}
			$pathParams = 'organizations/{0}/members' -f $Team.id
			if ($members = Invoke-PowerTrelloApiCall -PathParameters $pathParams) {
				$members | Add-Member -NotePropertyName 'teamId' -NotePropertyValue $Team.id
			}
			if ($PSBoundParameters.ContainsKey('Name')) {
				@($members).where({ $_.fullName -eq $Name })
			} else {
				$members
			}
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}