param(
  [Parameter(Mandatory=$true)][string]$Command,
  [int]$TimeoutSec = 240
)
# 在独立隐藏桌面运行命令：主桌面零窗口、零任务栏、零焦点变化
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class HiddenDesk {
  [DllImport("user32.dll", CharSet=CharSet.Unicode, SetLastError=true)] public static extern IntPtr CreateDesktopW(string name, IntPtr device, IntPtr devmod, uint flags, uint access, IntPtr attr);
  [DllImport("user32.dll")] public static extern bool CloseDesktop(IntPtr h);
  [DllImport("kernel32.dll", CharSet=CharSet.Unicode)] public static extern bool CreateProcess(string app, string cmd, IntPtr pa, IntPtr ta, bool inh, uint flags, IntPtr env, string cwd, ref STARTUPINFO si, out PROCESS_INFORMATION pi);
  [DllImport("kernel32.dll")] public static extern uint WaitForSingleObject(IntPtr h, uint ms);
  [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
  public struct STARTUPINFO { public uint cb; public string lpReserved; public string lpDesktop; public string lpTitle; public uint dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwBFlags; public short wShowWindow, cbReserved2; public IntPtr lpReserved2, hStdInput, hStdOutput, hStdError; }
  [StructLayout(LayoutKind.Sequential)]
  public struct PROCESS_INFORMATION { public IntPtr hProcess, hThread; public int dwProcessId, dwThreadId; }
}
'@
$GENERIC_ALL = 0x10000000
$desk = [HiddenDesk]::CreateDesktopW("ZAgentHiddenDesk", [IntPtr]::Zero, [IntPtr]::Zero, 0, $GENERIC_ALL, [IntPtr]::Zero)
if ($desk -eq [IntPtr]::Zero) { Write-Output "DESKTOP_CREATE_FAILED"; exit 2 }
$si = New-Object HiddenDesk+STARTUPINFO
$si.cb = [System.Runtime.InteropServices.Marshal]::SizeOf($si)
$si.lpDesktop = "ZAgentHiddenDesk"
$pi = New-Object HiddenDesk+PROCESS_INFORMATION
$ok = [HiddenDesk]::CreateProcess($null, $Command, [IntPtr]::Zero, [IntPtr]::Zero, $false, 0, [IntPtr]::Zero, (Get-Location).Path, [ref]$si, [ref]$pi)
if (-not $ok) { Write-Output ("CREATEPROCESS_FAILED " + [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()); exit 3 }
$wait = [HiddenDesk]::WaitForSingleObject($pi.hProcess, [uint32]($TimeoutSec * 1000))
if ($wait -eq 258) { Write-Output "TIMEOUT"; Stop-Process -Id $pi.dwProcessId -Force -ErrorAction SilentlyContinue } else { Write-Output ("EXITED code=" + $wait) }
[HiddenDesk]::CloseHandle($pi.hProcess) | Out-Null
[HiddenDesk]::CloseHandle($pi.hThread) | Out-Null
[HiddenDesk]::CloseDesktop($desk) | Out-Null
