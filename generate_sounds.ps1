
$sampleRate = 22050
$channels = 1
$bitsPerSample = 16
$blockAlign = $channels * ($bitsPerSample / 8)

function Write-WavFile {
    param(
        [string]$Path,
        [double]$FreqHz,
        [double]$DurSec
    )
    $numSamples = [int]($sampleRate * $DurSec)
    $byteRate = $sampleRate * $channels * ($bitsPerSample / 8)
    $dataSize = $numSamples * $blockAlign

    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($ms)
    
    $bw.Write([byte[]][System.Text.Encoding]::ASCII.GetBytes('RIFF'))
    $bw.Write([int32](36 + $dataSize))
    $bw.Write([byte[]][System.Text.Encoding]::ASCII.GetBytes('WAVE'))
    $bw.Write([byte[]][System.Text.Encoding]::ASCII.GetBytes('fmt '))
    $bw.Write([int32]16)
    $bw.Write([int16]1)
    $bw.Write([int16]$channels)
    $bw.Write([int32]$sampleRate)
    $bw.Write([int32]$byteRate)
    $bw.Write([int16]$blockAlign)
    $bw.Write([int16]$bitsPerSample)
    $bw.Write([byte[]][System.Text.Encoding]::ASCII.GetBytes('data'))
    $bw.Write([int32]$dataSize)

    for ($i = 0; $i -lt $numSamples; $i++) {
        $fade = 1.0 - ($i / $numSamples)
        $val = [int16](32767 * 0.5 * $fade * [Math]::Sin(2 * [Math]::PI * $FreqHz * $i / $sampleRate))
        $bw.Write($val)
    }
    $bw.Flush()
    [System.IO.File]::WriteAllBytes($Path, $ms.ToArray())
    $bw.Close()
    Write-Host "Written: $Path"
}

Write-WavFile -Path "assets\sounds\notification_pop.mp3" -FreqHz 880 -DurSec 0.3
Write-WavFile -Path "assets\sounds\success_chime.mp3" -FreqHz 660 -DurSec 0.5
Write-Host "Done!"
