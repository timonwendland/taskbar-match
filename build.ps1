$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2
$root = $PSScriptRoot
$source = Join-Path $root 'src\TaskbarMatch.cs'
$helper = Join-Path $root 'build\TaskbarMatch.Xaml.dll'
$text = [IO.File]::ReadAllText($source)
$expected = [regex]::Match($text, 'HelperHash = "([a-f0-9]{64})"').Groups[1].Value
if (-not (Test-Path -LiteralPath $helper)) { throw 'Build the native helper first: python build_native.py' }
if ((Get-FileHash -LiteralPath $helper -Algorithm SHA256).Hash -ne $expected) { throw 'Native helper hash does not match the source.' }
$package = Join-Path $root 'dist\TaskbarMatch-1.2.0-beta1'
New-Item -ItemType Directory -Path $package -Force | Out-Null
$exe = Join-Path $package 'TaskbarMatch.exe'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
& $compiler /nologo /target:winexe /platform:x64 /optimize+ /warn:4 /warnaserror+ /r:System.dll /r:System.Core.dll /r:System.Drawing.dll /r:System.Windows.Forms.dll ('/win32manifest:' + (Join-Path $root 'src\TaskbarMatch.manifest')) ('/resource:' + $helper + ',TaskbarMatch.Xaml.dll') ('/out:' + $exe) $source
if ($LASTEXITCODE -ne 0) { throw 'C# build failed.' }
$test = Start-Process -FilePath $exe -ArgumentList '--selftest' -Wait -PassThru -WindowStyle Hidden
if ($test.ExitCode -ne 0) { throw 'Startup self-test failed; check runtime.log.' }
Copy-Item -LiteralPath (Join-Path $root 'LICENSE.txt') -Destination $package -Force
Copy-Item -LiteralPath (Join-Path $root 'README.md') -Destination $package -Force
$hash = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText((Join-Path $package 'SHA256SUMS.txt'), $hash + "  TaskbarMatch.exe`r`n")
$zip = Join-Path $root 'dist\TaskbarMatch-1.2.0-beta1-exe.zip'
Compress-Archive -Path (Join-Path $package '*') -DestinationPath $zip -Force
Write-Output ('Built: ' + $exe)
Write-Output ('SHA256: ' + $hash)
