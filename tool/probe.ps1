param([string]$Mode = '--debug', [int]$Attempts = 2, [int]$MaxSeconds = 60)

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class P {
  [DllImport("kernel32.dll", SetLastError = true)] public static extern IntPtr OpenProcess(uint a, bool i, uint p);
  [DllImport("kernel32.dll", SetLastError = true)] public static extern bool GetExitCodeProcess(IntPtr h, out uint c);
  [DllImport("kernel32.dll", SetLastError = true)] public static extern uint WaitForSingleObject(IntPtr h, uint ms);
  [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
}
"@

function Classify([uint32]$c) {
  switch ($c) {
    0 { 'CLEAN EXIT' }
    3221225477 { 'ACCESS VIOLATION' }
    3221225474 { 'STACK OVERFLOW' }
    3221226505 { 'HEAP CORRUPTION' }
    default { "0x$('{0:X8}' -f $c)" }
  }
}

$pre = @(Get-Process dart, flutter, bjtuselfserviceaio -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)

for ($a = 1; $a -le $Attempts; $a++) {
  Start-Sleep -Seconds 12
  $out = "$env:TEMP\rm.txt"
  Remove-Item $out -ErrorAction SilentlyContinue
  $cmd = Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', "flutter run -d windows $Mode > `"$out`" 2>&1" -WindowStyle Hidden -PassThru
  Start-Sleep -Seconds 2

  $app = $null
  for ($i = 0; $i -lt 1500 -and -not $app; $i++) {
    $app = Get-Process bjtuselfserviceaio -ErrorAction SilentlyContinue |
           Where-Object { $pre -notcontains $_.Id } | Select-Object -First 1
    if (-not $app) { Start-Sleep -Milliseconds 200 }
  }
  if (-not $app) {
    "attempt $a : app never started (build error?)"
    Get-Content $out -Tail 2 -ErrorAction SilentlyContinue
    Get-Process dart, flutter, bjtuselfserviceaio -ErrorAction SilentlyContinue | Where-Object { $pre -notcontains $_.Id } | Stop-Process -Force -ErrorAction SilentlyContinue
    Stop-Process -Id $cmd.Id -Force -ErrorAction SilentlyContinue
    continue
  }

  $h = [P]::OpenProcess(0x100400, $false, [uint32]$app.Id)
  $up = Get-Date; $code = 4294967295
  while ($true) {
    $wr = [P]::WaitForSingleObject($h, 500)
    if ($wr -eq 0) { [void][P]::GetExitCodeProcess($h, [ref]$code); break }
    if (((Get-Date) - $up).TotalSeconds -gt $MaxSeconds) { break }
  }
  [void][P]::CloseHandle($h)
  $ran = [math]::Round(((Get-Date) - $up).TotalSeconds, 1)
  if ($code -eq 4294967295) { "attempt $a : SURVIVED $ran s" } else { "attempt $a : DIED after $ran s -> $(Classify $code)" }
  $impeller = Select-String -Path $out -Pattern 'Impeller rendering backend' -ErrorAction SilentlyContinue
  "  impeller log: " + $(if ($impeller) { 'ON' } else { 'OFF/absent' })
  Get-Process dart, flutter, bjtuselfserviceaio -ErrorAction SilentlyContinue |
    Where-Object { $pre -notcontains $_.Id } | Stop-Process -Force -ErrorAction SilentlyContinue
  Stop-Process -Id $cmd.Id -Force -ErrorAction SilentlyContinue
}