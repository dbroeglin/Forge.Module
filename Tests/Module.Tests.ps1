Describe 'Forge.Module' {
    
    $ModuleName   = "Forge.Module"
    $ManifestPath = "$PSScriptRoot\..\$ModuleName\$ModuleName.psd1"

    It "loads" {
        {
            Import-Module -Force $ManifestPath        
        } | Should Not Throw
    }

    AfterEach {
        # -Force is required because Remove-Module tries to remove 
        # EPS, Forge and Forge.Module in that order !?!
        Remove-Module $ModuleName -Force
    }
}