function <%= $Name %> {
    <#
    .SYNOPSIS
        <%= $Name %> synopsis.

    .DESCRIPTION
        <%= $Name %> description.

<% $Parameters | ForEach { %>
    .PARAMETER <%= $_ %>
        <%= $_ %> description.

<% } %>
    .EXAMPLE
        <%= $Name %> #...
    #>
    [CmdletBinding()]
    Param(
<% $Parameters | ForEach { $i = 1 } { %>
       <%= $_ %><%= if ($i++ -lt $Parameters.length) { "," } %>
<% } %>
    )
    Begin {
        # Begin block
    }
    Process {
        # Process block
    }
    End {
        # End block
    }
}