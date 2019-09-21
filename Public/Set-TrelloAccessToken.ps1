function Set-TrelloAccessToken {
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
            'key'           = $ApiKey
            'expiration'    = $ExpirationTime
            'scope'         = $Scope
            'response_type' = 'token'
            'name'          = $ApplicationName
        }
		
        $keyValues = @()
        $httpParams.GetEnumerator() | Sort-Object -Property Name | foreach {
            $keyValues += "$($_.Key)=$($_.Value)"
        }
		
        $keyValueString = $keyValues -join '&'
        $authUri = "$script:baseUrl/authorize?$keyValueString"

        $instructions = @'
You will need to perform some steps manually now.

Auth URI: {0}

1. Copy the above authorization URI to your clipboard and navigate to this URI in a web browser.
2. Log into Trello and allow PowerTrello access your account.
3. Copy the token provided in your web browser.
4. Hit enter when the token is in your clipboard.
'@ -f $authUri

        $instructions

        $token = Read-Host -Prompt 'Paste the token provided by Trello here'
        $setParams = @{
            ApiKey      = $ApiKey
            AccessToken = $token
        }
        Set-TrelloConfiguration @setParams 
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}