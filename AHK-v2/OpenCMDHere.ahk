; #################
; #  OpenCMDHere  #
; #################

!c up::OpenCMDHere()

OpenCMDHere()
{
    win := 'ahk_class ConsoleWindowClass ahk_exe cmd.exe'
    winExp := 'ahk_class CabinetWClass ahk_exe explorer.exe'
    Static convert := " !#$%&'()-.*:?@[]^_``{|}~/"

    If WinActive(winExp)
        winObj := ComObject('Shell.Application').Windows
    Else
    {
        Run(A_ComSpec ' /E:ON /T:0A /K pushd C:\Users\' . A_UserName . '\Downloads',, 'Max', &winCMD)
        if WinWait(win . ' ahk_pid ' . winCMD,, 2)
            WinActivate(win . ' ahk_pid ' . winCMD)
        return
    }

    For win in winObj
    {
        pwd := SubStr(win.LocationURL, 9)
        Loop Parse, convert
            hex := Format('{:X}' , Ord(A_LoopField))
            ,pwd := StrReplace(pwd, hex, A_LoopField)
            pwd := StrReplace(pwd, "%", "")
            pwd := StrReplace(pwd, "'", "''")
            pwd := StrReplace(pwd, "/", "\")
            pwd := StrReplace(pwd, pwd, '"' . pwd . '"')
    }
     Run(A_ComSpec ' /E:ON /T:0A /K pushd ' . pwd,, 'Max', &winCMD)
     if WinWait(win . ' ahk_pid ' . winCMD,, 2)
        WinActivate(win . ' ahk_pid ' . winCMD)
     return
}
