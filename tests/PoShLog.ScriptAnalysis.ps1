Get-ChildItem -Path "$PSScriptRoot\..\src\functions" -Recurse -File -Filter '*.ps1' | ForEach-Object {
	Invoke-ScriptAnalyzer -Path $_.FullName -Settings "./PSScriptAnalyzerSettings.psd1"
}