#include-once
#include "../imports.au3"

;Run CMD session to send ADB command.
;Output will be retrieved after command has been executed.
Func ADB_Command($sCommand, $sAdbDevice = $g_sAdbDevice, $sAdbPath = $g_sAdbPath)
	Log_Level_Add("ADB_Command")
    Log_Add("ADB command: " & '"' & $sAdbPath & '"' & " -s " & $sAdbDevice & " " & $sCommand, $LOG_DEBUG)

    Local $iPID = Run('"' & $sAdbPath & '"' & " -s " & $sAdbDevice & " " & $sCommand, "", @SW_HIDE, $STDERR_MERGED)
    Local $hTimer = TimerInit()
	Local $sResult ;Holds ADB output
	While ProcessExists($iPID)
		If (_Sleep(100)) Then ExitLoop
		If (TimerDiff($hTimer) > 3000) Then
			$sResult = "Timed out."
			ProcessClose($iPID)
			ExitLoop
		EndIf
	WEnd
	If ($sResult <> "Timed out.") Then $sResult = StdoutRead($iPID)
    StdioClose($iPID)

    If ($sResult <> "") Then Log_Add("ADB output: " & $sResult, $LOG_DEBUG)
    Log_Level_Remove()
    Return $sResult
EndFunc   ;==>ADB_Command

;Run CMD session to send ADB command.
;Output will be retrieved after command has been executed.
Func ADB_Command_Ignore_Timeout($sCommand, $sAdbDevice = $g_sAdbDevice, $sAdbPath = $g_sAdbPath)
	Log_Level_Add("ADB_Command")
    Log_Add("ADB command: " & '"' & $sAdbPath & '"' & " -s " & $sAdbDevice & " " & $sCommand, $LOG_DEBUG)

    Local $iPID = Run('"' & $sAdbPath & '"' & " -s " & $sAdbDevice & " " & $sCommand, "", @SW_HIDE, $STDERR_MERGED)
    Local $hTimer = TimerInit()
	Local $sResult ;Holds ADB output
	While ProcessExists($iPID)
		If (_Sleep(100)) Then ExitLoop
		If (TimerDiff($hTimer) > 20000) Then
			$sResult = "Timed out."
			ProcessClose($iPID)
			ExitLoop
		EndIf
	WEnd
	If ($sResult <> "Timed out.") Then $sResult = StdoutRead($iPID)
    StdioClose($iPID)

    If ($sResult <> "") Then Log_Add("ADB output: " & $sResult, $LOG_DEBUG)
    Log_Level_Remove()
    Return $sResult
EndFunc   ;==>ADB_Command

Func ADB_General_Command($sCommand)
	Log_Level_Add("ADB_General_Command")
    Log_Add("ADB command: " & '"' & $g_sAdbDevice & '"' & " " & $sCommand, $LOG_DEBUG)

    Local $iPID = Run('"' & $g_sAdbDevice & '"' & " " & $sCommand, "", @SW_HIDE, $STDERR_MERGED)
    Local $hTimer = TimerInit()
	Local $sResult ;Holds ADB output
	While ProcessExists($iPID)
		If (_Sleep(100)) Then ExitLoop
		If (TimerDiff($hTimer) > 3000) Then
			$sResult = "Timed out."
			ProcessClose($iPID)
			ExitLoop
		EndIf
	WEnd
	If ($sResult <> "Timed out.") Then $sResult = StdoutRead($iPID)
    StdioClose($iPID)

    If ($sResult <> "") Then Log_Add("ADB output: " & $sResult, $LOG_DEBUG)
    Log_Level_Remove()
    Return $sResult
EndFunc

;Runs ADB Shell session directly and inputs commands individually.
;Commands could be separated by @CRLF.
;Output is automatically parsed to show only output.
;Raw output displays all command inputs from session.
Func ADB_Shell($sCommand, $bOutput = False, $bRawOutput = False, $sAdbDevice = $g_sAdbDevice, $sAdbPath = $g_sAdbPath)
	Log_Level_Add("ADB_Shell")

	;Run shell session
	Local $iPID_ADB = Run('"' & $sAdbPath & '" -s ' & $sAdbDevice & ' shell', "", @SW_HIDE, $STDIN_CHILD + $STDOUT_CHILD)
	StdinWrite($iPID_ADB, $sCommand & @CRLF)
	StdinWrite($iPID_ADB, "exit" & @CRLF)

	;Read output from session.
	Local $sOutput = ""
	If ($bOutput) Then

        ;Reading output from stream.
		Local $hTimer = TimerInit()
		While True 
			$sOutput &= StdoutRead($iPID_ADB)
			If (@error Or _Sleep(0)) Then ExitLoop

			If (TimerDiff($hTimer) > 5000) Then
				$sOutput = "Timed out."
				ExitLoop
			EndIf
		WEnd

		;Parsing output
		If ($sOutput <> "Timed out." And Not($bRawOutput)) Then
			Local $aOutput = StringRegExp($sOutput, "(?s)\n.*?\n.*?\n(.*)\n(?:root@)", $STR_REGEXPARRAYMATCH) ;Process input
			If (IsArray($aOutput)) Then $sOutput = $aOutput[0]
		EndIf

	EndIf

	;Prevent adb process from building up.
	If ($sOutput = "Timed out.") Then
		Log_Add("ADB Process has stopped functioning. Restarting Nox.", $LOG_ERROR)
		If (ProcessExists($iPID_ADB)) Then ProcessClose($iPID_ADB)
		RestartNox()
	EndIf

	Log_Level_Remove()
	Return $sOutput
EndFunc   ;==>ADB_Shell

;Returns working condition of ADB.
Func ADB_isWorking()
	Local $bStatus = (FileExists($g_sAdbPath) = True) And (StringInStr(ADB_Command("get-state"), "error") = False)
	Log_Add("Checking ADB status: " & $bStatus, $LOG_DEBUG)
	$g_bAdbWorking = $bStatus

	Return $bStatus
EndFunc   ;==>ADB_isWorking

;Send ESC through ADB.
Func ADB_SendESC($iCount = 1, $sAdbDevice = $g_sAdbDevice, $sAdbPath = $g_sAdbPath)
	If (Not($g_bAdbWorking)) Then Return 0
	For $i = 0 To $iCount - 1 
		ADB_Command("shell input keyevent ESCAPE")
	Next
	Return 1
EndFunc   ;==>ADB_SendESC

Func ADB_RestartServer()
	ADB_General_Command("kill-server")
	ADB_General_Command("start-server")
EndFunc

Func ADB_GetDevices()
	If (Not($g_bAdbWorking)) Then Return "Adb Not Working"
	Msgbox(0,"Adb Devices", ADB_Command("devices"))
EndFunc

;Converts an array of event, type, code, and value to sendevent long text.
Func ADB_ConvertEvent($sEvent, $aTCV)
	Local $sFinal = ""
	If (Not(IsArray($aTCV))) Then $aTCV = StringSplit($aTCV, ",", $STR_NOCOUNT)

	For $i = 0 To UBound($aTCV) - 1
		Local $aRaw = StringSplit($aTCV[$i], " ", $STR_NOCOUNT)
		Local $sType = $aRaw[0]
		Local $sCode = $aRaw[1]
		Local $sValue = $aRaw[2]

		$sFinal &= ";sendevent " & $sEvent & " " & $sType & " " & $sCode & " " & $sValue
	Next

	Return StringMid($sFinal, 2)
EndFunc   ;==>ADB_ConvertEvent

;Retrieves "Android Input" to be able to use sendevent method.
Func ADB_GetEvent($iTimeout = 500)
	Log_Level_Add("ADB_GetEvent")
	If ($g_sADBMethod <> "sendevent") Then 
		Log_Level_Remove()
		Return ""
	EndIf

	;Capture event list.
	Local $sData = ""
	Local $hTimer = TimerInit()

	$g_bLogEnabled = False
	While ($sData = "" Or $sData = "Timed out.")
		$sData = ADB_Command("shell getevent -p")
		If (TimerDiff($hTimer) > $iTimeout Or _Sleep(100)) Then ExitLoop
	WEnd
	$g_bLogEnabled = True
	
	If (Not(StringInStr($sData , "Android Input")) And Not(StringInStr($sData , "Android_Input"))) Then
		Log_Add("ADB_GetEvent() => Could not find Android Input.", $LOG_ERROR)
		Log_Level_Remove()
		Return ""
	EndIf

	Local $aEvents = StringSplit(StringStripWS($sData, $STR_STRIPSPACES), @CRLF, $STR_NOCOUNT)
	If (IsArray($aEvents)) Then
		For $i = 0 To UBound($aEvents) - 1
			If (StringInStr($aEvents[$i], "Android Input") Or StringInStr($aEvents[$i], "Android_Input")) Then

				Local $aEventNum = StringSplit($aEvents[$i - 1], ":", $STR_NOCOUNT)
				If (IsArray($aEventNum) And UBound($aEventNum) > 1) Then
					Log_Level_Remove()
					Return StringStripWS($aEventNum[1], $STR_STRIPLEADING)
				EndIf

			EndIf
		Next
	Else
		Log_Add("ADB_GetEvent() => Could not get event list.", $LOG_ERROR)
		Log_Level_Remove()
		Return ""
	EndIf

	Log_Add("ADB_GetEvent() => Something went wrong.", $LOG_ERROR)
	Log_Level_Remove()
	Return ""
EndFunc   ;==>ADB_GetEvent