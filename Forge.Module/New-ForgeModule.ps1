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
        Generates a new module.

    .DESCRIPTION
        Generates a new skeleton module based on the arguments passed to the function.

    .EXAMPLE
        New-ForgeModule -Name MyModule

    .PARAMETER Name
        The name of the new module.

    .PARAMETER Path
        The path where the new module is created.

    .PARAMETER Description
        Description of the generated module.   

    .PARAMETER License
        License to add to the generated module.

        Allowed values are:
        - Apache : Apache License
        - MIT : MIT License   

    .PARAMETER Author
        Name to use as module author.

    .PARAMETER Email
        Email to use for the generated module.

    .PARAMETER Git
        Optional, if set add a default .gitignore file to the generated module.

    .PARAMETER Editor
        Optional, editor configuration to setup inside the generated module.

        Allowed values are:
            - VSCode : Visual Studio Code

    .PARAMETER Build
        Optional, if set add build support to the module.

        Allowed values are:
            - PSake : Add PSake build support to the module.
            - TODO: InvokeBuild : Add InvokeBuild support to the module.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact='Low')]
    Param(
        [Parameter(Mandatory = $true)]
        [String]$Name,

        [String]$Path = $Name,

        [String]$Description = "$Name module",

        [ValidateSet('', 'Apache', 'MIT')]
        [String]$License,

        [String]$Author,

        [String]$Email,

        [Switch]$Git,

        [ValidateSet('', 'VSCode')]
        [String]$Editor,

        [ValidateSet('', 'PSake', 'InvokeBuild')]
        [String]$Build,

        [ValidateSet('Src', 'ModuleName')]
        [String]$Layout = 'Src'
    )
    Begin {
        Initialize-ForgeContext -SourceRoot $Script:SourceRoot `
            -DestinationPath $Path
    }
    Process {
        if (!$PSCmdlet.ShouldProcess($Name, "Create module")) {
            return
        }
        $Author = Get-ValueOrGitOrDefault $Author "user.user" "John Doe"
        $Email  = Get-ValueOrGitOrDefault $Email "user.email" "JohnDoe@example.com"
        $CopyrightYear = Get-Date -UFormat %Y
        switch ($Layout) {
            "Src"         { $ModuleDir = "src"}
            "ModuleName"  { $ModuleDir = $Name}
        }

        Set-ForgeBinding @{
            Name          = $Name
            Description   = $Description
            Author        = $Author
            Email         = $Email
            CopyrightYear = $CopyrightYear
        }

        New-ForgeDirectory 
        Copy-ForgeFile -Source "README.md" 

        New-ForgeDirectory -Dest $ModuleDir 
        Copy-ForgeFile -Source "Module.psm1" -Dest "$ModuleDir\$Name.psm1" 

        New-ModuleManifest -Path "$Path\$ModuleDir\$Name.psd1" -RootModule "$Name.psm1" `
            -ModuleVersion "0.1.0" -Description $Description -Author $Author `
            -Copyright "(c) $CopyrightYear $Author. All rights reserved."

        New-ForgeDirectory -Dest "Tests" 
        Copy-ForgeFile -Source "Manifest.Tests.ps1" -Dest "Tests" 

        New-ForgeDirectory -Dest "docs/en-US"
        Copy-ForgeFile -Source "docs/en-US/about_Module_help.txt" -Dest "docs/en-US/about_$($Name)_help.txt"

        if ($License) {
            Copy-ForgeFile -Source "LICENSE.$License" -Dest "LICENSE" 
        }
        if ($Git) {
            Copy-ForgeFile -Source "DotGitIgnore" -Dest ".gitignore"             
        }
        switch ($Build) {
            "PSake" {
                Copy-ForgeFile -Source "Build.PSake\build.ps1" -Dest "build.ps1"
                Copy-ForgeFile -Source "Build.PSake\build.psake.ps1" -Dest "build.psake.ps1"
                Copy-ForgeFile -Source "Build.PSake\build.settings.ps1" -Dest "build.settings.ps1"
                Copy-ForgeFile -Source "ScriptAnalyzerSettings.psd1"
            }
            "InvokeBuild" {
                Copy-ForgeFile -Source "Build.InvokeBuild\build.ps1" -Dest "build.ps1"
                Copy-ForgeFile -Source "Build.InvokeBuild\.build.ps1" -Dest ".build.ps1"
                Copy-ForgeFile -Source "Build.InvokeBuild\build.settings.ps1" -Dest "build.settings.ps1"
                Copy-ForgeFile -Source "ScriptAnalyzerSettings.psd1"
            }
        }
        switch ($Editor) {
            "VSCode" {
                New-ForgeDirectory -Dest .vscode
                Copy-ForgeFile -Source "VSCode.settings.json" -Dest ".vscode\settings.json"
                Copy-ForgeFile -Source "VSCode.tasks.json" -Dest ".vscode\tasks.json"
                Copy-ForgeFile -Source "ScriptAnalyzerSettings.psd1"
            }
        }
    }
}