function Get-TrelloBoardMember {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[Alias('Id')]
		[string]$BoardId
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$invApiParams = @{
				PathParameters = 'boards/{0}/members' -f $BoardId
			}
			
			Invoke-PowerTrelloApiCall @invApiParams
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}