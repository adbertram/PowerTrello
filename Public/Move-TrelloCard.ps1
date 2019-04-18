function Move-TrelloCard {
	[CmdletBinding(SupportsShouldProcess)]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[object]$Card,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$ToBoardName,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$NewListName
	)

	$ErrorActionPreference = 'Stop'

	if ($PSBoundParameters.ContainsKey('ToBoardName')) {
		$boardId = Get-TrelloBoard -Name $ToBoardName
	} else {
		$boardId = $card.idBoard
	}
	if (-not ($list = (Get-TrelloList -BoardId $boardId).where({ $_.name -eq $NewListName }))) {
		throw "The list [$($NewListName)] was not found."
	} else {
		$null = $Card | Update-TrelloCard -ListId $list.id
	}
	
}