# initial configuration

# Set Sleet Nuget Feed Source ConnectionString
if (Test-Path $Env:ProgramFiles/Sleet/tools)
{
    # Sleet create json config
    Start-Process Sleet.exe -WorkingDirectory $Env:ProgramFiles/Sleet/tools -ArgumentList 'createconfig', '--azure' -Wait -NoNewWindow
    
    $sleetJson = Get-Content $Env:ProgramFiles/Sleet/tools/sleet.json -ErrorAction SilentlyContinue | ConvertFrom-Json
    if ($sleetJson)
    {
        $sleetSource = $sleetJson.sources[0]
        $sleetSource.name = "feed"
        $sleetSource.container = "feed"
        $sleetSource.connectionString = $env:FEED_CONN_STR
        $sleetJson | ConvertTo-Json | Set-Content $Env:ProgramFiles/Sleet/tools/sleet.json
    }
}
