function Get-TrelloCard {
    [CmdletBinding(DefaultParameterSetName = 'Id')]
    param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [object]$Board,

        [Parameter(ParameterSetName = 'List')]
        [ValidateNotNullOrEmpty()]
        [object]$List,
		
        [Parameter(ParameterSetName = 'Name')]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(ParameterSetName = 'Id')]
        [ValidateNotNullOrEmpty()]
        [string]$Id,
		
        [Parameter(ParameterSetName = 'Label')]
        [ValidateNotNullOrEmpty()]
        [string]$Label,
	
        [Parameter(ParameterSetName = 'Due')]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Today', 'Tomorrow', 'In7Days', 'In14Days')]
        [string]$Due,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [switch]$IncludeArchived,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [switch]$IncludeAllActivity
    )
    begin {
        $ErrorActionPreference = 'Stop'
    }
    process {
        try {
            $filter = 'open'
            if ($IncludeArchived.IsPresent) {
                $filter = 'all'
            }
            $cards = Invoke-RestMethod -Uri "$script:baseUrl/boards/$($Board.Id)/cards?customFieldItems=true&filter=$filter&$($trelloConfig.String)"
            if ($PSBoundParameters.ContainsKey('Label')) {
                $cards = $cards | where { if (($_.labels) -and $_.labels.Name -contains $Label) { $true } }
            } elseif ($PSBoundParameters.ContainsKey('Due')) {
                Write-Warning -Message 'Due functionality is not complete.'
            } elseif ($PSBoundParameters.ContainsKey('Name')) {
                $cards = $cards | where { $_.Name -eq $Name }
            } elseif ($PSBoundParameters.ContainsKey('Id')) {
                $cards = $cards | where { $_.idShort -eq $Id }
            } elseif ($PSBoundParameters.ContainsKey('List')) {
                $cards = $cards | where { $_.idList -eq $List.id }
            }

            $boardCustomFields = Get-TrelloCustomField -BoardId $Board.id
            foreach ($card in $cards) {
                if ($IncludeAllActivity.IsPresent) {
                    $card | Add-Member -NotePropertyName 'Activity' -NotePropertyValue (Get-TrelloCardAction -Card $_)
                }
                if ('customFieldItems' -in $card.PSObject.Properties.Name) {
                    $cFields = @()
                    $card.customFieldItems | foreach {
                        $cFields += ConvertToFriendlyCustomField -BoardId $Board.Id -CustomFieldItem $_ -BoardCustomFields $boardCustomFields
                    }
                    $card | Add-Member -NotePropertyName 'CustomFields' -NotePropertyValue $cFields -PassThru
                }
            }
        } catch {
            Write-Error $_.Exception.Message
        }
    }
}