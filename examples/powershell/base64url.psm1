
# https://www.powershellgallery.com/packages/Posh-ACME/4.20.0/Content/Private%5CConvertTo-Base64Url.ps1

function ConvertTo-Base64Url {
    [CmdletBinding()]
    [OutputType('System.String')]
    param(
        [Parameter(ParameterSetName='String',Mandatory,Position=0,ValueFromPipeline)]
        [AllowEmptyString()]
        [string]$Text,
        [Parameter(ParameterSetName='String')]
        [switch]$FromBase64,
        [Parameter(ParameterSetName='Bytes',Mandatory,Position=0)]
        [AllowEmptyCollection()]
        [byte[]]$Bytes
    )

    Process {

        if (-not $FromBase64) {

            # get a byte array from the input string
            if ($PSCmdlet.ParameterSetName -eq 'String') {
                $Bytes = [Text.Encoding]::UTF8.GetBytes($Text)
            }

            # standard base64 encoder
            $s = [Convert]::ToBase64String($Bytes)

        } else {
            # $Text is already Base64 encoded, we just need the Url'ized version
            $s = $Text
        }

        # remove trailing '='s
        $s = $s.Split('=')[0]

        # 62nd and 63rd char of encoding
        $s = $s.Replace('+','-').Replace('/','_')

        return $s

    }

}

# https://www.powershellgallery.com/packages/Posh-ACME/4.20.0/Content/Private%5CConvertFrom-Base64Url.ps1

function ConvertFrom-Base64Url {
    [CmdletBinding()]
    [OutputType('System.String', ParameterSetName='String')]
    [OutputType('System.Byte[]', ParameterSetName='Bytes')]
    param(
        [Parameter(ParameterSetName='Bytes',Mandatory,Position=0,ValueFromPipeline)]
        [Parameter(ParameterSetName='String',Mandatory,Position=0,ValueFromPipeline)]
        [AllowEmptyString()]
        [string]$Base64Url,
        [Parameter(ParameterSetName='Bytes',Mandatory)]
        [switch]$AsByteArray
    )

    Process {

        # short circuit on empty strings
        if ($Base64Url -eq [string]::Empty) {
            return [string]::Empty
        }

        # put the standard unsafe characters back
        $s = $Base64Url.Replace('-', '+').Replace('_', '/')

        # put the padding back
        switch ($s.Length % 4) {
            0 { break; }             # no padding needed
            2 { $s += '=='; break; } # two pad chars
            3 { $s += '='; break; }  # one pad char
            default { throw "Invalid Base64Url string" }
        }

        # convert it using standard base64 stuff
        if ($AsByteArray) {
            return [Convert]::FromBase64String($s)
        } else {
            return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($s))
        }

    }

}

function Clear-AllUserVariables{
  Get-Variable | Where-Object { $_.Options -notmatch "Constant|ReadOnly" } | ForEach-Object { Remove-Variable -Name $_.Name }
}