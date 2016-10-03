Set-PSDebug -Strict
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$PSScriptRoot\..\<%= $ModuleName %>\$sut"

Describe "<%= $Name %>" {
    It "should just work" {
        # TODO: an actual test
    }
}