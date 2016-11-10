# Taken with love from https://raw.githubusercontent.com/RamblingCookieMonster/PSDiskPart/master/Tests/appveyor.pester.ps1

# This script will invoke pester tests
# We serialize XML results and pull them in appveyor.yml

# If Finalize is specified, we collect XML output, upload tests, and indicate build errors
param([switch]$Finalize, [String]$PSVersion = $PSVersionTable.PSVersion.Major)

#Initialize some variables, move to the project root
$TestFile = "TestResultsPS$PSVersion.xml"
$ProjectRoot = $ENV:APPVEYOR_BUILD_FOLDER
Set-Location $ProjectRoot

#Run a test with the current version of PowerShell
if(-not $Finalize) {
    "`n`tSTATUS: Testing with PowerShell $PSVersion`n"

    Import-Module Pester

    Invoke-Pester -Path "$ProjectRoot\Tests" -OutputFormat NUnitXml -OutputFile "$($env:temp)\$TestFile" -PassThru |
        Export-Clixml -Path "$($env:temp)\PesterResults$PSVersion.xml"
} else {
    # If finalize is specified, check for failures and 

    #Show status...
    $AllFiles = Get-ChildItem -Path "$($env:temp)\*Results*.xml" | Select -ExpandProperty FullName
    "`n`tSTATUS: Finalizing results`n"
    "COLLATING FILES:`n$($AllFiles | Out-String)"

    #Upload results for test page
    Get-ChildItem -Path "$($env:temp)\TestResultsPS*.xml" | Foreach-Object {
        
        $Address = "https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)"
        $Source = $_.FullName

        "UPLOADING FILES: $Address $Source"

        (New-Object 'System.Net.WebClient').UploadFile( $Address, $Source )
    }

    #What failed?
    $Results = @( Get-ChildItem -Path "$($env:temp)\PesterResults*.xml" | Import-Clixml )
            
    $FailedCount = $Results |
        Select -ExpandProperty FailedCount |
        Measure-Object -Sum |
        Select -ExpandProperty Sum
    
    if ($FailedCount -gt 0) {
        $FailedItems = $Results | Select -ExpandProperty TestResult | Where {$_.Passed -notlike $True}

        "FAILED TESTS SUMMARY:`n"
        $FailedItems | ForEach-Object {
            $Test = $_
            [pscustomobject]@{
                Describe = $Test.Describe
                Context = $Test.Context
                Name = "It $($Test.Name)"
                Result = $Test.Result
            }
        } |
            Sort Describe, Context, Name, Result |
            Format-List

        throw "$FailedCount tests failed."
    }
}