function Enable-BoardPowerUp {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[pscustomobject]$Board,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('Custom Fields')]
		[string]$Name
	)

	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			switch ($Name) {
				'Custom Fields' {
					$pluginId = '56d5e249a98895a9797bebb9'
				}
				default {
					throw "Unrecognized input: [$_]"
				}
			}
			$body = @{
				key      = $trelloConfig.APIKey
				token    = $trelloConfig.AccessToken
				idPlugin = $pluginId
			}
			$invParams = @{
				Uri    = "$script:baseUrl/boards/$($Board.id)/boardPlugins"
				Method = 'POST'
				Body   = $body
			}
			$null = Invoke-RestMethod @invParams
		} catch {
			Write-Error $_.Exception.Message
		}
	}
}