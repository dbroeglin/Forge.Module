<#
Copyright 2016 Dominique Broeglin

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
#>
function New-ForgeModuleFunction {
    <#
    .SYNOPSIS
        Creates a new function in a module.

    .DESCRIPTION
        Creates a new skeleton module function based on the arguments passed to the function.

    .EXAMPLE
        New-ForgeModuleFunction -Name MyFunction

    .PARAMETER Name
        The name of the new function.

    .PARAMETER Export
        If $True the function will be added to the list of exported functions in the PSD1 file.

        Default: $True        
    #>
    [CmdletBinding(ConfirmImpact='Low')]
    Param(
        [Parameter(Mandatory = $true)]
        [String]$Name,

        [String]$Path = "./",

        [String]$ModuleName,

        [String[]]$Parameter = @(),

        [switch]$NoExport
    )
    Begin {
        $DestinationPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
        $Context = @{
            SourceRoot      = $Script:SourceRoot
            # TODO: handle $Path
            DestinationPath = $DestinationPath
        }  
        if (-not $ModuleName) {
            $ModuleName = Split-Path -Leaf (Get-Location)
        }
    }
    Process {  
        $PsdPath = Join-Path $DestinationPath (Join-Path $ModuleName "$ModuleName.psd1")
        if (-not (Test-Path -PathType Container $ModuleName)) {
            throw "Module directory '$ModuleName' does not exist"
        }
        if (-not (Test-Path -PathType Container 'Tests')) {
            throw "Test directory 'Tests' does not exist"
        }
        if (!$NoExport -and -not (Test-Path -PathType Leaf $PsdPath)) {
            throw "PSD file '$PsdPath' does not exist"
        }

        $Context.Binding = @{
            Name       = $Name
            ModuleName = $ModuleName
            Parameters = $Parameter
        }

        $FunctionFilename = "$Name.ps1"
        $TestsFilename    = "$Name.Tests.ps1"
        Copy-ForgeFile -Source "Function.ps1" -Dest (Join-Path $ModuleName $FunctionFilename) @Context
        Copy-ForgeFile -Source "Function.Tests.ps1" -Dest (Join-Path Tests $TestsFilename) @Context
        if (!$NoExport) {
            Update-ModuleManifest -Path $PsdPath -FunctionsToExport (
                (Import-PowerShellDataFile $PsdPath)["FunctionsToExport"] + $Name
            )
        }
    }
}