function Get-TrelloTeam {
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Name
	)
	
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$body = @{
				key   = $trelloConfig.APIKey
				token = $trelloConfig.AccessToken
			}
			$invParams = @{
				Uri  = '{0}/members/me/organizations?{1}' -f $script:baseUrl, $trelloConfig.String
				Body = $body
			}
			$teams = Invoke-RestMethod @invParams
			$whereFilter = { '*' }
			if ($PSBoundParameters.ContainsKey('Name')) {
				$whereFilter = { $_.displayName -eq $Name }
			}
			$teams.where($whereFilter)
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}