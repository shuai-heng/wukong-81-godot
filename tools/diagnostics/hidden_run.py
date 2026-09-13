import ctypes, sys, time
from ctypes import wintypes

k32 = ctypes.windll.kernel32
u32 = ctypes.windll.user32
GENERIC_ALL = 0x10000000
CREATE_UNICODE_ENV = 0x400

class STARTUPINFOW(ctypes.Structure):
    _fields_ = [
        ("cb", wintypes.DWORD), ("lpReserved", wintypes.LPWSTR),
        ("lpDesktop", wintypes.LPWSTR), ("lpTitle", wintypes.LPWSTR),
        ("dwX", wintypes.DWORD), ("dwY", wintypes.DWORD),
        ("dwXSize", wintypes.DWORD), ("dwYSize", wintypes.DWORD),
        ("dwXCountChars", wintypes.DWORD), ("dwYCountChars", wintypes.DWORD),
        ("dwFillAttribute", wintypes.DWORD), ("dwFlags", wintypes.DWORD),
        ("wShowWindow", wintypes.WORD), ("cbReserved2", wintypes.WORD),
        ("lpReserved2", ctypes.c_void_p), ("hStdInput", wintypes.HANDLE),
        ("hStdOutput", wintypes.HANDLE), ("hStdError", wintypes.HANDLE)]

class PROCESS_INFORMATION(ctypes.Structure):
    _fields_ = [("hProcess", wintypes.HANDLE), ("hThread", wintypes.HANDLE),
                ("dwProcessId", wintypes.DWORD), ("dwThreadId", wintypes.DWORD)]

def main():
    cmdline = sys.argv[1]
    timeout_s = float(sys.argv[2]) if len(sys.argv) > 2 else 240.0
    desk = u32.CreateDesktopW("ZAgentHiddenDesk", None, None, 0, GENERIC_ALL, None)
    if not desk:
        print("DESKTOP_CREATE_FAILED err=%d" % k32.GetLastError())
        sys.exit(2)
    si = STARTUPINFOW()
    si.cb = ctypes.sizeof(si)
    si.lpDesktop = "ZAgentHiddenDesk"
    pi = PROCESS_INFORMATION()
    cmd = ctypes.create_unicode_buffer(cmdline)
    ok = k32.CreateProcessW(None, cmd, None, None, False, 0, None, None, ctypes.byref(si), ctypes.byref(pi))
    if not ok:
        print("CREATEPROCESS_FAILED err=%d" % k32.GetLastError())
        sys.exit(3)
    wait = k32.WaitForSingleObject(pi.hProcess, int(timeout_s * 1000))
    if wait == 0x102:
        print("TIMEOUT")
        k32.TerminateProcess(pi.hProcess, 1)
    else:
        code = wintypes.DWORD()
        k32.GetExitCodeProcess(pi.hProcess, ctypes.byref(code))
        print("EXITED code=%d" % code.value)
    k32.CloseHandle(pi.hProcess)
    k32.CloseHandle(pi.hThread)
    u32.CloseDesktop(desk)

if __name__ == "__main__":
    main()
