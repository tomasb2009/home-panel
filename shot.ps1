$code = @"
using System;
using System.Runtime.InteropServices;
public class WinApi {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int ht, bool repaint);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
  [DllImport("user32.dll")] public static extern void keybd_event(byte k, byte s, uint f, UIntPtr e);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L,T,R,B; }
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X,Y; }
}
"@
Add-Type -TypeDefinition $code
[WinApi]::SetProcessDPIAware() | Out-Null
Add-Type -AssemblyName System.Drawing
$proc = Get-Process -Name home_panel -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if ($null -eq $proc) { Write-Output "process not found"; exit 1 }
$h = $proc.MainWindowHandle
[WinApi]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)
[WinApi]::ShowWindow($h, 9) | Out-Null
[WinApi]::MoveWindow($h, 0, 0, 1600, 1000, $true) | Out-Null
[WinApi]::BringWindowToTop($h) | Out-Null
[WinApi]::SetForegroundWindow($h) | Out-Null
[WinApi]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
[WinApi]::SetCursorPos(780, 250) | Out-Null
Start-Sleep -Milliseconds 1000
$r = New-Object WinApi+RECT
[WinApi]::GetClientRect($h, [ref]$r) | Out-Null
$tl = New-Object WinApi+POINT; $tl.X = 0; $tl.Y = 0
[WinApi]::ClientToScreen($h, [ref]$tl) | Out-Null
$w = $r.R - $r.L; $ht = $r.B - $r.T
$bmp = New-Object System.Drawing.Bitmap $w, $ht
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($tl.X, $tl.Y, 0, 0, (New-Object System.Drawing.Size($w, $ht)))
$out = "C:\Users\pedro\OneDrive\Escritorio\home-panel\shot.png"
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Output "saved $out ($w x $ht)"
