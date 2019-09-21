function Get-TrelloConfiguration {
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$RegistryKeyPath = "HKCU:\Software\$script:ProjectName"
    )
	
    $ErrorActionPreference = 'Stop'

    function decrypt([string]$TextToDecrypt) {
        $secure = ConvertTo-SecureString $TextToDecrypt
        $hook = New-Object system.Management.Automation.PSCredential("test", $secure)
        $plain = $hook.GetNetworkCredential().Password
        return $plain
    }

    try {
        switch ($PSEdition) {
            'Desktop' {
                if (-not (Test-Path -Path $RegistryKeyPath)) {
                    throw "No $script:ProjectName configuration found in registry"
                } else {
                    $keyValues = Get-ItemProperty -Path $RegistryKeyPath
                    $ak = decrypt $keyValues.APIKey
                    $at = decrypt $keyValues.AccessToken
                }
                break
            }
            'Core' {
                $config = Get-Content -Path $script:ConfigurationFilePath -Raw | ConvertFrom-Json
                $ak = decrypt $config.APIKey
                $at = decrypt $config.AccessToken
                break
            }
            default {
                throw "Unrecognized PSEdition: [$_]"
            }
        }
		
        [pscustomobject]@{
            'APIKey'      = $ak
            'AccessToken' = $at
            'String'      = "key=$ak&token=$at"
        }

        ## "cache" the config. This is to prevent having to issue a file system call
        $script:trelloConfig = [pscustomobject]@{
            'APIKey'      = $ak
            'AccessToken' = $at
            'String'      = "key=$ak&token=$at"
        }
    } catch {
        Write-Error $_.Exception.Message
    }
}