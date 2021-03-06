Set-PSDebug -Strict
$ErrorActionPreference = "Stop"
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
if (!(Get-Module Forge)) {
    Import-Module "Forge"
}
. "$PSScriptRoot\..\Forge.Module\_Context.ps1"
. "$PSScriptRoot\..\Forge.Module\New-ForgeModule.ps1"
. "$PSScriptRoot\..\Forge.Module\$sut"

function Invoke-Contexts {
    Context "-Name $FunctionName -Parameter a,b,c" {
        $FunctionName = "TestFunction1"

        it "should generate a function file with parameters" {
            $FunctionPath = Join-Path $ModulePath "$FunctionName.ps1"
            $FunctionTestPath = Join-Path Tests "$FunctionName.Tests.ps1"

            New-ForgeModuleFunction -Name $FunctionName -Parameter a1,b1,c1 -NoExport
            $FunctionPath     | Should Exist
            $FunctionPath     | Should -FileContentMatch '\$a1,'
            $FunctionPath     | Should -FileContentMatch '\$b1,'
            $FunctionPath     | Should -FileContentMatch '\$c1'
            $FunctionTestPath | Should Exist
            (Join-Path $ModulePath "$ModuleName.psd1") | Should -Not -FileContentMatch $FunctionName
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
            } | Should Throw "Could'nt find either 'src' or 'TestModule' directory"
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
}

Describe "New-ForgeModuleFunction ('ModuleName' layout)" {
    $ModuleName = "TestModule"
    $FunctionName = "TestFunction"
    $TestBase   = Setup -Dir $ModuleName -Passthru

    Invoke-Contexts

    BeforeEach {
        $Script:OldLocation = Get-Location
        Set-Location $TestBase

        $ModulePath = New-Item (Join-Path $TestBase $ModuleName) -Type Container
        $TestsPath  = New-Item (Join-path $TestBase Tests) -Type Container
        # RootModule is important because it will generate "FunctionsToExport = '*'"
        # instead of FunctionsToExport = @()
        New-ModuleManifest "$ModuleName/$ModuleName.psd1" -RootModule "$ModuleName.psm1"
    }

    AfterEach {
        Set-Location $Script:OldLocation
        Remove-Item -Recurse $TestBase/*
   }
}

Describe "New-ForgeModuleFunction (src layout)" {
    $ModuleName = "TestModule"
    $FunctionName = "TestFunction"
    $TestBase   = Setup -Dir $ModuleName -Passthru

    Invoke-Contexts

    BeforeEach {
        $Script:OldLocation = Get-Location
        Set-Location $TestBase

        $ModulePath = New-Item (Join-Path $TestBase src) -Type Container
        $TestsPath  = New-Item (Join-path $TestBase Tests) -Type Container
        New-ModuleManifest "src/$ModuleName.psd1"
    }

    AfterEach {
        Set-Location $Script:OldLocation
        Remove-Item -Recurse $TestBase/*
   }
}

