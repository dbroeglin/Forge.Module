Set-PSDebug -Strict
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
if (!(Get-Module Forge)) {
    Import-Module "Forge"
}
. "$PSScriptRoot\..\Forge.Module\_context.ps1"
. "$PSScriptRoot\..\Forge.Module\$sut"

Describe "New-ForgeModule" {
    $Name = "TestModule"
    $TestPath = Join-Path $TestDrive $Name 
    $Params = @{ 
        Name   = $Name
        Path   = $TestPath
        Author = "Jane Doe"
    }

    Context "-Name $Name -Path... "{
        $TestPath = "TestDrive:\$Name" 
        New-ForgeModule @Params 

        It "should create a project directory" {
            $TestPath | Should Exist
        }

        It "should create a README.md" {
            "$TestPath\README.md" | Should Exist
            "$TestPath\README.md" | Should -FileContentMatch "# TestModule PowerShell module"
        }

        It "should create a module directory" {
            "$TestPath\src" | Should Exist
        }

        It "should create a module file" {
            "$TestPath\src\$Name.psm1" | Should Exist
            "$TestPath\src\$Name.psm1" | Should -FileContentMatch "Set-StrictMode"
        }

        It "should create a manifest file" {
            "$TestPath\src\$Name.psd1" | Should Exist
            "$TestPath\src\$Name.psd1" | Should -FileContentMatch "Jane Doe"
        }

        It "should create a test directory" {
            "$TestPath\Tests" | Should Exist
        }

        It "should create manifest tests" {
            "$TestPath\Tests\Manifest.Tests.ps1" | Should Exist
            "$TestPath\Tests\Manifest.Tests.ps1" | Should -FileContentMatch "Describe '$Name Manifest"
        }

        It "should create an about file" {
            "$TestPath\src\en-US\about_$($Name).help.txt" | Should Exist
            "$TestPath\src\en-US\about_$($Name).help.txt" | Should -FileContentMatch "    $Name"
        }
    }

    Context "-Name $Name -Layout ModuleName -Path... "{
        $TestPath = "TestDrive:\$Name" 
        New-ForgeModule @Params -Layout ModuleName

        It "should create a project directory" {
            $TestPath | Should Exist
        }

        It "should create a module directory" {
            "$TestPath\$Name" | Should Exist
        }

        It "should create a module file" {
            "$TestPath\$Name\$Name.psm1" | Should Exist
            "$TestPath\$Name\$Name.psm1" | Should -FileContentMatch "Set-StrictMode"
        }

        It "should create a manifest file" {
            "$TestPath\$Name\$Name.psd1" | Should Exist
            "$TestPath\$Name\$Name.psd1" | Should -FileContentMatch "Jane Doe"
        }        
    }

    Context "-License Apache" {
        New-ForgeModule @Params -License Apache

        It "should create an Apache LICENSE.txt file" {
            "$TestPath\LICENSE.txt" | Should Exist
            "$TestPath\LICENSE.txt" | Should -FileContentMatch "Apache License"            
            "$TestPath\LICENSE.txt" | Should -FileContentMatch "$(Get-Date -UF %Y) Jane Doe"
            "$TestPath\src\$Name.psd1" | Should -FileContentMatch "LicenseUri = 'http://www.apache.org/licenses/LICENSE-2.0'"
        }
    }

    Context "-License MIT" {
        New-ForgeModule @Params -License MIT

        It "should create a MIT LICENSE file" {
            "$TestPath\LICENSE.txt" | Should Exist
            "$TestPath\LICENSE.txt" | Should -FileContentMatch "MIT License"
            "$TestPath\LICENSE.txt" | Should -FileContentMatch "$(Get-Date -UF %Y) Jane Doe"
            "$TestPath\src\$Name.psd1" | Should -FileContentMatch "LicenseUri = 'https://opensource.org/licenses/MIT'"
        }
    }

    Context "-Git" {
        New-ForgeModule @Params -Git

        It "should create a .gitignore file" {
            "$TestPath\.gitignore" | Should Exist
            "$TestPath\.gitignore" | Should -FileContentMatch "https://github.com/github/gitignore "
        }
    }

    Context "-Editor VSCode" {
        New-ForgeModule @Params -Editor VSCode

        It "should create a .vscode directory" {
            "$TestPath\.vscode" | Should Exist
        }

        It "should create a .vscode\settings.json file" {
            "$TestPath\.vscode\settings.json" | Should Exist
        }
        
        It "should create a .vscode\tasks.json file" {
            "$TestPath\.vscode\tasks.json" | Should Exist
        }

        It "should create a ScriptAnalyzerSettings.psd1 file" {
            "$TestPath\ScriptAnalyzerSettings.psd1" | Should Exist
        }
    }            

    Context "-Build PSake" {
        New-ForgeModule @Params -Build PSake

        It "should create a build.ps1 file" {
            "$TestPath\build.ps1" | Should Exist
        }
        
        It "should create a build.psake.ps1 file" {
            "$TestPath\build.psake.ps1" | Should Exist
        }

        It "should create a build.settings.ps1 file" {
            "$TestPath\build.settings.ps1" | Should Exist
            "$TestPath\build.settings.ps1" | Should -FileContentMatch '\$ModuleName = "TestModule"'
            "$TestPath\build.settings.ps1" | Should -FileContentMatch '\$SrcRootDir *= *"\$PSScriptRoot\\\$ModuleName"'
        }

        It "should create a ScriptAnalyzerSettings.psd1 file" {
            "$TestPath\ScriptAnalyzerSettings.psd1" | Should Exist
        }
    }

    Context "-Build InvokeBuild" {
        New-ForgeModule @Params -Build InvokeBuild

        It "should create a build.ps1 file" {
            "$TestPath\build.ps1" | Should Exist
        }
        
        It "should create a .build.ps1 file" {
            "$TestPath\.build.ps1" | Should Exist
        }

        It "should create a build.settings.ps1 file" {
            "$TestPath\build.settings.ps1" | Should Exist
            "$TestPath\build.settings.ps1" | Should -FileContentMatch '\$ModuleName = "TestModule"'
            "$TestPath\build.settings.ps1" | Should -FileContentMatch '\$SrcRootDir *= *"\$PSScriptRoot/\$ModuleName"'
        }

        It "should create a ScriptAnalyzerSettings.psd1 file" {
            "$TestPath\ScriptAnalyzerSettings.psd1" | Should Exist
        }
    }             
}