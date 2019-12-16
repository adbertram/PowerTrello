function Get-TrelloCustomField {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('Id')]
        [string]$BoardId
    )
    begin {
        $ErrorActionPreference = 'Stop'
    }
    process {
        try {
            foreach ($field in (Invoke-RestMethod -Uri ("$script:baseUrl/boards/{0}/customFields?{1}" -f $BoardId, $trelloConfig.String))) {
                $field
            }
        } catch {
            Write-Error $_.Exception.Message
        }
    }
}