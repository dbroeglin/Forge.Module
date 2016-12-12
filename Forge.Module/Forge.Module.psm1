$ErrorActionPreference = "Stop"
Set-StrictMode -Version 3

Import-Module 'Forge'

# Load functions
$functions = Get-ChildItem -Path $PSScriptRoot -Recurse -Include *.ps1 |
    Where-Object { 
        -not ($_.Fullname -match "[/\\]Templates[/\\]") 
    } | Sort-Object
$functions | ForEach-Object { . $_.FullName }