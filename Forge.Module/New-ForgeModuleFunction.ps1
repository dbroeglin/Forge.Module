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

    .PARAMETER Path
        The path where the function should be generated.

    .PARAMETER ModuleName
        The name of the module in which the function is generated if it is not the
        same as the parent directory name.

    .PARAMETER Parameter
        An array of parameter names to generate for the new function.

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
        Initialize-ForgeContext -SourceRoot $Script:SourceRoot `
            -DestinationPath $Path

        if (-not $ModuleName) {
            $ModuleName = Split-Path -Leaf (Get-Location)
        }
    }
    Process {  
        if (Test-Path -PathType Container src) {
            $SourceDir = "src"
        } elseif (Test-Path -PathType Container $ModuleName) {
            $SourceDir = $ModuleName
        } else {
            throw "Could'nt find either 'src' or '$ModuleName' directory"
        }
        if (-not (Test-Path -PathType Container 'Tests')) {
            throw "Test directory 'Tests' does not exist"
        }

        $PsdPath = Join-Path (Get-ForgeContext).DestinationPath (Join-Path $SourceDir "$ModuleName.psd1")

        if (!$NoExport -and -not (Test-Path -PathType Leaf $PsdPath)) {
            throw "PSD file '$PsdPath' does not exist"
        }

        Set-ForgeBinding @{
            Name       = $Name
            ModuleName = $ModuleName
            Parameters = $Parameter
        }

        $FunctionFilename = "$Name.ps1"
        $TestsFilename    = "$Name.Tests.ps1"
        Copy-ForgeFile -Source "Function.ps1" -Dest (Join-Path $SourceDir $FunctionFilename)
        Copy-ForgeFile -Source "Function.Tests.ps1" -Dest (Join-Path Tests $TestsFilename)
        if (!$NoExport) {
            Update-ModuleManifest -Path $PsdPath -FunctionsToExport (
                (Import-PowerShellDataFile $PsdPath)["FunctionsToExport"] + $Name
            )
        }
    }
}