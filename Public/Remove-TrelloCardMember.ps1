function Remove-TrelloCardMember {
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
			$uri = "$script:baseUrl/cards/{0}/idMembers/{1}?{2}" -f $Card.Id, $MemberId, $trelloConfig.String
			Invoke-RestMethod -Uri $uri -Method Delete
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}