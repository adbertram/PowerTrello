function Get-TrelloBoard {
	[CmdletBinding(DefaultParameterSetName = 'None')]
	param
	(
		[Parameter(ParameterSetName = 'ByName')]
		[ValidateNotNullOrEmpty()]
		[string[]]$Name,
		
		[Parameter(ParameterSetName = 'ById')]
		[ValidateNotNullOrEmpty()]
		[string[]]$Id,
	
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$IncludeClosedBoards
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$invApiParams = @{
				QueryParameter = @{ }
			}
			if (-not $IncludeClosedBoards.IsPresent) {
				$invApiParams.QueryParameter.filter = 'open'
			}
			
			switch ($PSCmdlet.ParameterSetName) {
				'ByName' {
					$invApiParams.PathParameters = 'members/me/boards'
					foreach ($bName in $Name) {
						$boards = Invoke-PowerTrelloApiCall @invApiParams
						$boards | where { $_.name -eq $bName }
					}
				}
				'ById' {
					foreach ($bId in $Id) {
						$invApiParams.PathParameters = "boards/$bId"
						Invoke-PowerTrelloApiCall @invApiParams
					}
				}
				default {
					$invApiParams.PathParameters = 'members/me/boards'
					Invoke-PowerTrelloApiCall @invApiParams
				}
			}
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}