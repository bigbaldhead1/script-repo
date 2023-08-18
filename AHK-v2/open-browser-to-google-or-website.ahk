/*____________________________________________________________________________________

    Open your browser and search the clipboard or the currently highlighted text using
    Google or if it is a website then directly load it.

    Instructions:
                  1. Change the variable 'Browser' to the full path of the exe you wish to use.
                  2. If needed, use WindowSpy.ahk to replace the variable 'win' with the correct text.

    Test the strings below!

    funny cat videos
    how to bake a pie
    amazon.com
    mail.google.com
    https://github.com/slyfox1186/script-repo/

  */

^!c up::
{
    Browser := 'C:\Program Files\Google\Chrome Beta\Application\chrome.exe' ; YOU MUST CHANGE THIS AS NECESSARY
    win := 'ahk_class Chrome_WidgetWin_1 ahk_exe chrome.exe' ; YOU MUST CHANGE THIS AS NECESSARY

    SetControlDelay 1 ; make sure the script is run as fast as possible without overdoing it.

    ClipSaved := ClipboardAll() ; save current A_Clipboard contents to its own variable
    A_Clipboard := "" ; Empty the clipboard

    Send '^c'
    if !ClipWait(0.75)
        A_Clipboard := ClipSaved ; if nothing is saved in the A_Clipboard from the clipwait command then use the current A_Clipboard contents

    ; A_Clipboard is the text-only bit of the clipboard.
    ; trim whitespace including "enter", because some apps are overzealous when selecting text. Trim does spaces and tabs by default."
    string := Trim(A_Clipboard, " `t`r`n") 

    ; if the text ends in specific text matching a set of TLDs, assume it's a www address.
    ; otherwise, query the text.
    ; if the text does not end with the listed postfix, add "?" so Chrome treats it as a query.
    reg := RegExMatch(string, "i)^\S+\.(com|de|gov|io|jp|net|org|to|tv|uk)|(\/.*)$")? "" : "https://www.google.com/search?q="

    ; Attach the prefix and wrap text in quotes.
    ; Characters between quotes are parsed as a single argument for most Windows apps.
    ; NOTE: if you are using an editor with syntax highlighting it might color this part wrong.
    ;   AHK's quoting rules are ... interesting.
    ; '"' is a string containing a quote.
    url :=  '"' . reg . string . '"'

    ; Open Browser
    Run(Browser . ' --new-tab ' . url,, 'Max')
    if WinWait(win,, 3)
        WinActivate(win)
    MinMax := WinGetMinMax(win)
    if (MinMax < 1)
        WinMaximize(win)
}
