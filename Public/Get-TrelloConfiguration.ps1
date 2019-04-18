function Get-TrelloConfiguration {
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$RegistryKeyPath = "HKCU:\Software\$script:ProjectName",

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$ApiKey,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$AccessToken
	)
	
	$ErrorActionPreference = 'Stop'

	function decrypt([string]$TextToDecrypt) {
		$secure = ConvertTo-SecureString $TextToDecrypt
		$hook = New-Object system.Management.Automation.PSCredential("test", $secure)
		$plain = $hook.GetNetworkCredential().Password
		return $plain
	}

	try {
		if ($PSBoundParameters.ContainsKey('ApiKey') -and $PSBoundParameters.ContainsKey('AccessToken')) {
			$ak = $ApiKey
			$at = $AccessToken
		} elseif (-not (Test-Path -Path $RegistryKeyPath)) {
			throw "No $script:ProjectName configuration found in registry"
		} else {
			$keyValues = Get-ItemProperty -Path $RegistryKeyPath
			$ak = decrypt $keyValues.APIKey
			$at = decrypt $keyValues.AccessToken
		}
		$global:trelloConfig = [pscustomobject]@{
			'APIKey'      = $ak
			'AccessToken' = $at
			'String'      = "key=$ak&token=$at"	
		}
		$trelloConfig
	} catch {
		Write-Error $_.Exception.Message
	}
}