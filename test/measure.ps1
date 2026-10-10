# Compare how long it takes to play a WAV file with playsound.exe and with
# PowerShell's System.Media.SoundPlayer. Run it on a PC with speakers.
#
# Usage: powershell -ExecutionPolicy Bypass -File test\measure.ps1
#            [-Wav <file.wav>] [-Count <number>] [-Exe <playsound.exe>]
#
# Both ways wait until the sound ends, so each time includes the length
# of the sound. The difference between the times is the extra cost.

param(
    [string]$Wav = (Join-Path $env:WINDIR 'Media\tada.wav'),
    [int]$Count = 5,
    [string]$Exe = (Join-Path $PSScriptRoot '..\build\playsound.exe')
)

$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$Wav = (Resolve-Path -LiteralPath $Wav).Path

function Measure-Average {
    param([scriptblock]$Command)
    $total = 0.0
    for ($i = 0; $i -lt $Count; $i++) {
        $total += (Measure-Command $Command).TotalMilliseconds
    }
    [math]::Round($total / $Count)
}

# The new PowerShell process reads the path from an environment variable,
# so the path needs no quoting.
$env:PLAYSOUND_MEASURE_WAV = $Wav
$soundPlayer = '(New-Object System.Media.SoundPlayer $env:PLAYSOUND_MEASURE_WAV).PlaySync()'

$results = [ordered]@{
    'playsound.exe -h (no sound)'  = Measure-Average { & $Exe -h | Out-Null }
    'playsound.exe'                = Measure-Average { & $Exe $Wav }
    'powershell.exe + SoundPlayer' = Measure-Average { powershell.exe -NoProfile -NonInteractive -Command $soundPlayer }
}

"File: $Wav"
"Average of $Count runs:"
foreach ($name in $results.Keys) {
    '  {0,-30} {1,6} ms' -f $name, $results[$name]
}
