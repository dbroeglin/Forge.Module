Describe 'Forge.Module' {
    
    $ModuleName   = "Forge.Module"
    $ManifestPath = "$PSScriptRoot\..\$ModuleName\$ModuleName.psd1"

    It "loads" {
        {
            Import-Module -Force $ManifestPath        
        } | Should Not Throw
    }

    AfterEach {
        Remove-Module $ModuleName
    }
}