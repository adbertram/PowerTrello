function New-TrelloBoard {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$TeamName,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('org', 'private', 'public')]
		[string]$Visibility = 'private'
	)

	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$body = @{
				key                   = $trelloConfig.APIKey
				token                 = $trelloConfig.AccessToken
				name                  = $Name
				defaultLists          = 'false'
				defaultLabels         = 'false'
				prefs_permissionLevel = $Visibility
			}
			if ($PSBoundParameters.ContainsKey('TeamName')) {
				$body.idOrganization = (Get-TrelloTeam -Name $TeamName).id
			}
			$invParams = @{
				Uri    = "$script:baseUrl/boards"
				Method = 'POST'
				Body   = $body
			}
			Invoke-RestMethod @invParams
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}