Set-PSDebug -Strict
$ErrorActionPreference = "Stop"
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'

Import-Module "Forge"
. "$PSScriptRoot\..\Forge.Module\_Context.ps1"
. "$PSScriptRoot\..\Forge.Module\New-ForgeModule.ps1"
. "$PSScriptRoot\..\Forge.Module\$sut"

Describe "New-ForgeModuleFunction" {
    $ModuleName = "TestModule"
    $FunctionName = "TestFunction"
    $TestBase   = Setup -Dir $ModuleName -Passthru

    Context "-Name $FunctionName -Parameter a,b,c" {
        $FunctionName = "TestFunction1"

        it "should generate a function file with parameters" {
            $FunctionPath = Join-Path $ModulePath "$FunctionName.ps1"
            $FunctionTestPath = Join-Path Tests "$FunctionName.Tests.ps1"

            New-ForgeModuleFunction -Name $FunctionName -Parameter a1,b1,c1 -NoExport
            $FunctionPath     | Should Exist
            $FunctionPath     | Should Contain "a1,"
            $FunctionPath     | Should Contain "b1,"
            $FunctionPath     | Should Contain "c1"
            $FunctionTestPath | Should Exist
            (Join-Path $ModulePath "$ModuleName.psd1") | Should Not Contain $FunctionName
        }
    }

    Context "-Name $FunctionName" {
        It "should generate a function file" {
            (Join-Path $ModulePath "$FunctionName.ps1") | Should Exist
            (Join-Path Tests "$FunctionName.Tests.ps1") | Should Exist
        }

        It "should add the function to the exported ones" {

            $PsdPath = Join-Path $ModulePath "$ModuleName.psd1"
            (Import-PowerShellDataFile $PsdPath)["FunctionsToExport"] | Should Be @($FunctionName)
        }

        BeforeEach {
            New-ForgeModuleFunction -Name $FunctionName
        }
    }

    Context "Incorrect directory structure: no module dir" {
        It "should fail if '<ModuleName>' directory does not exist" {
            Remove-Item -Recurse $ModulePath
            { 
                New-ForgeModuleFunction -Name $FunctionName
            } | Should Throw "Module directory 'TestModule' does not exist"
        }
    }

    Context "Incorrect directory structure: no Tests dir" {
        It "should fail if 'Tests' directory does not exist" {
            Remove-Item $TestsPath
            { 
                New-ForgeModuleFunction -Name $FunctionName
            } | Should Throw "Test directory 'Tests' does not exist"
        }
    }

    BeforeEach {
        $Script:OldLocation = Get-Location
        Set-Location $TestBase

        $ModulePath = New-Item (Join-Path $TestBase $ModuleName) -Type Container
        $TestsPath  = New-Item (Join-path $TestBase Tests) -Type Container
        New-ModuleManifest "$ModuleName/$ModuleName.psd1"
    }

    AfterEach {
        Set-Location $Script:OldLocation
        Remove-Item -Recurse $TestBase/*
   }
}