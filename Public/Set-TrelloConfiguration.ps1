function Set-TrelloConfiguration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ApiKey,
	
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$AccessToken,
	
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$RegistryKeyPath = "HKCU:\Software\$script:ProjectName"
    )

    function encrypt([string]$TextToEncrypt) {
        $secure = ConvertTo-SecureString $TextToEncrypt -AsPlainText -Force
        $encrypted = $secure | ConvertFrom-SecureString
        return $encrypted
    }

    $ak = encrypt $ApiKey
    $at = encrypt $AccessToken

    switch ($PSEdition) {
        'Desktop' {
            if (-not (Test-Path -Path $RegistryKeyPath)) {
                New-Item -Path ($RegistryKeyPath | Split-Path -Parent) -Name ($RegistryKeyPath | Split-Path -Leaf) | Out-Null
            }
            $values = 'APIKey', 'AccessToken'
            foreach ($val in $values) {
                if ((Get-Item $RegistryKeyPath).GetValue($val)) {
                    Write-Verbose "'$RegistryKeyPath\$val' already exists. Skipping."
                }
            }
            Write-Verbose "Creating $RegistryKeyPath\$val"
            New-ItemProperty $RegistryKeyPath -Name 'APIKey' -Value $ak -Force | Out-Null
            New-ItemProperty $RegistryKeyPath -Name 'AccessToken' -Value $at -Force | Out-Null
            break
        }
        'Core' {
            $config = [pscustomobject]@{
                APIKey      = $ak
                AccessToken = $at
            }

            $config | ConvertTo-Json | Set-Content -Path $script:ConfigurationFilePath
            break
        }
        default {
            throw "Unrecognized PSEdition: [$_]"
        }
    }
    $script:trelloConfig = [pscustomobject]@{
        'APIKey'      = $ApiKey
        'AccessToken' = $AccessToken
        'String'      = "key=$ApiKey&token=$AccessToken"
    }
}