function ConvertToCustomFieldValue {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$BoardId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [pscustomobject]$CustomFieldItem,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [pscustomobject[]]$BoardCustomFields = (Get-TrelloCustomField -BoardId $BoardId)
    )

    $ErrorActionPreference = 'Stop'

    if ('value' -in $CustomFieldItem.PSObject.Properties.Name) {
        if ('checked' -in $CustomFieldItem.value.PSObject.Properties.Name) {
            if ($CustomFieldItem.value.checked -eq 'true') {
                $true
            } else {
                $false
            }
        } elseif ('date' -in $CustomFieldItem.value.PSObject.Properties.Name) {
            $CustomFieldItem.value.date
        } else {
            $CustomFieldItem.value.text
        }
    } else {
        $boardField = $BoardCustomFields | Where { $_.id -eq $CustomFieldItem.idCustomField }
        if (-not $boardField) {
            throw "No board custom fields with ID $($CustomFieldItem.idCustomField) found on board ID $BoardId."
        }
        if ($CustomFieldItemValue = $boardField.options | where { $_.id -eq $CustomFieldItem.idValue }) {
            $CustomFieldItemValue.value.text
        }
    }
}