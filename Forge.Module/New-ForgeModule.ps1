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
function New-ForgeModule {
    <#
    .SYNOPSIS
        Creates a new module.

    .DESCRIPTION
        Creates a new skeleton module based on the arguments passed to the function.

    .EXAMPLE
        New-ForgeModule -Name MyModule

    .PARAMETER Name
        The name of the new module.

    .PARAMETER Path
        The path where the new module is created.

    .PARAMETER Description
        The description of new module.   
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact='Low')]
    Param(
        [Parameter(Mandatory = $true)]
        [String]$Name,

        [String]$Path = $Name,

        [String]$Description = "$Name module",

        [ValidateSet('Apache', 'MIT')]
        [String]$License,

        [String]$Author,

        [String]$Email,

        [String]$GitCommand = "git"
    )
    Begin {
        $Context = @{
            SourceRoot      = $Script:SourceRoot
            DestinationPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
        }        
    }
    Process {
        if (!$PSCmdlet.ShouldProcess($Name, "Create module")) {
            return
        }
        $Author = Get-ValueOrGitOrDefault $Author "user.user" "John Doe"
        $Email  = Get-ValueOrGitOrDefault $Email "user.email" "JohnDoe@example.com"

        $CopyrightYear = Get-Date -UFormat %Y
        $Context.Binding = @{
            Name          = $Name
            Description   = $Description
            Author        = $Author
            Email         = $Email
            CopyrightYear = $CopyrightYear
        }

        New-ForgeDirectory @Context
        Copy-ForgeFile -Source "README.md" @Context

        New-ForgeDirectory -Dest $Name @Context
        Copy-ForgeFile -Source "Module.psm1" -Dest "$Name\$Name.psm1" @Context

        New-ModuleManifest -Path "$Path\$Name\$Name.psd1" -RootModule "$Name.psm1" `
            -ModuleVersion "0.1.0" -Description $Description -Author $Author `
            -Copyright "(c) $CopyrightYear $Author. All rights reserved."

        New-ForgeDirectory -Dest "Tests" @Context
        Copy-ForgeFile -Source "Manifest.Tests.ps1" -Dest "Tests" @Context

        if ($License) {
            Copy-ForgeFile -Source "LICENSE.$License" -Dest "LICENSE" @Context
        }
    }
}