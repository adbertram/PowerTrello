function ConvertToFriendlyCustomField {
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

    $obj = @{ }

    ## Find the board custom field
    if (-not ($boardField = $BoardCustomFields | Where { $_.id -eq $CustomFieldItem.idCustomField })) {
        throw "No board custom fields with ID $($CustomFieldItem.idCustomField) found on board ID $BoardId."
    }

    ## Find the card custom field value
    if ('value' -in $CustomFieldItem.PSObject.Properties.Name) {
        if ('checked' -in $CustomFieldItem.value.PSObject.Properties.Name) {
            if ($CustomFieldItem.value.checked -eq 'true') {
                $obj[$boardField.Name] = $true
            } else {
                $obj[$boardField.Name] = $false
            }
        } elseif ('date' -in $CustomFieldItem.value.PSObject.Properties.Name) {
            $obj[$boardField.Name] = $CustomFieldItem.value.date
        } elseif ('number' -in $CustomFieldItem.value.PSObject.Properties.Name) {
            $obj[$boardField.Name] = $CustomFieldItem.value.number
        } else {
            $obj[$boardField.Name] = $CustomFieldItem.value.text
        }
    } elseif ($CustomFieldItemValue = $boardField.options | where { $_.id -eq $CustomFieldItem.idValue }) {
        $obj[$boardField.Name] = $CustomFieldItemValue.value.text
    }
    [pscustomobject]$obj
}