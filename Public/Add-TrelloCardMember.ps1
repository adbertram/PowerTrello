function Add-TrelloCardMember {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[object]$Card,
	
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$MemberId
		
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$body = @{
				value = $MemberId
			}
			$uri = "$script:baseUrl/cards/{0}/idMembers?{1}" -f $Card.Id, $trelloConfig.String
			
			$null = Invoke-RestMethod -Uri $uri -Method POST -Body $body
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}