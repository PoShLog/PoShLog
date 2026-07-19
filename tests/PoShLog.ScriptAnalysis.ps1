# PoShLog is now a compiled C# binary module; there are no loose .ps1 function files left to
# analyze with PSScriptAnalyzer. Kept as a no-op for backwards compatibility with any tooling
# that still invokes this script directly.
$functionsPath = "$PSScriptRoot\..\src\functions"
if (Test-Path $functionsPath) {
	Get-ChildItem -Path $functionsPath -Recurse -File -Filter '*.ps1' | ForEach-Object {
		Invoke-ScriptAnalyzer -Path $_.FullName -Settings "./PSScriptAnalyzerSettings.psd1"
	}
}