function New-TrelloLabel {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[object]$Board,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('yellow', 'purple', 'blue', 'red', 'green', 'orange', 'black', 'sky', 'pink', 'lime', 'null')]
		[string]$Color = 'null'
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$body = @{
				key   = $trelloConfig.APIKey
				token = $trelloConfig.AccessToken
				name 	= $Name
				color = $Color
			}
			$invParams = @{
				Uri    = "{0}/boards/{1}/labels" -f $script:baseUrl, $Board.id
				Method = 'POST'
				Body   = $body
			}
			Invoke-RestMethod @invParams
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}