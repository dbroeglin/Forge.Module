#Requires -Modules InvokeBuild
Import-Module InvokeBuild

# Builds the module by invoking Invoke-Build on the .build.ps1 script.
Invoke-Build -File $PSScriptRoot\.build.ps1 -Task Build
