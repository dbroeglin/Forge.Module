Set-PSDebug -Strict
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
Import-Module "Forge"
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
            "$TestPath\README.md" | Should Contain "# TestModule PowerShell module"
        }

        It "should create a module directory" {
            "$TestPath\$Name" | Should Exist
        }

        It "should create a module file" {
            "$TestPath\$Name\$Name.psm1" | Should Exist
            "$TestPath\$Name\$Name.psm1" | Should Contain "Set-StrictMode"
        }

        It "should create a manifest file" {
            "$TestPath\$Name\$Name.psd1" | Should Exist
            "$TestPath\$Name\$Name.psd1" | Should Contain "Jane Doe"
        }

        It "should create a test directory" {
            "$TestPath\Tests" | Should Exist
        }

        It "should create manifest tests" {
            "$TestPath\Tests\Manifest.Tests.ps1" | Should Exist
            "$TestPath\Tests\Manifest.Tests.ps1" | Should Contain "Describe '$Name Manifest"
        }
    }

    Context "-License Apache" {
        New-ForgeModule @Params -License Apache

        It "should create an Apache LICENSE file" {
            "$TestPath\LICENSE" | Should Exist
            "$TestPath\LICENSE" | Should Contain "Apache License"            
            "$TestPath\LICENSE" | Should Contain "$(Get-Date -UF %Y) Jane Doe"
        }
    }

    Context "-License MIT" {
        New-ForgeModule @Params -License MIT

        It "should create a MIT LICENSE file" {
            "$TestPath\LICENSE" | Should Exist
            "$TestPath\LICENSE" | Should Contain "MIT License"
            "$TestPath\LICENSE" | Should Contain "$(Get-Date -UF %Y) Jane Doe"
        }
    }
}