# Speaks an SSML file with one of Windows' OneCore voices (the newer set:
# David, Mark, Zira, Hazel, Susan, George, James, Catherine...) to a WAV.
# System.Speech only sees three of them, so the Mission Control cast
# (tools/generate_voice.py, data/mc_cast.json) goes through WinRT instead.
# Usage: powershell -File speak_onecore.ps1 -voice George -ssml in.xml -out out.wav
param([string]$voice, [string]$ssml, [string]$out)
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Media.SpeechSynthesis.SpeechSynthesizer, Windows.Media.SpeechSynthesis, ContentType = WindowsRuntime]
$null = [Windows.Storage.Streams.DataReader, Windows.Storage.Streams, ContentType = WindowsRuntime]
$asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
function Await($op, $type) { $t = $asTask.MakeGenericMethod($type).Invoke($null, @($op)); $t.Wait(-1) | Out-Null; $t.Result }
$s = New-Object Windows.Media.SpeechSynthesis.SpeechSynthesizer
$s.Voice = [Windows.Media.SpeechSynthesis.SpeechSynthesizer]::AllVoices | Where-Object { $_.DisplayName -like "*$voice*" } | Select-Object -First 1
if ($null -eq $s.Voice) { throw "No OneCore voice named $voice" }
$text = [IO.File]::ReadAllText($ssml)
$stream = Await ($s.SynthesizeSsmlToStreamAsync($text)) ([Windows.Media.SpeechSynthesis.SpeechSynthesisStream])
$reader = New-Object Windows.Storage.Streams.DataReader($stream.GetInputStreamAt(0))
$n = [uint32]$stream.Size
Await ($reader.LoadAsync($n)) ([uint32]) | Out-Null
$bytes = New-Object byte[] $n
$reader.ReadBytes($bytes)
[IO.File]::WriteAllBytes($out, $bytes)
