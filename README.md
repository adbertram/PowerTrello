# PowerTrello

[![Build status](https://ci.appveyor.com/api/projects/status/sfix5awr3a737yr3?svg=true)](https://ci.appveyor.com/project/adbertram/powertrello)

PowerTrello is a PowerShell module for interacting with the Trello web service.

## How to Use

1. Sign up for an API key and secret for your Trello subscription [here](https://trello.com/app-key).

2. Open up your PowerShell console as administrator.

3. Download the PowerTrello module from the PowerShell Gallery.

   `Install-Module PowerTrello`

4. Retrieve and save a token from Trello.
    1. Run `Request-TrelloAccessToken -ApiKey MYAPIKEY`
    2. Follow the on-screen instructions.
    
5. Make the Trello configuration available in your current PowerShell session.

  `Get-TrelloConfiguration`

7. Run any of the functions in the module to interact with your Trello boards. For example, just to ensure you can communicate with Trello, run the `Get-TrelloBoard` function. This function should return all of your Trello boards.
