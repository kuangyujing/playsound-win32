# Tests for playsound.exe that do not need an audio device.
#
# Usage: pwsh test/smoke.ps1 [path\to\playsound.exe]
#
# The exit code of playsound.exe is always 0, so these tests check the
# exit code and the text on standard output and standard error.
# Without an audio device, PlaySound fails for a good WAV file too, so
# for a file that exists, the test accepts no message or
# "cannot play the file", but not "file not found".

param(
    [string]$Exe = (Join-Path $PSScriptRoot '..\build\playsound.exe')
)

$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path

$Usage = 'Usage: playsound <file.wav>'
$NotFound = "playsound: file not found`r`n"
$IsDirectory = "playsound: path is a directory`r`n"
$CannotPlay = "playsound: cannot play the file`r`n"

# Run playsound.exe with a raw command line, so that the tests do not
# depend on how PowerShell quotes arguments.
function Invoke-PlaySound {
    param(
        [string]$Arguments,
        [string]$WorkingDirectory = $PWD.Path,
        [string]$PathVariable = ''
    )
    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName = $Exe
    $info.Arguments = $Arguments
    $info.WorkingDirectory = $WorkingDirectory
    $info.UseShellExecute = $false
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    if ($PathVariable -ne '') {
        $info.EnvironmentVariables['PATH'] = $PathVariable
    }
    $process = [System.Diagnostics.Process]::Start($info)
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    [pscustomobject]@{ ExitCode = $process.ExitCode; Out = $stdout; Err = $stderr }
}

$script:Failures = 0

# Check one result. Each expected value is a script block that gets the
# actual text in $_ and returns $true if it is good.
function Test-Result {
    param(
        [string]$Name,
        $Result,
        [scriptblock]$Out = { $_ -eq '' },
        [scriptblock]$Err = { $_ -eq '' }
    )
    $ok = ($Result.ExitCode -eq 0) -and
          ($Result.Out | ForEach-Object $Out) -and
          ($Result.Err | ForEach-Object $Err)
    $status = if ($ok) { 'ok  ' } else { 'FAIL' }
    $message = ($Result.Err -replace '\s+', ' ').Trim()
    if ($message.Length -gt 60) { $message = $message.Substring(0, 60) + '...' }
    Write-Host ("{0} {1} (exit code {2}, stderr: '{3}')" -f $status, $Name, $Result.ExitCode, $message)
    if (-not $ok) { $script:Failures++ }
}

# Write a short 16-bit PCM WAV file (8 kHz, mono, silent).
function New-Wav {
    param([string]$Path)
    $dataSize = 1600
    $writer = New-Object System.IO.BinaryWriter([System.IO.File]::Create($Path))
    $ascii = [System.Text.Encoding]::ASCII
    $writer.Write($ascii.GetBytes('RIFF'))
    $writer.Write([int](36 + $dataSize))
    $writer.Write($ascii.GetBytes('WAVEfmt '))
    $writer.Write([int]16)       # Size of the fmt chunk
    $writer.Write([int16]1)      # PCM
    $writer.Write([int16]1)      # Channels
    $writer.Write([int]8000)     # Samples per second
    $writer.Write([int]16000)    # Bytes per second
    $writer.Write([int16]2)      # Bytes per sample (all channels)
    $writer.Write([int16]16)     # Bits per sample
    $writer.Write($ascii.GetBytes('data'))
    $writer.Write([int]$dataSize)
    $writer.Write((New-Object byte[] $dataSize))
    $writer.Close()
}

# Test files. Non-ASCII names are made from character codes, so this
# script file itself is plain ASCII.
$japanese = [string][char]0x65E5 + [char]0x672C          # "Nihon"
$katakana = [string][char]0x30C6 + [char]0x30B9 + [char]0x30C8  # "Tesuto"
$root = Join-Path ([System.IO.Path]::GetTempPath()) ('playsound-test-' + [guid]::NewGuid())
$plainDir = Join-Path $root 'plain'
$unicodeDir = Join-Path $root "$japanese dir"
$pathDir = Join-Path $root 'in-path'
$emptyDir = Join-Path $root 'empty'
foreach ($dir in $plainDir, $unicodeDir, $pathDir, $emptyDir) {
    New-Item -ItemType Directory -Path $dir | Out-Null
}
$wavName = "$katakana sound.wav"
$unicodeWav = Join-Path $unicodeDir $wavName
New-Wav $unicodeWav
New-Wav (Join-Path $plainDir 'name with space.wav')
New-Wav (Join-Path $pathDir 'only-in-path.wav')
$fakeWav = Join-Path $plainDir 'fake.wav'
[System.IO.File]::WriteAllText($fakeWav, 'This is not a WAV file.')

$isUsage = { $_.StartsWith($Usage) }
$isFound = { $_ -eq '' -or $_ -eq $CannotPlay }

try {
    Write-Host "Testing $Exe"

    # Command line
    Test-Result 'no arguments' (Invoke-PlaySound '') -Err $isUsage
    foreach ($help in '-h', '--help', '/?') {
        Test-Result "help ($help)" (Invoke-PlaySound $help) -Out $isUsage
    }
    Test-Result 'two arguments' (Invoke-PlaySound 'a.wav b.wav') -Err $isUsage
    Test-Result 'help and one more argument' (Invoke-PlaySound '-h x') -Err $isUsage

    # Quotes and backslashes, with the rules of the Microsoft C runtime
    Test-Result '"a\" b" is one argument' (Invoke-PlaySound '"a\" b"') -Err { $_ -eq $NotFound }
    Test-Result '"a\\" b is two arguments' (Invoke-PlaySound '"a\\" b') -Err $isUsage
    Test-Result 'quoted path with spaces' (Invoke-PlaySound "`"$plainDir\name with space.wav`"") -Err $isFound
    Test-Result 'quote ends in the middle of a path' (Invoke-PlaySound "`"$plainDir\name with `"space.wav") -Err $isFound
    Test-Result 'empty argument' (Invoke-PlaySound '""') -Err { $_ -eq $NotFound }

    # Paths
    Test-Result 'missing file' (Invoke-PlaySound "`"$root\missing.wav`"") -Err { $_ -eq $NotFound }
    Test-Result 'directory' (Invoke-PlaySound "`"$plainDir`"") -Err { $_ -eq $IsDirectory }
    Test-Result 'Japanese characters and spaces' (Invoke-PlaySound "`"$unicodeWav`"") -Err $isFound
    Test-Result 'relative path' (Invoke-PlaySound "`"$wavName`"" -WorkingDirectory $unicodeDir) -Err $isFound
    Test-Result 'forward slashes' (Invoke-PlaySound ('"' + $unicodeWav.Replace('\', '/') + '"')) -Err $isFound
    Test-Result 'file only in a PATH folder is not played' `
        (Invoke-PlaySound 'only-in-path.wav' -WorkingDirectory $emptyDir -PathVariable "$pathDir;$env:PATH") `
        -Err { $_ -eq $NotFound }

    # Path length: PlaySound takes at most 255 characters.
    $path255 = 'C:\' + ('a' * 248) + '.wav'
    $path256 = 'C:\' + ('a' * 249) + '.wav'
    Test-Result 'full path of 255 characters' (Invoke-PlaySound $path255) -Err { $_ -eq $NotFound }
    Test-Result 'full path of 256 characters: no message' (Invoke-PlaySound $path256)
    Test-Result 'long relative path: no message' (Invoke-PlaySound (('b' * 300) + '.wav'))

    # Not a WAV file
    Test-Result 'not a WAV file' (Invoke-PlaySound "`"$fakeWav`"") -Err { $_ -eq $CannotPlay }
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

if ($script:Failures -gt 0) {
    Write-Host "$script:Failures test(s) failed."
    exit 1
}
Write-Host 'All tests passed.'
