
Function Get-StringHash{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [String]$String,

        [ValidateSet("SHA1", "SHA256", "SHA384", "SHA512", "MACTripleDES", "MD5", "RIPEMD160")]
        [System.String]
        $Algorithm="SHA256"
    )

    $stringAsStream = [System.IO.MemoryStream]::new()
    $writer = [System.IO.StreamWriter]::new($stringAsStream)
    $writer.write($String)
    $writer.Flush()
    $stringAsStream.Position = 0
    Get-FileHash -InputStream $stringAsStream -Algorithm $Algorithm | Select Algorithm,Hash,@{Name = "String"; Expression = {$String}}
}

function Convert-Size {
    [cmdletbinding()]
    param(
        [validateset("Bytes","KB","MB","GB","TB")]
        [string]$From,
        [validateset("Bytes","KB","MB","GB","TB")]
        [string]$To,
        [Parameter(Mandatory=$true)]
        [double]$Value,
        [int]$Precision = 4
    )
    switch($From) {
        "Bytes" {$value = $Value }
        "KB" {$value = $Value * 1024 }
        "MB" {$value = $Value * 1024 * 1024}
        "GB" {$value = $Value * 1024 * 1024 * 1024}
        "TB" {$value = $Value * 1024 * 1024 * 1024 * 1024}
    }

    switch ($To) {
        "Bytes" {return $value}
        "KB" {$Value = $Value/1KB}
        "MB" {$Value = $Value/1MB}
        "GB" {$Value = $Value/1GB}
        "TB" {$Value = $Value/1TB}
    }

    return [Math]::Round($value,$Precision,[MidPointRounding]::AwayFromZero)
}

Function Format-FileSize() {
    Param ([int64]$size)
    If ($size -gt 1TB) {[string]::Format("{0:0.00}TB", $size / 1TB)}
    ElseIf ($size -gt 1GB) {[string]::Format("{0:0.00}GB", $size / 1GB)}
    ElseIf ($size -gt 1MB) {[string]::Format("{0:0.00}MB", $size / 1MB)}
    ElseIf ($size -gt 1KB) {[string]::Format("{0:0.00}kB", $size / 1KB)}
    ElseIf ($size -gt 0) {[string]::Format("{0:0.00}B", $size)}
    Else {""}
}


<#
Function Invoke-HashProcess{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateSet("SwmFiles", "WimFile", "FileList", "FolderList", "TsFile", "Files", "Folders")]
        [System.String]
        $Type,

        [Parameter(Mandatory, ParameterSetName="Path")]
        [System.String[]]
        $Path,

        [Parameter(Mandatory, ParameterSetName="Variable")]
        [String]
        $Variable,

        [ValidateSet("SHA1", "SHA256", "SHA384", "SHA512", "MACTripleDES", "MD5", "RIPEMD160")]
        [System.String]
        $Algorithm="SHA256",

        [string]$UIStatusElement,

        [switch]$AsJob

    )

    Begin{}
    Process{
        if($PSCmdlet.ParameterSetName -eq "Variable"){

        }
        Else{
            foreach($filePath in $Path){

            }
        }

    }
    End{

    }
}


#Invoke-HashProcess -Path "\\192.168.1.10\Development\DeployNMCI_OEM\Content\Deploy\Operating Systems\SHB_REF_2020-6-29_1805\SHB_REF_2020-6-29_1805.wim" -UIStatusElement 'Hash_DeployWIM_Text'

#>