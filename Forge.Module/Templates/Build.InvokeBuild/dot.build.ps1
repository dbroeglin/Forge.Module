
##############################################################################
# DO NOT MODIFY THIS FILE!  Modify build.settings.ps1 instead.
##############################################################################

##############################################################################
# This is the PowerShell Module psake build script. It defines the following tasks:
#
# Clean, Build, Sign, BuildHelp, Install, Test and Publish.
#
# The default task is Build.  This task copies the appropriate files from the
# $SrcRootDir to the $OutDir.  Later, other tasks such as Sign and BuildHelp
# will further modify the contents of $OutDir and add new files.
#
# The Sign task will only sign scripts if the $SignScripts variable is set to
# $true.  A code-signing certificate is required for this task to complete.
#
# The BuildHelp task invokes platyPS to generate markdown files from
# comment-based help for your exported commands.  platyPS then generates
# a help file for your module from the markdown files.
#
# The Install task simplies copies the $OutDir to your profile's Modules folder.
#
# The Test task invokes Pester on the $TestRootDir.
#
# The Publish task uses the Publish-Module command to publish
# to either the PowerShell Gallery (the default) or you can change
# the $PublishRepository property to the name of an alternate repository.
# Note: the Publish task requires that the Test task execute without failures.
#
# You can exeute a specific task, such as the Test task by running the
# following command:
#
# PS C:\> invoke-psake build.psake.ps1 -taskList Test
#
# You can execute the Publish task with the following command.
# The first time you execute the Publish task, you will be prompted to enter
# your PowerShell Gallery NuGetApiKey.  After entering the key, it is encrypted
# and stored so you will not have to enter it again.
#
# PS C:\> invoke-psake build.psake.ps1 -taskList Publish
#
# You can verify the stored and encrypted NuGetApiKey by running the following
# command which will display a portion of your NuGetApiKey in plain text.
#
# PS C:\> invoke-psake build.psake.ps1 -taskList ShowApiKey
#
# You can store a new NuGetApiKey with this command. You can leave off
# the -properties parameter and you'll be prompted for the key.
#
# PS C:\> invoke-psake build.psake.ps1 -taskList StoreApiKey -properties @{NuGetApiKey='test123'}
#

###############################################################################
# Dot source the user's customized properties and extension tasks.
###############################################################################

function Enter-Build {
    . $PSScriptRoot\build.settings.ps1

    function Assert-Variable($Name) {
        assert ($null -ne $PSCmdlet.GetVariableValue($Name)) "Missing or null variable '$Name'."
    }

    Assert-Variable DocsRootDir
    Assert-Variable ModuleName
    Assert-Variable OutDir
    Assert-Variable ReleaseDir
    Assert-Variable ScriptAnalysisAction
    Assert-Variable ScriptAnalysisSettingsPath
    Assert-Variable SettingsPath
    Assert-Variable SignScripts
    Assert-Variable SkipScriptAnalysisHost
    Assert-Variable SrcRootDir
    Assert-Variable TestRootDir
}

###############################################################################
# Core task implementations. Avoid modifying these tasks.
###############################################################################

Task . Build

Task Init {
    if (!(Test-Path $OutDir) -and $OutDir.StartsWith($PSScriptRoot, 'OrdinalIgnoreCase')) {
        New-Item $OutDir -ItemType Directory > $null
    }
}

Task Clean {
    if ((Test-Path $ReleaseDir) -and $ReleaseDir.StartsWith($PSScriptRoot, 'OrdinalIgnoreCase')) {
        Get-ChildItem $ReleaseDir | Remove-Item -Recurse -Force -Verbose:$VerbosePreference
    }
}

Task Build BuildImpl, Analyze, Sign

Task BuildImpl Init, Clean, {
    Copy-Item -Path $SrcRootDir -Destination $OutDir -Recurse -Exclude $Exclude -Verbose:$VerbosePreference
}

Task Analyze BuildImpl, {
    if ($Host.Name -in $SkipScriptAnalysisHost) {
        $ScriptAnalysisAction = 'None'
    }

    if (!(Get-Module PSScriptAnalyzer -ListAvailable)) {
        "PSScriptAnalyzer module is not installed.  Skipping Analyze task."
        return
    }

    if ($ScriptAnalysisAction -eq 'None') {
        "Script analysis is not enabled.  Skipping Analyze task."
        return
    }

    $analysisResult = Invoke-ScriptAnalyzer -Path $OutDir -Settings $ScriptAnalysisSettingsPath -Recurse -Verbose:$VerbosePreference
    $analysisResult | Format-Table
    switch ($ScriptAnalysisAction) {
        'Error' {
            Assert -condition (
                ($analysisResult | Where-Object Severity -eq 'Error').Count -eq 0
                ) -message 'One or more Script Analyzer errors were found. Build cannot continue!'
        }
        'Warning' {
            Assert -condition (
                ($analysisResult | Where-Object {
                    $_.Severity -eq 'Warning' -or $_.Severity -eq 'Error'
                }).Count -eq 0) -message 'One or more Script Analyzer warnings were found. Build cannot continue!'
        }
        'ReportOnly' {
            return
        }
        default {
            Assert -condition (
                $analysisResult.Count -eq 0
                ) -message 'One or more Script Analyzer issues were found. Build cannot continue!'
        }
    }
}

Task Sign BuildImpl, {
    if (!$SignScripts) {
        "Script signing is not enabled.  Skipping Sign task."
        return
    }

    $validCodeSigningCerts = Get-ChildItem -Path $CertPath -CodeSigningCert -Recurse | Where-Object NotAfter -ge (Get-Date)
    if (!$validCodeSigningCerts) {
        throw "There are no non-expired code-signing certificates in $CertPath. You can either install " +
              "a code-signing certificate into the certificate store or disable script analysis in build.settings.ps1."
    }

    $certSubjectNameKey = "CertSubjectName"
    $storeCertSubjectName = $true

    # Get the subject name of the code-signing certificate to be used for script signing.
    if (!$CertSubjectName -and ($CertSubjectName = GetSetting -Key $certSubjectNameKey -Path $SettingsPath)) {
        $storeCertSubjectName = $false
    }
    elseif (!$CertSubjectName) {
        "A code-signing certificate has not been specified."
        "The following non-expired, code-signing certificates are available in your certificate store:"
        $validCodeSigningCerts | Format-List Subject,Issuer,Thumbprint,NotBefore,NotAfter

        $CertSubjectName = Read-Host -Prompt 'Enter the subject name (case-sensitive) of the certificate to use for script signing'
    }

    # Find a code-signing certificate that matches the specified subject name.
    $certificate = $validCodeSigningCerts |
                       Where-Object { $_.SubjectName.Name -cmatch [regex]::Escape($CertSubjectName) } |
                       Sort-Object NotAfter -Descending | Select-Object -First 1

    if ($certificate) {
        if ($storeCertSubjectName) {
            SetSetting -Key $certSubjectNameKey -Value $certificate.SubjectName.Name -Path $SettingsPath
            "The new certificate subject name has been stored in ${SettingsPath}."
        }
        else {
            "Using stored certificate subject name $CertSubjectName from ${SettingsPath}."
        }

        "Using code-signing certificate: $certificate"

        $files = @(Get-ChildItem -Path $OutDir\* -Recurse -Include *.ps1,*.psm1)
        foreach ($file in $files) {
            $result = Set-AuthenticodeSignature -FilePath $file.FullName -Certificate $certificate -Verbose:$VerbosePreference
            if ($result.Status -ne 'Valid') {
                throw "Failed to sign script: $($file.FullName)."
            }

            "Successfully signed script: $($file.Name)"
        }
    }
    else {
        $expiredCert = Get-ChildItem -Path $CertPath -CodeSigningCert -Recurse |
                           Where-Object { ($_.SubjectName.Name -cmatch [regex]::Escape($CertSubjectName)) -and
                                          ($_.NotAfter -lt (Get-Date)) }
                           Sort-Object NotAfter -Descending | Select-Object -First 1

        if ($expiredCert) {
            throw "The code-signing certificate `"$($expiredCert.SubjectName.Name)`" EXPIRED on $($expiredCert.NotAfter)."
        }

        throw 'No valid certificate subject name supplied or stored.'
    }
}

Task GenerateMarkdown Build, {
    if ($null -eq $DefaultLocale) {
        $DefaultLocale = 'en-US'
    }

    $moduleInfo = Import-Module $OutDir\$ModuleName.psd1 -Global -Force -PassThru
    if ($moduleInfo.ExportedCommands.Count -eq 0) {
        "No commands have been exported. Skipping GenerateDocs task."
        return
    }

    if (!(Test-Path -LiteralPath $DocsRootDir)) {
        New-Item $DocsRootDir -ItemType Directory > $null
    }

    if (Get-ChildItem -LiteralPath $DocsRootDir -Filter *.md -Recurse) {
        Get-ChildItem -LiteralPath $DocsRootDir -Directory | ForEach-Object {
            Update-MarkdownHelp -Path $_.FullName > $null
        }
    }

    New-MarkdownHelp -Module $ModuleName -Locale $DefaultLocale -OutputFolder $DocsRootDir\$DefaultLocale `
                     -WithModulePage -ErrorAction SilentlyContinue > $null

    Remove-Module $ModuleName
}

Task BuildHelp GenerateMarkdown, {
    if (!(Test-Path -LiteralPath $DocsRootDir) -or !(Get-ChildItem -LiteralPath $DocsRootDir -Filter *.md -Recurse)) {
        "No markdown help files to process. Skipping BuildDocs task."
        return
    }

    foreach ($locale in (Get-ChildItem -Path $DocsRootDir -Directory).Name) {
        New-ExternalHelp -Path $DocsRootDir\$locale -OutputPath $OutDir\$locale -Force -ErrorAction SilentlyContinue | Out-Null
    }
}

Task Install BuildHelp, {
    if ($null -eq $InstallPath) {
        # The default installation path is the current user's module path.
        $moduleInfo = Test-ModuleManifest -Path $SrcRootDir\$ModuleName.psd1
        $InstallPath = Join-Path -Path (Split-Path $profile.CurrentUserAllHosts -Parent) `
                                 -ChildPath "Modules\$ModuleName\$($moduleInfo.Version.ToString())"
    }

    if (!(Test-Path -Path $InstallPath)) {
        Write-Verbose 'Creating local install directory'
        New-Item -Path $InstallPath -ItemType Directory -Verbose:$VerbosePreference > $null
    }

    Copy-Item -Path $OutDir\* -Destination $InstallPath -Verbose:$VerbosePreference -Recurse -Force
    "Module installed into $InstallPath"
}

Task Test Analyze, {
    Import-Module Pester

    try {
        Microsoft.PowerShell.Management\Push-Location -LiteralPath $TestRootDir

        if ($TestOutputFile) {
            $Testing = @{
                OutputFile   = $TestOutputFile
                OutputFormat = $TestOutputFormat
                PassThru     = $true
                Verbose      = $VerbosePreference
            }
        }
        else {
            $Testing = @{
                PassThru     = $true
                Verbose      = $VerbosePreference
            }
        }

        # To control the Pester code coverage, a boolean $CodeCoverageStop is used. ($true, $false and $null).
        # $true enables code coverage. $false disables code coverage. $null enables code coverage but only report on coverage status.
        if ($CodeCoverageStop -or ($null -eq $CodeCoverageStop)) {
            $Testing.CodeCoverage = $CodeCoverageSelection
        }

        $TestResult = Invoke-Pester @Testing

        Assert -condition (
            $TestResult.FailedCount -eq 0
        ) -message "One or more Pester tests failed, build cannot continue."

        if ($CodeCoverageStop -or ($null -eq $CodeCoverageStop)) {
            $TestCoverage = [int]($TestResult.CodeCoverage.NumberOfCommandsExecuted /
                $TestResult.CodeCoverage.NumberOfCommandsAnalyzed * 100)

            if ($CodeCoverageStop) {
                Assert -condition (
                    $TestCoverage -gt $CodeCoveragePercentage
                ) -message "Pester code coverage test failed. ($TestCoverage% Achieved, $CodeCoveragePercentage% Required.)"
            }
        }
    }
    finally {
        Microsoft.PowerShell.Management\Pop-Location
        Remove-Module $ModuleName -ErrorAction SilentlyContinue
    }
}

Task Publish Test, {
    $publishParams = @{
        Path        = $OutDir
        NuGetApiKey = $NuGetApiKey
    }

    # Publishing to the PSGallery requires an API key, so get it.
    if ($NuGetApiKey) {
        "Using script embedded NuGetApiKey"
    }
    elseif ($NuGetApiKey = GetSetting -Path $SettingsPath -Key NuGetApiKey) {
        "Using stored NuGetApiKey"
    }
    else {
        $promptForKeyCredParams = @{
            DestinationPath = $SettingsPath
            Message         = 'Enter your NuGet API key in the password field'
            Key             = 'NuGetApiKey'
        }

        $cred = PromptUserForCredentialAndStorePassword @promptForKeyCredParams
        $NuGetApiKey = $cred.GetNetworkCredential().Password
        "The NuGetApiKey has been stored in $SettingsPath"
    }

    $publishParams = @{
        Path        = $OutDir
        NuGetApiKey = $NuGetApiKey
    }

    # If an alternate repository is specified, set the appropriate parameter.
    if ($PublishRepository) {
        $publishParams['Repository'] = $PublishRepository
    }

    # Consider not using -ReleaseNotes parameter when Update-ModuleManifest has been fixed.
    if ($ReleaseNotesPath) {
        $publishParams['ReleaseNotes'] = @(Get-Content $ReleaseNotesPath)
    }

    "Calling Publish-Module..."
    Publish-Module @publishParams
}

###############################################################################
# Secondary/utility tasks - typically used to manage stored build settings.
###############################################################################

Task RemoveApiKey {
    if (GetSetting -Path $SettingsPath -Key NuGetApiKey) {
        RemoveSetting -Path $SettingsPath -Key NuGetApiKey
    }
}

Task StoreApiKey {
    $promptForKeyCredParams = @{
        DestinationPath = $SettingsPath
        Message         = 'Enter your NuGet API key in the password field'
        Key             = 'NuGetApiKey'
    }

    PromptUserForCredentialAndStorePassword @promptForKeyCredParams
    "The NuGetApiKey has been stored in $SettingsPath"
}

Task ShowApiKey {
    $OFS = ""
    if ($NuGetApiKey) {
        "The embedded (partial) NuGetApiKey is: $($NuGetApiKey[0..7])"
    }
    elseif ($NuGetApiKey = GetSetting -Path $SettingsPath -Key NuGetApiKey) {
        "The stored (partial) NuGetApiKey is: $($NuGetApiKey[0..7])"
    }
    else {
        "The NuGetApiKey has not been provided or stored."
        return
    }

    "To see the full key, use the task 'ShowFullApiKey'"
}

Task ShowFullApiKey {
    if ($NuGetApiKey) {
        "The embedded NuGetApiKey is: $NuGetApiKey"
    }
    elseif ($NuGetApiKey = GetSetting -Path $SettingsPath -Key NuGetApiKey) {
        "The stored NuGetApiKey is: $NuGetApiKey"
    }
    else {
        "The NuGetApiKey has not been provided or stored."
    }
}

Task RemoveCertSubjectName {
    if (GetSetting -Path $SettingsPath -Key CertSubjectName) {
        RemoveSetting -Path $SettingsPath -Key CertSubjectName
    }
}

Task StoreCertSubjectName {
    $certSubjectName = 'CN='
    $certSubjectName += Read-Host -Prompt 'Enter the certificate subject name for script signing. Use exact casing, CN= prefix will be added'
    SetSetting -Key CertSubjectName -Value $certSubjectName -Path $SettingsPath
    "The new certificate subject name '$certSubjectName' has been stored in ${SettingsPath}."
}

Task ShowCertSubjectName {
    $CertSubjectName = GetSetting -Path $SettingsPath -Key CertSubjectName
    "The stored certificate is: $CertSubjectName"

    $cert = Get-ChildItem -Path Cert:\CurrentUser\My -CodeSigningCert |
            Where-Object { $_.Subject -eq $CertSubjectName -and $_.NotAfter -gt (Get-Date) } |
            Sort-Object -Property NotAfter -Descending | Select-Object -First 1

    if ($cert) {
        "A valid certificate for the subject $CertSubjectName has been found"
    }
    else {
        'A valid certificate has not been found'
    }
}

###############################################################################
# Helper functions
###############################################################################

function PromptUserForCredentialAndStorePassword {
    [Diagnostics.CodeAnalysis.SuppressMessage("PSProvideDefaultParameterValue", '')]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $DestinationPath,

        [Parameter(Mandatory)]
        [string]
        $Message,

        [Parameter(Mandatory, ParameterSetName = 'SaveSetting')]
        [string]
        $Key
    )

    $cred = Get-Credential -Message $Message -UserName "ignored"
    if ($DestinationPath) {
        SetSetting -Key $Key -Value $cred.Password -Path $DestinationPath
    }

    $cred
}

function AddSetting {
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSShouldProcess', '', Scope='Function')]
    param(
        [Parameter(Mandatory)]
        [string]$Key,

        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object]$Value
    )

    switch ($type = $Value.GetType().Name) {
        'securestring' { $setting = $Value | ConvertFrom-SecureString }
        default        { $setting = $Value }
    }

    if (Test-Path -LiteralPath $Path) {
        $storedSettings = Import-Clixml -Path $Path
        $storedSettings.Add($Key, @($type, $setting))
        $storedSettings | Export-Clixml -Path $Path
    }
    else {
        $parentDir = Split-Path -Path $Path -Parent
        if (!(Test-Path -LiteralPath $parentDir)) {
            New-Item $parentDir -ItemType Directory > $null
        }

        @{$Key = @($type, $setting)} | Export-Clixml -Path $Path
    }
}

function GetSetting {
    param(
        [Parameter(Mandatory)]
        [string]$Key,

        [Parameter(Mandatory)]
        [string]$Path
    )

    if (Test-Path -LiteralPath $Path) {
        $securedSettings = Import-Clixml -Path $Path
        if ($securedSettings.$Key) {
            switch ($securedSettings.$Key[0]) {
                'securestring' {
                    $value = $securedSettings.$Key[1] | ConvertTo-SecureString
                    $cred = New-Object -TypeName PSCredential -ArgumentList 'jpgr', $value
                    $cred.GetNetworkCredential().Password
                }
                default {
                    $securedSettings.$Key[1]
                }
            }
        }
    }
}

function SetSetting {
    param(
        [Parameter(Mandatory)]
        [string]$Key,

        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object]$Value
    )

    if (GetSetting -Key $Key -Path $Path) {
        RemoveSetting -Key $Key -Path $Path
    }

    AddSetting -Key $Key -Value $Value -Path $Path
}

function RemoveSetting {
    param(
        [Parameter(Mandatory)]
        [string]$Key,

        [Parameter(Mandatory)]
        [string]$Path
    )

    if (Test-Path -LiteralPath $Path) {
        $storedSettings = Import-Clixml -Path $Path
        $storedSettings.Remove($Key)
        if ($storedSettings.Count -eq 0) {
            Remove-Item -Path $Path
        }
        else {
            $storedSettings | Export-Clixml -Path $Path
        }
    }
    else {
        Write-Warning "The build setting file '$Path' has not been created yet."
    }
}

