function Add-TrelloCardAttachment {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[object]$Card,
	
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
		[string]$FilePath
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$fileName = $FilePath | Split-Path -Leaf
			$contents = Get-Content -Path $FilePath -Raw
			$params = @{
				'Uri'    = "$script:baseUrl/cards/{0}/attachments?file={1}&name={2}&{3}" -f $Card.Id, $contents, $fileName, $trelloConfig.String
				'Method' = 'Post'
			}
			$attachment = Invoke-RestMethod @params
			
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}