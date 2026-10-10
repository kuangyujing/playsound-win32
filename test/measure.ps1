# Measure the time to run playsound.exe, and compare it with PowerShell.
#
# Usage: powershell -ExecutionPolicy Bypass -File test\measure.ps1
#            [-Wav <file.wav>] [-Count <number>] [-Exe <playsound.exe>]
#            [-NoSound]
#
# Each command runs once to warm up, and then -Count times. The script
# shows the median time.
#
# - "playsound.exe -h" and "powershell.exe -Command exit" play no sound.
#   They show the cost of starting each program.
# - Without -NoSound, the script also plays -Wav with playsound.exe and
#   with System.Media.SoundPlayer in a new PowerShell process. Run this on
#   a PC with speakers. Both wait until the sound ends, so both times
#   include the length of the sound.

param(
    [string]$Wav = (Join-Path $env:WINDIR 'Media\tada.wav'),
    [int]$Count = 5,
    [string]$Exe = (Join-Path $PSScriptRoot '..\build\playsound.exe'),
    [switch]$NoSound
)

$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path

function Measure-Median {
    param([scriptblock]$Command)
    & $Command | Out-Null
    $times = for ($i = 0; $i -lt $Count; $i++) {
        (Measure-Command { & $Command | Out-Null }).TotalMilliseconds
    }
    $sorted = @($times | Sort-Object)
    [math]::Round($sorted[[math]::Floor(($sorted.Count - 1) / 2)], 1)
}

$results = [ordered]@{}
$results['playsound.exe -h'] = Measure-Median { & $Exe -h }
$results['powershell.exe -Command exit'] = Measure-Median {
    powershell.exe -NoProfile -NonInteractive -Command exit
}

if (-not $NoSound) {
    $Wav = (Resolve-Path -LiteralPath $Wav).Path
    # The new PowerShell process reads the path from an environment
    # variable, so the path needs no quoting.
    $env:PLAYSOUND_MEASURE_WAV = $Wav
    $results['playsound.exe <file>'] = Measure-Median { & $Exe $Wav }
    $results['powershell.exe + SoundPlayer'] = Measure-Median {
        powershell.exe -NoProfile -NonInteractive -Command `
            '(New-Object System.Media.SoundPlayer $env:PLAYSOUND_MEASURE_WAV).PlaySync()'
    }
    "File: $Wav"
}

"Median of $Count runs:"
foreach ($name in $results.Keys) {
    '  {0,-30} {1,8} ms' -f $name, $results[$name]
}
