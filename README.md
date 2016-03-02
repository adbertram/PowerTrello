# PowerTrello
PowerTrello is a PowerShell module for interacting with the Trello web service.

## How to Use

1. Sign up for an API key and secret for your Trello subscription [here](https://trello.com/app-key).

2. Open up your PowerShell console as administrator.

3. Download the PowerTrello module from Github from within PowerShell into your modules folder.

        $uri = 'https://raw.githubusercontent.com/adbertram/PowerTrello/master/Trello.psm1'
        $sysModulePath = 'C:\Program Files\WindowsPowerShell\Modules'
        if ($sysModulePath -in $env:PSModulePath.Split(';')) {
          $fileName = $uri | Split-Path -Leaf
          $null = mkdir "$sysModulePath\$($fileName.Trim('.psm1'))"
          $filePath = "C:\Program Files\WindowsPowerShell\Modules\$($fileName.Trim('.psm1'))\$($uri | Split-Path -Leaf)"
          Invoke-WebRequest -Uri $uri -OutFile $filePath
        } else {
          throw 'Unable to download PowerTrello into system module path. Please put it there manually.'
        }

NOTE: If you use PSGET, you can install this way:
        $uri = 'https://raw.githubusercontent.com/adbertram/PowerTrello/master/Trello.psm1'
        Import-module psget
        Install-module -ModuleUrl $uri 

4. Retrieve a token from Trello and save to a variable.

  `$token = Request-TrelloAccessToken –ApiKey MYAPIKEY`

5. Save the token and API key to the registry so you don't have to specify it every time.

  `Set-TrelloConfiguration –ApiKey MYAPIKEY –AccessToken $token`

6. Make the Trello configuration available in your current PowerShell session.

  `Get-TrelloConfiguration`

7. Run any of the functions in the module to interact with your Trello boards. For example, just to ensure you can communicate with Trello, run the `Get-TrelloBoard` function. This function should return all of your Trello boards.
