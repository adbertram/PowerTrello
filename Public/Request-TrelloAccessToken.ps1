function Request-TrelloAccessToken {
	[CmdletBinding()]
	[OutputType('System.String')]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ApiKey,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Scope = 'read,write',

		[Parameter()]
		[ValidateSet('never', '1hour', '1day', '30days')]
		[string]$ExpirationTime = 'never',
	
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$ApplicationName = $script:ProjectName,
	
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[int]$AuthTimeout = 30
		
	)
	
	$ErrorActionPreference = 'Stop'
	try {
		$httpParams = @{
			'key'           = $apiKey
			'expiration'    = $ExpirationTime
			'scope'         = $Scope
			'response_type' = 'token'
			'name'          = $ApplicationName
			'return_url'    = 'https://trello.com'
		}
		
		$keyValues = @()
		$httpParams.GetEnumerator() | sort Name | foreach {
			$keyValues += "$($_.Key)=$($_.Value)"
		}
		
		$keyValueString = $keyValues -join '&'
		$authUri = "$script:baseUrl/authorize?$keyValueString"
		
		$IE = New-Object -ComObject InternetExplorer.Application
		$null = $IE.Navigate($authUri)
		$null = $IE.Visible = $true
		
		$timer = [System.Diagnostics.Stopwatch]::StartNew()
		while (($IE.LocationUrl -notmatch '^https://trello.com/token=') -and ($timer.Elapsed.TotalSeconds -lt $AuthTimeout)) {
			Start-Sleep -Seconds 1
		}
		$timer.Stop()
		
		if ($timer.Elapsed.TotalSeconds -ge $AuthTimeout) {
			throw 'Timeout waiting for user authorization.'
		}
		
		[regex]::Match($IE.LocationURL, 'token=(.+)').Groups[1].Value
		
	} catch {
		Write-Error $_.Exception.Message
	} finally {
		$null = $IE.Quit()	
	}
}