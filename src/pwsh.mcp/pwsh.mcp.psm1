#Requires -Version 7.5

$PublicPath = Join-Path -Path $PSScriptRoot -ChildPath ''
if (Test-Path -Path $PublicPath -PathType Container) {
    $PublicFiles = Get-ChildItem -Path $PublicPath -Filter *.ps1 -File
    foreach ($File in $PublicFiles) {
        try {
            . $File.FullName
        }
        catch {
            Write-Error "Failed to source file: $($File.FullName). Error: $($_.Exception.Message)"
        }
    }
}
else {
    Write-Warning "Public directory not found at path: $PublicPath"
}
