#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=icon.ico
#AutoIt3Wrapper_Outfile=build\current\four-tris-x86.exe
#AutoIt3Wrapper_Outfile_x64=build\current\four-tris-x64.exe
#AutoIt3Wrapper_UseUpx=y
#AutoIt3Wrapper_Compile_Both=y
#AutoIt3Wrapper_UseX64=y
#AutoIt3Wrapper_Res_Description=Fio's tetris client
#AutoIt3Wrapper_Res_Fileversion=1.4.0
#AutoIt3Wrapper_Res_Fileversion_AutoIncrement=p
#AutoIt3Wrapper_Res_LegalCopyright=pls TTC dont sue me
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

#include <WinAPIGDI.au3>
#include <WinAPISys.au3>
#include <WinAPIMisc.au3>
#include <WindowsConstants.au3>
#include <BorderConstants.au3>
#include <FontConstants.au3>
#include <Array.au3>
#include <ScreenCapture.au3>
#include <Color.au3>

#include "lib\Keyboard.au3"
#include "lib\Base64.au3"
#include "lib\Bass.au3"
#include "lib\LZNT.au3"


Opt("TrayIconHide", 1)
FileChangeDir(@ScriptDir)
SRandom(Number(@MSEC&@SEC))

;fixed DPI resizing
DllCall("shcore.dll", "uint", "SetProcessDpiAwareness", "uint", 1)
;auto resource unloading on exit
OnAutoItExitRegister("UnloadResources")


#Region GAME SETTINGS
Global $DEBUG  = 0

Global $GRID_X = IniRead("settings.ini", "OTHER", "CELL_AMOUNT_X", 10)
Global $GRID_Y = IniRead("settings.ini", "OTHER", "CELL_AMOUNT_Y", 20)
Global $GRID_H = 4

;ensure min 4x4 and max 32x32 including hidden lines
If $GRID_X <  4 Then $GRID_X =  4
If $GRID_X > 32 Then $GRID_X = 32
If $GRID_Y <  4 Then $GRID_Y =  4
If $GRID_Y > 28 Then $GRID_Y = 28

Global $GRID  [$GRID_X][$GRID_Y+$GRID_H] ;game grid
Global $HLIGHT[$GRID_X][$GRID_Y+$GRID_H] ;highlights

Global $Cell   = IniRead("settings.ini", "OTHER", "CELL_SIZE", 30) ;game cell size
Global $CellS  = 1  ;game cell style
Global $GridX  = 95 ;game grid position X
Global $GridY  = 75 ;game grid position Y

Global $WTITLE = "four-tris"
Global $WSize[2] = [2 * $GridX + $GRID_X * $Cell, $GridY + $GRID_Y * $Cell + 18]
Global $GBounds  = BoundBox($GridX, $GridY, $GRID_X * $Cell, $GRID_Y * $Cell)

;ensure minimum window sizew
If $WSize[1] < 460 Then $WSize[1] = 480

Global $AlignL = 10
Global $AlignR = 10 + $GridX + $GRID_X * $Cell
Global $AlignT = 10
Global $AlignB = $WSize[1] - 14
Global $AlignC = $WSize[0] / 2

Global $Piece
Global $PieceX
Global $PieceY
Global $PieceA
Global $PieceH = -1

Global $Swapped       = False
Global $InfiniteSwaps = (IniRead("settings.ini", "SETTINGS", "INFINITE_HOLD", False) == True)

Global $AllowedPieces[7] = [0,1,2,3,4,5,6]
Global $Bag
Global $BagType = IniRead("settings.ini", "OTHER", "BAG_TYPE", 0)
Global $BagSeed = Random(0, 65535, 1)

Global $DAS  	= IniRead("settings.ini", "SETTINGS", "DAS", 133)
Global $DAS_CAN =(IniRead("settings.ini", "SETTINGS", "DAS_CANCELLATION", True) == True)
Global $DAS_DIR = ""
Global $ARR     = IniRead("settings.ini", "SETTINGS", "ARR", 0)

Global $GAMEMODE   = 0
Global $Gravity    = 0
Global $Stickyness = 0

Global $GarbageString = IniRead("settings.ini", "SETTINGS", "GARBAGE", "1")
Global $GarbageType   = StringSplit($GarbageString, ",", 2)
Global $GarbageAlternates = True

Global $Damage  = 0 ;damage sent
Global $Lines   = 0 ;lines cleared
Global $Lost    = False ;game has ended
Global $BtB     = False
Global $Perfect = False
Global $ClearCombo = 0
Global $B2BText    = ''
Global $AttackText = ''

Global $tSpin   = False
Global $sMini   = False
Global $lKick   = 0 ;last kick type

Global $ALLOW_DRAWING = 1
Global $EditColor     = 8

Global $DROPFILE[2] = [False,""]

Global $SaveState[1]
Global $UNDO[100][8]
Global $UNDO_INDEX = 0
Global $UNDO_MAX = 0
Global $REDO_MAX = 0

Global $GTimer = TimerInit()
Global $tInput   = 0
Global $tGravity = 0
Global $tSticky  = 0
Global $tARR = 0

#EndRegion GAME SETTINGS
#Region GDI OBJECTS
Global $GUI = GUICreate($WTITLE, $WSize[0], $WSize[1])
_WinAPI_DragAcceptFiles($GUI, True)

Global $CHG = True
Global $ANIMATION_PLAYING = False

Global $GDI = _WinAPI_GetDC($GUI)
Global $BMP = _WinAPI_CreateCompatibleBitmap($GDI, $WSize[0], $WSize[1])
Global $DRW = _WinAPI_CreateCompatibleDC($GDI)
_WinAPI_SelectObject($DRW, $BMP)

Global $Color[11]
Global $Brush[11]

Global $SnapBMP = _WinAPI_LoadImage(0, "snap.bmp", $IMAGE_BITMAP, 0, 0, $LR_LOADFROMFILE+$LR_DEFAULTCOLOR)
Global $BlendDC = _WinAPI_CreateCompatibleDC($GDI)
Global $Blend
Global $Pen

Global $CSKIN = IniRead("settings.ini", "SETTINGS", "SKIN", "DEFAULT")
Global $SKINS = IniReadSectionNames("colors.ini")
SetColors($CSKIN)

;font
Global $Font9  = _CreateFont(14, 200, 'Consolas')
Global $Font10 = _CreateFont(15, 400, 'Consolas')
Global $Font20 = _CreateFont(30, 400, 'Consolas')
Global $Font30 = _CreateFont(52, 400, 'Consolas')
Global $Font50 = _CreateFont(75, 400, 'Consolas')

#EndRegion GDI OBJECTS
#Region SOUND

_BASS_STARTUP ("se\bass"& (@AutoItX64 ? "x64" : "x86") &".dll")
_BASS_Init    (0, -1, 44100, $GUI, "")

Global $VOLUME = IniRead("settings.ini", "SETTINGS", "VOLUME", 20)
Global $Sound[11][3]

$Sound[0][0] = 'se\se_move.wav'
$Sound[1][0] = 'se\se_rotate.wav'
$Sound[2][0] = 'se\se_hdrop.wav'
$Sound[3][0] = 'se\se_hold.wav'
$Sound[4][0] = 'se\se_spin.wav'
$Sound[5][0] = 'se\se_clear_line.wav'
$Sound[6][0] = 'se\se_clear_tetris.wav'
$Sound[7][0] = 'se\se_clear_spin.wav'
$Sound[8][0] = 'se\se_clear_btb.wav'
$Sound[9][0] = 'se\se_down.wav'
$Sound[10][0]= 'se\se_lose.wav'

For $i = 0 To UBound($Sound) - 1
	$Sound[$i][1] = _BASS_SampleLoad(0, $Sound[$i][0], 0, 0, 6, $BASS_UNICODE)
	$Sound[$i][2] = _BASS_SampleGetChannel($Sound[$i][1], 1)
Next

SoundSetWaveVolume($VOLUME)

#EndRegion
#Region KEYBINDS
Global Enum $KEYCODE, $KEYACTION, $KEYSTATE, $KEYTIME
Global		$KEYBINDS[14][4]
Global		$HOTKEYS [ 5][4]

;functions
$KEYBINDS[0 ][1] = "MoveL"
$KEYBINDS[1 ][1] = "MoveR"
$KEYBINDS[2 ][1] = "MoveD"
$KEYBINDS[3 ][1] = "Drop"
$KEYBINDS[4 ][1] = "PieceHold"
$KEYBINDS[5 ][1] = "RotateCCW"
$KEYBINDS[6 ][1] = "RotateCW"
$KEYBINDS[7 ][1] = "Rotate180"
$KEYBINDS[8 ][1] = "clear_board"
$KEYBINDS[9 ][1] = "GridSpawnGarbage"
$KEYBINDS[10][1] = "GridSpawn4W"
;$KEYBINDS[11][1] = "LoadState"
;$KEYBINDS[12][1] = "SaveState"
;$KEYBINDS[13][1] = @Compiled ? "" : "MoveU"

$HOTKEYS [0 ][1] = "Undo"
$HOTKEYS [1 ][1] = "Redo"
$HOTKEYS [2 ][1] = "Copy"
$HOTKEYS [3 ][1] = "Paste"
$HOTKEYS [4 ][1] = "SetQueue"
;$HOTKEYS [5 ][1] = "Settings"

;keybind
$KEYBINDS[0 ][0] = IniRead("settings.ini", "SETTINGS", "KB0",  37) ;LEFT
$KEYBINDS[1 ][0] = IniRead("settings.ini", "SETTINGS", "KB1",  39) ;RIGHT
$KEYBINDS[2 ][0] = IniRead("settings.ini", "SETTINGS", "KB2",  40) ;DOWN
$KEYBINDS[3 ][0] = IniRead("settings.ini", "SETTINGS", "KB3",  38) ;UP
$KEYBINDS[4 ][0] = IniRead("settings.ini", "SETTINGS", "KB4",  67) ;C
$KEYBINDS[5 ][0] = IniRead("settings.ini", "SETTINGS", "KB5",  90) ;Z
$KEYBINDS[6 ][0] = IniRead("settings.ini", "SETTINGS", "KB6",  88) ;X
$KEYBINDS[7 ][0] = IniRead("settings.ini", "SETTINGS", "KB7", 160) ;LSHIFT
$KEYBINDS[8 ][0] = IniRead("settings.ini", "SETTINGS", "KB8", 115) ;F4
$KEYBINDS[9 ][0] = IniRead("settings.ini", "SETTINGS", "KB11",  71) ;G
$KEYBINDS[10][0] = IniRead("settings.ini", "SETTINGS", "KB12",  52) ;4
$KEYBINDS[11][0] = IniRead("settings.ini", "SETTINGS", "KB15", 118) ;F7
$KEYBINDS[12][0] = IniRead("settings.ini", "SETTINGS", "KB16", 119) ;F8
$KEYBINDS[13][0] = IniRead("settings.ini", "SETTINGS", "KB17",   8) ;BS

$HOTKEYS [0 ][0] = "^z"
$HOTKEYS [1 ][0] = "^y"
$HOTKEYS [2 ][0] = "^c"
$HOTKEYS [3 ][0] = "^v"
$HOTKEYS [4 ][0] = "q"
;$HOTKEYS [5 ][0] = "^s" ;settings

Global $KEYCALL   = ""
Global $KEYACTIVE = False

Global $KEYPROC = DllCallbackRegister("KeyProc", "long", "int;wparam;lparam")
Global $MODULE  = _WinAPI_GetModuleHandle(0)
Global $KEYHOOK = _WinAPI_SetWindowsHookEx($WH_KEYBOARD_LL, DllCallbackGetPtr($KEYPROC), $MODULE)
Global $LASTKEYPRESSED = 0
#EndRegion
#Region BUTTONS
;standard buttons
Global Enum $MODEBUTTON, $SETTBUTTON, $SAVEBUTTON, _
			$HOLDBUTTON, $HOLDCHECK,  _
			$NEXTBUTTON, _
			$UNDOBUTTON, $REDOBUTTON, _
			$SNAPBUTTON

Global $BUTTONS[9][3]
Global $BUTTONTEXT[3] = ["TRAINING  MODE  ", "        SETTINGS", "F8:      SAVESTATE"]

$BUTTONS[$MODEBUTTON][2] = BoundBox($AlignL, $AlignB - 120, 75, 35)
$BUTTONS[$SETTBUTTON][2] = BoundBox($AlignL, $AlignB -  80, 75, 35)
$BUTTONS[$SAVEBUTTON][2] = BoundBox($AlignL, $AlignB -  40, 75, 35)

;special buttons
$BUTTONS[$HOLDBUTTON][2] = BoundBox($AlignL,      $AlignT +  90,  75,  80)
$BUTTONS[$HOLDCHECK ][2] = BoundBox($AlignL,      $AlignT + 172,  75,  18)
$BUTTONS[$NEXTBUTTON][2] = BoundBox($AlignR,      $AlignT,        75, 240)
$BUTTONS[$UNDOBUTTON][2] = BoundBox($AlignR,      $AlignT + 250,  35,  35)
$BUTTONS[$REDOBUTTON][2] = BoundBox($AlignR + 40, $AlignT + 250,  35,  35)
$BUTTONS[$SNAPBUTTON][2] = BoundBox($AlignR,      $AlignB -  60,  75,  55)

;paint buttons
Global $PAINT[8][3]

$PAINT[0][2] = BoundBox($AlignR + 10, $AlignT + 330, 15, 15)
$PAINT[1][2] = BoundBox($AlignR + 30, $AlignT + 330, 15, 15)
$PAINT[2][2] = BoundBox($AlignR + 50, $AlignT + 330, 15, 15)
$PAINT[3][2] = BoundBox($AlignR + 10, $AlignT + 350, 15, 15)
$PAINT[4][2] = BoundBox($AlignR + 30, $AlignT + 350, 15, 15)
$PAINT[5][2] = BoundBox($AlignR + 50, $AlignT + 350, 15, 15)
$PAINT[6][2] = BoundBox($AlignR + 10, $AlignT + 370, 15, 15)
$PAINT[7][2] = BoundBox($AlignR + 30, $AlignT + 370, 15, 15)

#EndRegion BUTTONS
#Region SETTINGS
Global $SEPARATORS[3][2] = [["COLORS", 10], ["KEYBINDS", 100], ["SOUND", 350]]
Global $SETTINGS[12][6]
Global $SLIDER[1][6]
Local  $Y

;bounds
$Y = 100+37+5
$SETTINGS[0 ][2] = BoundBox($AlignC-92, $Y, 90,35)
$SETTINGS[1 ][2] = BoundBox($AlignC+2,  $Y, 90,35)
$SETTINGS[2 ][2] = BoundBox($AlignC-140,$Y+40, 90,35)
$SETTINGS[3 ][2] = BoundBox($AlignC-45, $Y+40, 90,35)
$SETTINGS[4 ][2] = BoundBox($AlignC+50, $Y+40, 90,35)
$SETTINGS[5 ][2] = BoundBox($AlignC-45, $Y+80, 90,35)
$SETTINGS[6 ][2] = BoundBox($AlignC-92, $Y+120, 90,35)
$SETTINGS[7 ][2] = BoundBox($AlignC+2,  $Y+120, 90,35)
$SETTINGS[8 ][2] = BoundBox($AlignC-45, $Y+160, 90,35)

$Y = 10+37+5
$SETTINGS[9 ][2] = BoundBox($AlignC-85, $Y, 35,35)
$SETTINGS[10][2] = BoundBox($AlignC-45, $Y, 90,35)
$SETTINGS[11][2] = BoundBox($AlignC+50, $Y, 35,35)

$Y = 350+37+5
$SLIDER  [0 ][2] = BoundBox($AlignC-85, $Y, 170,35)

;text
$SETTINGS[0 ][3] = "MOVE  LEFT"
$SETTINGS[1 ][3] = "MOVE RIGHT"
$SETTINGS[2 ][3] = "ROTATE CCW"
$SETTINGS[3 ][3] = "ROTATE 180"
$SETTINGS[4 ][3] = "ROTATE  CW"
$SETTINGS[5 ][3] = "HOLD PIECE"
$SETTINGS[6 ][3] = "SOFT  DROP"
$SETTINGS[7 ][3] = "HARD  DROP"
$SETTINGS[8 ][3] = "RESET GAME"

$SETTINGS[9 ][3] = "<"
$SETTINGS[10][3] = "   SKIN   "
$SETTINGS[11][3] = ">"

$SLIDER  [0 ][3] = "  VOLUME  "

;current setting
$SETTINGS[0 ][4] = vKey($KEYBINDS[0][0])
$SETTINGS[1 ][4] = vKey($KEYBINDS[1][0])
$SETTINGS[2 ][4] = vKey($KEYBINDS[5][0])
$SETTINGS[3 ][4] = vKey($KEYBINDS[7][0])
$SETTINGS[4 ][4] = vKey($KEYBINDS[6][0])
$SETTINGS[5 ][4] = vKey($KEYBINDS[4][0])
$SETTINGS[6 ][4] = vKey($KEYBINDS[2][0])
$SETTINGS[7 ][4] = vKey($KEYBINDS[3][0])
$SETTINGS[8 ][4] = vKey($KEYBINDS[8][0])

$SETTINGS[9 ][4] = ""
$SETTINGS[10][4] = $CSKIN
$SETTINGS[11][4] = ""

$SLIDER  [0 ][4] = $VOLUME

;action
$SETTINGS[0 ][5] = "SetKeybind(0,0)"
$SETTINGS[1 ][5] = "SetKeybind(1,1)"
$SETTINGS[2 ][5] = "SetKeybind(5,2)"
$SETTINGS[3 ][5] = "SetKeybind(7,3)"
$SETTINGS[4 ][5] = "SetKeybind(6,4)"
$SETTINGS[5 ][5] = "SetKeybind(4,5)"
$SETTINGS[6 ][5] = "SetKeybind(2,6)"
$SETTINGS[7 ][5] = "SetKeybind(3,7)"
$SETTINGS[8 ][5] = "SetKeybind(8,8)"

$SETTINGS[9 ][5] = "SetSkin(-1)"
$SETTINGS[10][5] = ""
$SETTINGS[11][5] = "SetSkin(+1)"

$SLIDER  [0 ][5] = "SetVolume()"

#EndRegion

clear_board()

GUIRegisterMsg($WM_PAINT, "WMPaint")
GUIRegisterMsg($WM_MOVE,  "WMPaint")
GUIRegisterMsg($WM_DROPFILES, "WMDropFiles")
GUISetState()

While 1
	Main()
	DrawGame($DRW)

	While TimerDiff($GTimer) > $tInput
		GameInput()
		$tInput += 17
	WEnd

	While TimerDiff($GTimer) > $tGravity
		$tGravity += 1000 / $Gravity
		If Not Tick() Then
			If $tGravity < TimerDiff($GTimer) Then $tGravity = TimerDiff($GTimer)
			ExitLoop
		EndIf
	WEnd

	If $DROPFILE[0] Then
		$DROPFILE[0] = False
		FileProc($DROPFILE[1])
	EndIf
WEnd
Func Main()
	SetHotkeys()

	Local $msg
	Do
		$msg = GUIGetMsg()
		If $msg = -3 Then Exit
		If $msg = -5 Then $CHG = True ;minimize

		$m = GUIGetCursorInfo($GUI)
		If Not IsArray($m) Then ContinueLoop

		For $i = 0 To UBound($BUTTONS) - 1
			$BUTTONS[$i][0] = Bounds($m, $BUTTONS[$i][2])

			If $BUTTONS[$i][0] <> $BUTTONS[$i][1] Then
				$BUTTONS[$i][1] = $BUTTONS[$i][0]
				$CHG = True
			EndIf
		Next
		For $i = 0 To UBound($PAINT) - 1
			$PAINT[$i][0] = Bounds($m, $PAINT[$i][2])

			If $PAINT[$i][0] <> $PAINT[$i][1] Then
				$PAINT[$i][1] = $PAINT[$i][0]
				$CHG = True
			EndIf
		Next

		If $msg = -8 Then
			If $BUTTONS[$MODEBUTTON][0] Then SwitchMode()
			If $BUTTONS[$SETTBUTTON][0] Then Settings()
 			If $BUTTONS[$SAVEBUTTON][0] Then SaveState()
;~ 			If $BUTTONS[$LOADBUTTON][0] Then LoadState()
			If $BUTTONS[$SNAPBUTTON][0] Then SnapBoard()
			If $BUTTONS[$NEXTBUTTON][0] Then SetQueue()
			If $BUTTONS[$HOLDBUTTON][0] Then SetHold()
			If $BUTTONS[$HOLDCHECK ][0] Then SetUnlimitedHold()
			If $BUTTONS[$UNDOBUTTON][0] Then Undo()
			If $BUTTONS[$REDOBUTTON][0] Then Redo()

			For $i = 0 To UBound($PAINT) - 1
				If $PAINT[$i][0] Then
					$EditColor = $i + 1
					$CHG = True
				EndIf
			Next
		EndIf

		If ($msg = -7 Or $msg = -9) And $ALLOW_DRAWING Then
			If Bounds($m, $GBounds) Then EditBoard($msg = -9 ? 0 : $EditColor)
		EndIf

	Until $msg = 0
EndFunc   ;==>Main

Func SetHotkeys($Flag = 0)
	$KEYACTIVE = WinActive($GUI)

	If $Flag Or Not $KEYACTIVE Then
		For $i = 0 To UBound($HOTKEYS) - 1
			HotKeySet($HOTKEYS[$i][0])
		Next
	Else
		For $i = 0 To UBound($HOTKEYS) - 1
			HotKeySet($HOTKEYS[$i][0], $HOTKEYS[$i][1])
		Next
	EndIf
EndFunc   ;==>SetHotkeys

Func KeyProc($nCode, $wParam, $lParam)
	If $nCode >= 0 And $KEYACTIVE Then
		Local $tKEYHOOKS = DllStructCreate($tagKBDLLHOOKSTRUCT, $lParam)
		Local $vkCode    = DllStructGetData($tKEYHOOKS, "vkCode")
		Local $msgTime   = DllStructGetData($tKEYHOOKS, "time")
		Local $CTRL      = BitAND(_WinAPI_GetAsyncKeyState(0x11), 0x8000) ;ctrl

		If $wParam = $WM_KEYDOWN Then
			$LASTKEYPRESSED = $vkCode
			For $i = 0 To UBound($KEYBINDS) - 1
				If Not $KEYBINDS[$i][$KEYSTATE] And $KEYBINDS[$i][$KEYCODE] = $vkCode Then
					$KEYBINDS[$i][$KEYSTATE] = True
					$KEYBINDS[$i][$KEYTIME ] = $msgTime
					$KEYCALL = $KEYBINDS[$i][$KEYACTION]
					If Not $CTRL Then Call($KEYCALL)
				EndIf
			Next
		ElseIf $wParam = $WM_KEYUP Then
			For $i = 0 To UBound($KEYBINDS) - 1
				If $KEYBINDS[$i][$KEYSTATE] And $KEYBINDS[$i][$KEYCODE] = $vkCode Then
					$KEYBINDS[$i][$KEYSTATE] = False
					$KEYBINDS[$i][$KEYTIME ] = $msgTime
				EndIf
			Next
		EndIf
	EndIf
	Return _WinAPI_CallNextHookEx($KEYHOOK, $nCode, $wParam, $lParam)
EndFunc
Func FileProc($FileName)
	Local $Image, $Bitmap

	_GDIPlus_Startup()

	$Image  = _GDIPlus_ImageLoadFromFile($FileName)
	$Bitmap = _GDIPlus_BitmapCreateHBITMAPFromBitmap($Image)
	_GDIPlus_ImageDispose($Image)

	_GDIPlus_Shutdown()

	If $Bitmap <> 0 Then FillBoardFromBitmap($Bitmap)

	_WinAPI_DeleteObject($Bitmap)
EndFunc
Func WMPaint($hWnd, $iMsg, $wParam, $lParam)
	$CHG = True
EndFunc
Func WMDropFiles($hWnd, $iMsg, $wParam, $lParam)
	Local $Drop

	$Drop = _WinAPI_DragQueryFileEx($wParam, 1)
		    _WinAPI_DragFinish($wParam)

	$DROPFILE[0] = True
	$DROPFILE[1] = $Drop[1]
EndFunc


Func EditBoard($c = 0)
	Local $cm, $om, $msg
	Local $m[2] = [-1,-1]
	Local $o[2] = [-1,-1]

	Local $SHIFT = BitAND(_WinAPI_GetAsyncKeyState(0x10), 0x8000) ;shift ?
	Local $CTRL  = BitAND(_WinAPI_GetAsyncKeyState(0x11), 0x8000) ;ctrl

	Local $StrokeCoord[4][2]
	Local $Stroke = 0

	NewUndo()
	$cm = GUIGetCursorInfo($GUI)

	Do
		GUIGetMsg() ;releases cpu cycles
		$om = $cm
		$cm = GUIGetCursorInfo($GUI)

		For $k = 1 To 7 ;to avoid sparse dots
			$m[0] = $om[0] + ($cm[0]-$om[0]) * $k/7
			$m[1] = $om[1] + ($cm[1]-$om[1]) * $k/7

			$m[0] = Floor(($m[0] - $GridX) / $Cell)
			$m[1] = Floor(($m[1] - $GridY) / $Cell) + $GRID_H

			If $m[0] <> $o[0] Or $m[1] <> $o[1] Then
				$o[0] = $m[0]
				$o[1] = $m[1]

				If BlockInBounds($GRID, $m[0], $m[1]) Then

					If $CTRL Then
						For $i = 0 To UBound($GRID) - 1
							$GRID[$i][$m[1]] = $c
							If $m[0] = $i Then $GRID[$i][$m[1]] = 0
						Next
						$CHG = True

					ElseIf $SHIFT Then
						$c = $c <> 0 ;quantizes to 0-1

						If $HLIGHT[$m[0]][$m[1]] <> $c Then
							$HLIGHT[$m[0]][$m[1]] = $c
							$CHG = True
						EndIf

					Else
						If $GRID[$m[0]][$m[1]] <> $c Then
							$GRID[$m[0]][$m[1]] = $c
							$CHG = True

							If $Stroke < 4 Then
								$StrokeCoord[$Stroke][0] = $m[0]
								$StrokeCoord[$Stroke][1] = $m[1]
							EndIf
							$Stroke += 1

							If $c = 8 Then AutoColor($m[0],$m[1], $Stroke, $StrokeCoord)
							If $c = 0 Then
								AutoColor($m[0]-1, $m[1])
								AutoColor($m[0]+1, $m[1])
								AutoColor($m[0], $m[1]-1)
								AutoColor($m[0], $m[1]+1)
							EndIf
						EndIf
					EndIf
				EndIf
			EndIf
		Next

		DrawGame($DRW)

	Until Not ($cm[2] Or $cm[3])

	;flushes remaining messages that could trigger other buttons
	While GUIGetMsg()
	WEnd
EndFunc
Func AutoColor($X, $Y, $Stroke = 0, $StrokeCoord = 0)

	If $Stroke < 4 Then
		Local $Mem[UBound($GRID)][UBound($GRID, 2)]

		Local $Q[40] = [1, __Pair($X, $Y)]
		Local $Coord[5][2]

		Local $Count = 0

		While $Q[0] > 0 And $Count < 5
			$Pair = $Q[1]

			If BlockInBounds($GRID, $Pair[0], $Pair[1]) And _
			   $GRID[$Pair[0]][$Pair[1]] = 8 And _
			   $Mem [$Pair[0]][$Pair[1]] = 0 Then

				$Coord[$Count][0] = $Pair[0]
				$Coord[$Count][1] = $Pair[1]
				$Count += 1

				$Mem[$Pair[0]][$Pair[1]] = 1
				$Q[$Q[0]+1] = __Pair($Pair[0]-1, $Pair[1])
				$Q[$Q[0]+2] = __Pair($Pair[0]+1, $Pair[1])
				$Q[$Q[0]+3] = __Pair($Pair[0], $Pair[1]-1)
				$Q[$Q[0]+4] = __Pair($Pair[0], $Pair[1]+1)
				$Q[0] += 4
			EndIf

			;pop element from queue
			$Q[0] -= 1
			For $i = 1 To $Q[0]
				$Q[$i] = $Q[$i+1]
			Next
		WEnd

		If $Count = 4 Then
			Local $Shape, $Piece
			ReDim $Coord[4][2]

			$Shape = ShapeFromCoords($Coord)
			$Piece = PieceFromShape($Shape)
			Recolor($Coord, $Piece+1)
		EndIf

	ElseIf $Stroke = 4 Then
		Local $Shape, $Piece

		$Shape = ShapeFromCoords($StrokeCoord)
		$Piece = PieceFromShape($Shape)
		Recolor($StrokeCoord, $Piece+1)

	ElseIf $Stroke = 5 Then
		Recolor($StrokeCoord, 8)
	EndIf
EndFunc
Func Recolor($Coord, $c)
	$CHG = True
	For $i = 0 To UBound($Coord) - 1
		$GRID[$Coord[$i][0]][$Coord[$i][1]] = $c
	Next
EndFunc

Func SwitchMode()
	SetMode(Mod($GAMEMODE+1, 4))
EndFunc
Func SetMode($Mode)
	$GAMEMODE = $Mode
	Switch $GAMEMODE
		Case 0 ;training
			$Gravity = 0
			$BUTTONTEXT[$MODEBUTTON] = "TRAINING  MODE  "
		Case 1 ;cheese race
			$BUTTONTEXT[$MODEBUTTON] = " CHEESE   MODE  "
		Case 2 ;4wide
			$BUTTONTEXT[$MODEBUTTON] = "  FOUR    MODE  "
		Case 3 ;master mode
			$BUTTONTEXT[$MODEBUTTON] = " MASTER   MODE  "
			$Gravity = 1000
	EndSwitch
	clear_board()
EndFunc

Func Settings()
	Local $BMP = _WinAPI_CreateCompatibleBitmap($GDI, $WSize[0], $WSize[1])
	Local $DRW = _WinAPI_CreateCompatibleDC($GDI)
	_WinAPI_SelectObject($DRW, $BMP)

	$CHG = True
	DrawSettings($DRW, 0)
	DrawTransition($DRW, 150)
	$CHG = True

	SetHotkeys(1)
	$KEYACTIVE = False

	Local $msg, $m
	While True
		$msg = GUIGetMsg()
		If $msg = -3 Then ExitLoop
		If $msg = -5 Then $CHG = True ;minimize

		$m = GUIGetCursorInfo()
		If Not IsArray($m) Then ContinueLoop

		For $i = 0 To UBound($SETTINGS) - 1
			$SETTINGS[$i][0] = Bounds($m, $SETTINGS[$i][2])

			If $SETTINGS[$i][0] <> $SETTINGS[$i][1] Then
				$SETTINGS[$i][1] = $SETTINGS[$i][0]
				$CHG = True
			EndIf
		Next

		$SLIDER[0][0] = Bounds($m, $SLIDER[0][2])
		If $SLIDER[0][0] <> $SLIDER[0][1] Then
			$SLIDER[0][1] = $SLIDER[0][0]
			$CHG = True
		EndIf

		If $msg = -7 Then
			If $SLIDER[0][0] Then
				Execute($SLIDER[0][5])
				$CHG = True
			EndIf
		EndIf

		If $msg = -8 Then
			For $i = 0 To UBound($SETTINGS) - 1
				If $SETTINGS[$i][0] Then
					Execute($SETTINGS[$i][5])
					$CHG = True
				EndIf
			Next
		EndIf

		DrawSettings($DRW)
	WEnd

	$CHG = True
	DrawGame($DRW, 0)
	DrawTransition($DRW, 150)
	$CHG = True

	_WinAPI_DeleteDC($GDI)
	_WinAPI_DeleteObject($BMP)
EndFunc
Func SetKeybind($KB, $STT)
	DrawKeyCapture($STT)

	$KEYACTIVE = True
	$LASTKEYPRESSED = 27 ;esc key
	While $LASTKEYPRESSED = 27
		If GUIGetMsg() = -3 Then Return 0
	WEnd

	$SETTINGS[$STT][4]       = vKey($LASTKEYPRESSED)
	$KEYBINDS[$KB][$KEYCODE] = $LASTKEYPRESSED
	$KEYACTIVE = False

	ConsoleWrite($KEYBINDS[$KB][$KEYCODE]&@LF)

	IniWrite("settings.ini","SETTINGS","KB"&$KB,$LASTKEYPRESSED)
EndFunc
Func SetSkin($D)
	Local $i
	For $i = 1 To UBound($SKINS) - 1
		If $CSKIN = $SKINS[$i] Then ExitLoop
	Next

	$i += $D
	If $i < 1 		  Then $i = $SKINS[0]
	If $i > $SKINS[0] Then $i = 1

	$CSKIN           = $SKINS[$i]
	$SETTINGS[10][4] = $SKINS[$i]

	IniWrite("settings.ini","SETTINGS","SKIN",$CSKIN)

	SetColors($CSKIN)
EndFunc
Func SetColors($ColorSet)
	$Color[0 ] = IniRead("colors.ini", $ColorSet, "B", 0x000000)
	$Color[1 ] = IniRead("colors.ini", $ColorSet, "I", 0x00D0FF)
	$Color[2 ] = IniRead("colors.ini", $ColorSet, "J", 0x4080FF)
	$Color[3 ] = IniRead("colors.ini", $ColorSet, "S", 0x40D040)
	$Color[4 ] = IniRead("colors.ini", $ColorSet, "O", 0xFFE020)
	$Color[5 ] = IniRead("colors.ini", $ColorSet, "Z", 0xFF4020)
	$Color[6 ] = IniRead("colors.ini", $ColorSet, "L", 0xFF8020)
	$Color[7 ] = IniRead("colors.ini", $ColorSet, "T", 0xA040F0)
	$Color[8 ] = IniRead("colors.ini", $ColorSet, "G", 0xCCCCCC)
	$Color[9 ] = IniRead("colors.ini", $ColorSet, "F", 0x222222)
	$Color[10] = IniRead("colors.ini", $ColorSet, "X", 0xFFFFFF)
	$CellS = IniRead("colors.ini", $ColorSet, "STYLE", 1)
	If $CellS > 0 Then $CellS = 1
	If $CellS < 0 Then $CellS = 0

	For $i = 0 To UBound($Brush) - 1
		_WinAPI_DeleteObject($Brush[$i])
		$Color[$i] = _ColorSetCOLORREF(_ColorGetRGB($Color[$i]))
		$Brush[$i] = _WinAPI_CreateSolidBrush($Color[$i])
	Next

	_WinAPI_DeleteObject($Pen)
	_WinAPI_DeleteObject($Blend)

	$Pen   = _WinAPI_CreatePen($PS_SOLID, 2, $Color[10])
	$Blend = _WinAPI_CreateSolidBitmap($GUI, $Color[0], 256, 256)

	_WinAPI_SelectObject($BlendDC, $Blend)
EndFunc
Func SetVolume()
	Local $m
	Local $b = $SLIDER[0][2]

	Do
		GUIGetMsg()
		$m = GUIGetCursorInfo($GUI)
		$m[0] -= $b[0]

		If $m[0] < 0 Then $m[0] = 0
		If $m[0] > $b[2] Then $m[0] = $b[2]

		$VOLUME = Int($m[0] / $b[2] * 100)
		$SLIDER[0][4] = $VOLUME

		DrawVolume($GDI)
	Until Not ($m[2] Or $m[3])

	$CHG = True
	SoundSetWaveVolume($VOLUME)
	IniWrite("settings.ini", "SETTINGS", "VOLUME", $VOLUME)
EndFunc


Func DrawGame($DRW, $Render = True)
	If Not $ANIMATION_PLAYING And Not $CHG Then Return 0
	$CHG = False

	DrawGrid($DRW)
	DrawPiece($DRW)
	DrawGuide($DRW)
	DrawHighlight($DRW)

	DrawScore($DRW)
	DrawNext($DRW)
	DrawHold($DRW)

	DrawSnapButton($DRW)
	DrawPaintButtons($DRW)
	DrawUndoButton($DRW)
	DrawButtons($DRW)

	DrawCheckbox($DRW)
	DrawAttack($DRW)
	DrawCombo($DRW)

	DrawLose($DRW)
	DrawPerfect($DRW)
	DrawComment($DRW)

	If $Render Then _WinAPI_BitBlt($GDI, 0, 0, $WSize[0], $WSize[1], $DRW, 0, 0, $SRCCOPY)
EndFunc   ;==>Draw
Func DrawGrid($DRW)
	_WinAPI_FillRect($DRW, Rect(0, 0, $WSize[0], $WSize[1]), $Brush[9])

	Local $i, $j
	For $i = 0 To UBound($GRID, 1) - 1
		For $j = $GRID_H-2 To $GRID_H
			If $GRID[$i][$j] <> 0 Then
				_WinAPI_FillRect($DRW, Rect($GridX + $i * $Cell, $GridY + ($j-$GRID_H) * $Cell, $Cell-$CellS, $Cell-$CellS), $Brush[$GRID[$i][$j]])
			EndIf
		Next
		For $j = $GRID_H To UBound($GRID, 2) - 1
			_WinAPI_FillRect($DRW, Rect($GridX + $i * $Cell, $GridY + ($j-$GRID_H) * $Cell, $Cell-$CellS, $Cell-$CellS), $Brush[$GRID[$i][$j]])
		Next
	Next
EndFunc   ;==>DrawGrid
Func DrawPiece($DRW)
	Local $Shape = PieceGetShape($Piece, $PieceA)
	Local $X = $PieceX
	Local $Y = $PieceY

	Local $i, $j
	For $i = 0 To UBound($Shape, 1) - 1
		For $j = 0 To UBound($Shape, 2) - 1
			If $Shape[$i][$j] Then
				_WinAPI_FillRect($DRW, _
					Rect($GridX + ($X + $i) * $Cell, $GridY + ($Y-$GRID_H + $j) * $Cell, $Cell-$CellS, $Cell-$CellS), _
					$Brush[$Piece + 1])
			EndIf
		Next
	Next
EndFunc   ;==>DrawPiece
Func DrawGuide($DRW)
	Local $Shape = PieceGetShape($Piece, $PieceA)
	Local $X = $PieceX
	Local $Y = $PieceY

	Do
		$Y += 1
	Until Not PieceFits($Piece, $PieceA, $PieceX, $Y)
	$Y -= 1

	Local $i, $j
	For $i = 0 To UBound($Shape, 1) - 1
		For $j = 0 To UBound($Shape, 2) - 1
			If $Shape[$i][$j] Then
				_WinAPI_FrameRect($DRW, _
					Rect(2 + $GridX + ($X + $i) * $Cell, 2 + $GridY + ($Y-$GRID_H + $j) * $Cell, $Cell - 6, $Cell - 6), _
					$Brush[$Piece + 1])
			EndIf
		Next
	Next
EndFunc   ;==>DrawGuide
Func DrawHighlight($DRW)
	Local $i, $j
	Local $Flag

	For $i = 0 To UBound($HLIGHT, 1) - 1
		For $j = $GRID_H To UBound($HLIGHT, 2) - 1

			If Not $HLIGHT[$i][$j] Then ContinueLoop

			$Flag = $BF_MONO;$BF_MIDDLE
			If Not BlockIsBlock($HLIGHT, $i-1, $j) Then $Flag = BitOR($Flag, $BF_LEFT)
			If Not BlockIsBlock($HLIGHT, $i+1, $j) Then $Flag = BitOR($Flag, $BF_RIGHT)
			If Not BlockIsBlock($HLIGHT, $i, $j-1) Then $Flag = BitOR($Flag, $BF_TOP)
			If Not BlockIsBlock($HLIGHT, $i, $j+1) Then $Flag = BitOR($Flag, $BF_BOTTOM)

			_WinAPI_DrawEdge($DRW, Rect($GridX + $i * $Cell, $GridY + ($j-$GRID_H) * $Cell, $Cell, $Cell), $EDGE_ETCHED, $Flag)
		Next
	Next
EndFunc
Func DrawScore($DRW)
	Local $X

	$X = $AlignL

	_WinAPI_FillRect($DRW, Rect($X, 10, 75, 80), $Brush[0])

	_WinAPI_SelectObject($DRW, $Font10)
	_WinAPI_SetBkColor  ($DRW, $Color[0])
	_WinAPI_SetTextColor($DRW, $Color[10])

	$X += 2
	_WinAPI_DrawText($DRW, "CLEAR", Rect($X + 10, 20, 55, 15), $DT_LEFT)
	_WinAPI_DrawText($DRW, "SENT",  Rect($X + 10, 50, 55, 15), $DT_LEFT)
	_WinAPI_DrawText($DRW, StringRight("000000" & $Lines,  6), Rect($X + 10, 32, 55, 20), $DT_LEFT)
	_WinAPI_DrawText($DRW, StringRight("000000" & $Damage, 6), Rect($X + 10, 62, 55, 20), $DT_LEFT)
EndFunc   ;==>DrawScore
Func DrawNext($DRW)
	Local $Shape
	Local $Size = 14
	Local $Distance = 3
	Local $B = $BUTTONS[$NEXTBUTTON][2]

	_WinAPI_FillRect($DRW, Rect($B[0], $B[1], $B[2], $B[3]), $Brush[0])
	If $BUTTONS[$NEXTBUTTON][0] Then _WinAPI_FrameRect($DRW, Rect($B[0], $B[1], $B[2], $B[3]), $Brush[10])
	_WinAPI_DrawText($DRW, "NEXT", Rect($B[0] + 12, $B[1] + 10, 55, 20), $DT_LEFT)

	Local $Y = $B[1]
	Local $o
	Local $i, $j, $k
	For $k = 0 To 4
		$Shape = PieceGetShape($Bag[$k], 0)
		$o = 0

		For $i = 0 To UBound($Shape, 1) - 1
			For $j = 0 To UBound($Shape, 2) - 1
				If $Shape[$i][$j] Then
					_WinAPI_FillRect($DRW, Rect($B[0] + 10 + $i * $Size, $Y + 40 + $j * $Size, $Size-$CellS, $Size-$CellS), $Brush[$Bag[$k] + 1])
				EndIf
			Next
		Next

		$Y = $Y + ($Size-1) * $Distance
	Next

EndFunc   ;==>DrawNext
Func DrawHold($DRW)
	Local $Shape = PieceGetShape($PieceH, 0)
	Local $Size = 14
	Local $B = $BUTTONS[$HOLDBUTTON][2]

	_WinAPI_FillRect($DRW, Rect($B[0], $B[1], $B[2], $B[3]), $Brush[0])
	If $BUTTONS[$HOLDBUTTON][0] Then _WinAPI_FrameRect($DRW, Rect($B[0], $B[1], $B[2], $B[3]), $Brush[10])
	_WinAPI_DrawText($DRW, "HOLD", Rect($B[0] + 12, $B[1] + 10, 55, 20), $DT_LEFT)

	Local $i, $j
	For $i = 0 To UBound($Shape, 1) - 1
		For $j = 0 To UBound($Shape, 2) - 1
			If $Shape[$i][$j] Then
				_WinAPI_FillRect($DRW, Rect($B[0] + 10 + $i * $Size, $B[1] + 35 + $j * $Size, $Size-$CellS, $Size-$CellS), $Brush[$PieceH + 1])
			EndIf
		Next
	Next
	If $Swapped Then _WinAPI_AlphaBlend($DRW, $B[0], $B[1], $B[2], $B[3], $BlendDC, 0, 0, $B[2], $B[3], 128)
EndFunc   ;==>DrawHold
Func DrawButtons($DRW)
	Local $B, $X

	_WinAPI_SelectObject($DRW, $Font9)
	_WinAPI_SetBkColor  ($DRW, $Color[0])
	_WinAPI_SetTextColor($DRW, $Color[10])

	For $i = 0 To UBound($BUTTONTEXT) - 1
		$B = $BUTTONS[$i][2]

		_WinAPI_FillRect($DRW, Rect($B[0], $B[1], $B[2], $B[3]), $Brush[0])
		If $BUTTONS[$i][0] Then _WinAPI_FrameRect($DRW, Rect($B[0], $B[1], $B[2], $B[3]), $Brush[10])

		$X = Int(StringLen($BUTTONTEXT[$i])/2)

		If Mod($X, 2) Then
			_WinAPI_DrawText($DRW, StringLeft    ($BUTTONTEXT[$i],$X), Rect($B[0]+6, $B[1]+5, 65, 11),  $DT_LEFT)
			_WinAPI_DrawText($DRW, StringTrimLeft($BUTTONTEXT[$i],$X), Rect($B[0]+6, $B[1]+16, 65, 11), $DT_LEFT)
		Else
			_WinAPI_DrawText($DRW, StringLeft    ($BUTTONTEXT[$i],$X), Rect($B[0]+9, $B[1]+5, 65, 11),  $DT_LEFT)
			_WinAPI_DrawText($DRW, StringTrimLeft($BUTTONTEXT[$i],$X), Rect($B[0]+9, $B[1]+16, 65, 11), $DT_LEFT)
		EndIf
	Next
EndFunc
Func DrawSnapButton($DRW)
	Local $B = $BUTTONS[$SNAPBUTTON][2]

	_WinAPI_FillRect($DRW, Rect($B[0], $B[1], $B[2], $B[3]), $Brush[0])
	If $BUTTONS[$SNAPBUTTON][0] Then _WinAPI_FrameRect($DRW, Rect($B[0], $B[1], $B[2], $B[3]), $Brush[10])

	_WinAPI_DrawBitmap($DRW, $B[0] + 8, $B[1] + 7, $SnapBMP, $SRCINVERT)
EndFunc
Func DrawUndoButton($DRW)
	Local $X, $Y

	$X = $AlignR
	$Y = $AlignT + 250

	_WinAPI_FillRect($DRW, Rect($X,    $Y, 35, 35), $Brush[0])
	_WinAPI_FillRect($DRW, Rect($X+40, $Y, 35, 35), $Brush[0])
	If $BUTTONS[$UNDOBUTTON][0] Then _WinAPI_FrameRect($DRW, Rect($X,    $Y, 35, 35), $Brush[10])
	If $BUTTONS[$REDOBUTTON][0] Then _WinAPI_FrameRect($DRW, Rect($X+40, $Y, 35, 35), $Brush[10])

	_WinAPI_SelectObject($DRW, $Pen)

	_WinAPI_DrawLine($DRW, $X+10, $Y+17, $X + 15, $Y+12)
	_WinAPI_DrawLine($DRW, $X+10, $Y+17, $X + 25, $Y+17)
	_WinAPI_DrawLine($DRW, $X+10, $Y+17, $X + 15, $Y+22)

 	$X += 40
	_WinAPI_DrawLine($DRW, $X+20, $Y+12, $X + 25, $Y+17)
	_WinAPI_DrawLine($DRW, $X+10, $Y+17, $X + 25, $Y+17)
	_WinAPI_DrawLine($DRW, $X+20, $Y+22, $X + 25, $Y+17)

	$X -= 40

	If $UNDO_MAX = 0 Then _WinAPI_AlphaBlend($DRW, $X,    $Y, 36, 36, $BlendDC, 0, 0, 36, 36, 128)
	If $REDO_MAX = 0 Then _WinAPI_AlphaBlend($DRW, $X+40, $Y, 36, 36, $BlendDC, 0, 0, 36, 36, 128)
EndFunc
Func DrawPaintButtons($DRW)
	Local $B

	_WinAPI_FillRect($DRW, Rect($AlignR, $AlignT + 295, 75, 100), $Brush[0])
	_WinAPI_DrawText($DRW, "COLOR", Rect($AlignR + 12, $AlignT + 305, 55, 20), $DT_LEFT)

	For $i = 0 To 7
		$B = $PAINT[$i][2]
		_WinAPI_FillRect($DRW, Rect($B[0], $B[1], $B[2], $B[3]), $Brush[$i+1])
	Next
	_WinAPI_AlphaBlend($DRW, $AlignR, $AlignT + 330, 65, 65, $BlendDC, 0, 0, 65, 65, 128)

	For $i = 0 To 7
		$B = $PAINT[$i][2]
		If $PAINT[$i][0] Then _WinAPI_FrameRect($DRW, Rect($B[0], $B[1], $B[2], $B[3]), $Brush[10])
	Next

	$B = $PAINT[$EditColor-1][2]
	_WinAPI_FillRect ($DRW, Rect($B[0], $B[1], $B[2], $B[3]), $Brush[$EditColor])
	_WinAPI_FrameRect($DRW, Rect($B[0]-1, $B[1]-1, $B[2]+2, $B[3]+2), $Brush[10])
EndFunc
Func DrawCheckbox($DRW)
	_WinAPI_SetBkColor  ($DRW, $Color[9])

	$B = $BUTTONS[$HOLDCHECK][2]

	_WinAPI_DrawText($DRW, "INFINITE", Rect($B[0] + 16, $B[1] + 3, 55, 15), $DT_LEFT)
	_WinAPI_FrameRect($DRW, Rect($B[0] + 3, $B[1] + 4, 11, 11), $Brush[8])
	If $InfiniteSwaps = True Then _WinAPI_FillRect($DRW, Rect($B[0] + 5, $B[1] + 6,  7,  7), $Brush[8])
EndFunc
Func DrawAttack($DRW)
	If $AttackText = "" Then Return

	Local $X = 10
	Local $Y = 250
	Local $Text[2] = [StringStripWS(StringLeft($AttackText, 6),7), _
					  StringStripWS(StringTrimLeft($AttackText, 6),7)]

	If $B2BText <> "" Then $Text[0] = "B2B "&$Text[0]

	_WinAPI_DrawText($DRW, $Text[0], Rect($X,$Y,75,30), $DT_CENTER)
	_WinAPI_DrawText($DRW, $Text[1], Rect($X,$Y+11,75,30), $DT_CENTER)
EndFunc
Func DrawCombo($DRW)
	If $ClearCombo < 2 Then Return

	Local $X = 10
	Local $Y = 200

	_WinAPI_SelectObject($DRW, $Font20)
	_WinAPI_DrawText($DRW, "x" & $ClearCombo - 1, Rect($X,$Y+10,75,30), $DT_CENTER)
EndFunc
Func DrawLose($DRW)
	If Not $Lost Then Return

	_WinAPI_SelectObject($DRW, $Font50)
	_WinAPI_SetBkMode($DRW, $TRANSPARENT)
	_WinAPI_SetTextColor($DRW, $Color[0])
	_WinAPI_DrawText($DRW, "TOP OUT", Rect($GBounds[0]+5, $GBounds[1]+$GBounds[3]/2 - 31, $GBounds[2], $GBounds[3]), $DT_CENTER)
	_WinAPI_SetTextColor($DRW, $Color[10])
	_WinAPI_DrawText($DRW, "TOP OUT", Rect($GBounds[0], $GBounds[1]+$GBounds[3]/2 - 36, $GBounds[2], $GBounds[3]), $DT_CENTER)
EndFunc
Func DrawPerfect($DRW)
	If Not $Perfect Then Return

	_WinAPI_SelectObject($DRW, $Font30)
	_WinAPI_SetBkMode($DRW, $TRANSPARENT)
	_WinAPI_SetTextColor($DRW, $Color[6])
	_WinAPI_DrawText($DRW, "PERFECT", Rect($GBounds[0], $GBounds[1]+$GBounds[3]/2-1, $GBounds[2], $GBounds[3]), $DT_CENTER)
	_WinAPI_SelectObject($DRW, $Font50)
	_WinAPI_DrawText($DRW, "CLEAR", Rect($GBounds[0], $GBounds[1]+$GBounds[3]/2+25, $GBounds[2], $GBounds[3]), $DT_CENTER)
EndFunc

Func DrawSettings($DRW, $Render = True)
	If Not $ANIMATION_PLAYING And Not $CHG Then Return 0
	$CHG = False

	_WinAPI_FillRect($DRW, Rect(0, 0, $WSize[0], $WSize[1]), $Brush[0])
	_WinAPI_FillRect($DRW, Rect($WSize[0]/7,0, $WSize[0]*5/7,$WSize[1]), $Brush[9])

	DrawSeparators($DRW)
	DrawSettingButtons($DRW)
	DrawVolume($DRW)
	DrawPieces($DRW)

	If $Render Then _WinAPI_BitBlt($GDI, 0, 0, $WSize[0], $WSize[1], $DRW, 0, 0, $SRCCOPY)
EndFunc
Func DrawSeparators($DRW)
	_WinAPI_SelectObject($DRW, $Font30)
	_WinAPI_SetBkColor  ($DRW, $Color[9])
	_WinAPI_SetTextColor($DRW, $Color[8])

	For $i = 0 To UBound($SEPARATORS) - 1
		_WinAPI_DrawText($DRW, $SEPARATORS[$i][0], Rect($WSize[0]/7, $SEPARATORS[$i][1], 300, 34), $DT_LEFT)
		_WinAPI_FillRect($DRW, 					   Rect($WSize[0]/7, $SEPARATORS[$i][1] + 34, $WSize[0]*5/7, 3), $Brush[0])
	Next
EndFunc
Func DrawSettingButtons($DRW)
	_WinAPI_SelectObject($DRW, $Font9)
	_WinAPI_SetBkColor  ($DRW, $Color[0])

	For $i = 0 To UBound($SETTINGS) - 1
		$B = $SETTINGS[$i][2]

		_WinAPI_FillRect($DRW, Rect($B[0], $B[1], $B[2], $B[3]), $Brush[0])
		If $SETTINGS[$i][0] Then _WinAPI_FrameRect($DRW, Rect($B[0], $B[1], $B[2], $B[3]), $Brush[10])

		_WinAPI_SetTextColor($DRW, $Color[10])
		_WinAPI_DrawText($DRW, $SETTINGS[$i][3], Rect($B[0], $B[1]+5, $B[2], $B[3]/2), $DT_CENTER)

		_WinAPI_SetTextColor($DRW, $Color[5])
		_WinAPI_DrawText($DRW, $SETTINGS[$i][4], Rect($B[0], $B[1]+$B[3]/2, $B[2], $B[3]/2), $DT_CENTER)
	Next
EndFunc
Func DrawVolume($DRW)
	_WinAPI_SelectObject($DRW, $Font9)
	_WinAPI_SetBkColor  ($DRW, $Color[0])

	$B = $SLIDER[0][2]

	_WinAPI_FillRect($DRW, Rect($B[0], $B[1], $B[2], $B[3]), $Brush[0])
	If $SLIDER[0][0] Then _WinAPI_FrameRect($DRW, Rect($B[0], $B[1], $B[2], $B[3]), $Brush[10])

	_WinAPI_SetTextColor($DRW, $Color[10])
	_WinAPI_DrawText($DRW, $SLIDER[0][3], Rect($B[0], $B[1]+5, $B[2], $B[3]/2), $DT_CENTER)

	_WinAPI_SetTextColor($DRW, $Color[5])
	_WinAPI_DrawText($DRW, $SLIDER[0][4], Rect($B[0], $B[1]+$B[3]/2, $B[2], $B[3]/2), $DT_CENTER)

	_WinAPI_FillRect($DRW, Rect($B[0], $B[1]+$B[3], $B[2], 3), $Brush[9])
	_WinAPI_FillRect($DRW, Rect($B[0], $B[1]+$B[3], $VOLUME/100*$B[2], 3), $Brush[5])
EndFunc
Func DrawPieces($DRW)
	Local $X, $Y

	Local $Time = TimerDiff($GTimer)
	Local $Timings[7] = [1130, 0570, 2589, 0900, 0783, 0340, 1309]
	Local $Shape

	$Y = 55
	For $k = 0 To 6
		$Shape = PieceGetShape($k, Mod(Floor($Time/$Timings[$k]), 4))

		For $i = 0 To UBound($Shape, 1) - 1
			For $j = 0 To UBound($Shape, 2) - 1
				If $Shape[$i][$j] Then
					$X = 12
					_WinAPI_FillRect($DRW, Rect($X + $i * 11, $Y + $j * 11, 11-$CellS, 11-$CellS), $Brush[$k+1])
					$X = $WSize[0] - 56
					_WinAPI_FillRect($DRW, Rect($X + $i * 11, $Y + $j * 11, 11-$CellS, 11-$CellS), $Brush[$k+1])
				EndIf
			Next
		Next
		$Y += ($WSize[1]-55)/7
	Next
EndFunc

Func DrawKeyCapture($STT)
	Local $B = $SETTINGS[$STT][2]
	_WinAPI_AlphaBlend($GDI, 0, 0, $B[0], $WSize[1], $BlendDC, 0, 0, 1, 1, 128)
	_WinAPI_AlphaBlend($GDI, $B[0], 0, $B[2], $B[1], $BlendDC, 0, 0, 1, 1, 128)
	_WinAPI_AlphaBlend($GDI, $B[0]+$B[2], 0, $WSize[0], $WSize[1], $BlendDC, 0, 0, 1, 1, 128)
	_WinAPI_AlphaBlend($GDI, $B[0], $B[1]+$B[3], $B[2], $WSize[1], $BlendDC, 0, 0, 1, 1, 128)
EndFunc
Func DrawTransition($DRW, $Time)
	Local $Timer = TimerInit()
	Local $Y

	While TimerDiff($Timer) < $Time
		$Y = Floor($WSize[1] * (1 - TimerDiff($Timer)/$Time))

		_WinAPI_BitBlt($GDI, 0, $Y, $WSize[0], $WSize[1]-$Y, $DRW, 0, 0, $SRCCOPY)
	WEnd
EndFunc
Func DrawComment($DRW, $Time = 0, $Title = "", $Comment = "")
	Local Static $Info[5] = [0,0,"","",False]
	Local $Timer

	If $Time <> 0 And ($Title <> "" Or $Comment <> "") Then
		$Info[0] = TimerDiff($GTimer)
		$Info[1] = $Time
		$Info[2] = $Title
		$Info[3] = $Comment

		$ANIMATION_PLAYING = True
		Return
	EndIf

	$Timer = TimerDiff($GTimer) - $Info[0]

	;if ended draw taller
	If $Info[4] Then
		_WinAPI_FillRect($DRW, Rect(10, $AlignB, $WSize[0]-20, 20), $Brush[5])

		_WinAPI_SelectObject($DRW, $Font9)
		_WinAPI_SetBkColor  ($DRW, $Color[5])
		_WinAPI_SetTextColor($DRW, $Color[10])

		_WinAPI_DrawText($DRW, $Info[3], Rect(10, $AlignB, $WSize[0]-20, 20), $DT_CENTER)
	Else
		_WinAPI_FillRect($DRW, Rect(10, $AlignB+10, $WSize[0]-20, 20), $Brush[5])
	EndIf


	If $Timer < $Info[1] Then
		Local $X, $Y
		Local $T

		$T = ($Info[1] - $Timer) / $Info[1]
		$Y = $WSize[1]/7 * Popup($T)
		$X = 4

		If $T < 0.5 Then $Info[4] = True

		_WinAPI_FillRect($DRW, Rect(10, $WSize[1]-$Y, $WSize[0]-20, $Y), $Brush[5])

		_WinAPI_SelectObject($DRW, $Font30)
		_WinAPI_SetBkColor  ($DRW, $Color[5])
		_WinAPI_SetTextColor($DRW, $Color[10])
		_WinAPI_DrawText($DRW, $Info[2], Rect(10, $WSize[1]-$Y + $X, $WSize[0]-20, 55), $DT_CENTER)

		$X += $Info[2] = "" ? 14 : 53

		_WinAPI_SelectObject($DRW, $Font20)
		_WinAPI_DrawText($DRW, $Info[3], Rect(10, $WSize[1]-$Y + $X, $WSize[0]-20, $Y), $DT_CENTER)
	Else
		$ANIMATION_PLAYING = False
	EndIf
EndFunc

;X from 1 to 0
Func Popup($X)
	$X = 1-$X

	If $X < 1/5 Then Return $X*$X*25
	If $X < 4/5 Then Return 1
	If $X <  1  Then Return (1-$X)*(1-$X)*25
EndFunc


Func Sound($SE)
	If $VOLUME = 0 Then Return

	Switch $SE
		Case "move"
			_BASS_ChannelPlay($Sound[0][2], True)
		Case "rotate"
			_BASS_ChannelPlay($Sound[1][2], True)
		Case "drop"
			_BASS_ChannelPlay($Sound[2][2], True)
		Case "hold"
			_BASS_ChannelPlay($Sound[3][2], True)
		Case "kick"
			_BASS_ChannelPlay($Sound[4][2], True)
		Case "clear"
			_BASS_ChannelPlay($Sound[5][2], True)
		Case "tetris"
			_BASS_ChannelPlay($Sound[6][2], True)
		Case "tspin"
			_BASS_ChannelPlay($Sound[7][2], True)
		Case "b2b", "btb"
			_BASS_ChannelPlay($Sound[8][2], True)
		Case "fall"
			_BASS_ChannelPlay($Sound[9][2], True)
		Case "lose"
			_BASS_ChannelPlay($Sound[10][2], True)
	EndSwitch

EndFunc


Func SaveState()
	ReDim $SaveState[8]

	$SaveState[0] = $Piece
	$SaveState[1] = $PieceH
	$SaveState[2] = $Swapped
	$SaveState[3] = $BtB
	$SaveState[4] = $ClearCombo
	$SaveState[5] = $BagSeed
	$SaveState[6] = __MemCopy($GRID)
	$SaveState[7] = __MemCopy($Bag)
EndFunc
Func LoadState()
	If UBound($SaveState, 1) < 8 Then Return 0

	StatsReset()
	$Piece		= $SaveState[0]
	$PieceH		= $SaveState[1]
	$Swapped	= $SaveState[2]
	$BtB		= $SaveState[3]
	$ClearCombo	= $SaveState[4]
	$BagSeed    = $SaveState[5]
	$GRID 		= __MemCopy($SaveState[6])
	$Bag		= __MemCopy($SaveState[7])
	PieceReset()

	$CHG = True
EndFunc

Func SetQueue()
	SetHotkeys(1)
	$KEYACTIVE = False

	Local $W, $Q

	$Q = PieceGetName($Piece)
	For $i = 0 To UBound($Bag) - 1
		$Q &= PieceGetName($Bag[$i])
	Next

	$W = WinGetPos($GUI)
	$Q = InputBox($WTITLE, "Set the queue (TLJZSOI)", $Q, "", 250, 130, $W[0]+$W[2]/2-125, $W[1]+$W[3]/2-65, 0, $GUI)
	If @error Then Return

	$Q = StringStripWS($Q, 8)
	$Q = StringSplit  ($Q, "", 2)
	For $i = 0 To UBound($Q) - 1
		$Q[$i] = PieceGetID($Q[$i])
	Next
	$Bag = $Q

	PieceNext()
	$CHG = True
EndFunc
Func SetHold()
	SetHotkeys(1)
	$KEYACTIVE = False

	Local $W, $Q

	$Q = PieceGetName($PieceH)

	$W = WinGetPos($GUI)
	$Q = InputBox($WTITLE, "Set the hold piece. (TLJZSOI)", $Q, "", 250, 130, $W[0]+$W[2]/2-125, $W[1]+$W[3]/2-65, 0, $GUI)
	If @error Then Return

	$Q = StringStripWS($Q, 8)
	$Q = StringLeft   ($Q, 1)
	If $Q = "" Then
		$PieceH = -1 ;empty hold
	Else
		$PieceH = PieceGetID($Q)
	EndIf

	$Swapped = False
	$CHG = True
EndFunc
Func SetUnlimitedHold()
	$InfiniteSwaps = (Not $InfiniteSwaps = True)
	If $InfiniteSwaps Then $Swapped = False

	IniWrite("settings.ini", "SETTINGS", "INFINITE_HOLD", $InfiniteSwaps)

	$CHG = True
EndFunc

Func StateEncode()
	Local $Title     = '' ;unused
	Local $Comment   = '' ;unused
	Local $QueueData = ''
	Local $BoardData = ''

	$QueueData = '[' & __QueueEncode() ;4 bits per piece + 16 bits (bag seed)
	$BoardData = '[' & __BoardEncode() ;4 bits per block

	Return $QueueData&$BoardData
EndFunc
Func StateDecode($Data)
	Local $Title     = ''
	Local $Comment   = ''
	Local $QueueData = ''
	Local $BoardData = ''

	;strip whitespace later becuse we want to read comment first
	$Data = StringSplit  ($Data, "[")
	If $Data[0] > 0 Then $Comment   = StringStripWS($Data[1], 7)
	If $Data[0] > 1 Then $QueueData = StringStripWS($Data[2], 8)
	If $Data[0] > 2 Then $BoardData = StringStripWS($Data[3], 8)

	;decode and decompress the data
	$QueueData = __QueueDecode($QueueData)
	If Not IsArray($QueueData) Then Return
	$BoardData = __BoardDecode($BoardData)
	If Not IsArray($BoardData) Then Return

	;we now divide the info into title and comment
	$Comment = StringReplace($Comment, @CR, "")
	$Comment = StringReplace($Comment, @LF, "")
	$Comment = StringSplit  ($Comment, "|")
	If $Comment[0] > 1 Then
		$Title   = StringLeft($Comment[1], 19)
		$Comment = StringLeft($Comment[2], 33)
	ElseIf $Comment[1] <> "" Then
		$Comment = StringLeft($Comment[1], 33) & @LF & _
				   StringMid ($Comment[1], 34, 33)
	Else
		$Comment = ""
	EndIf

	StatsReset()
	$BagSeed = $QueueData[0]
	$PieceH  = $QueueData[1]
	$Bag     = $QueueData[2]
	$GRID    = $BoardData
	DrawComment(0, 2000, $Title, $Comment)
	PieceNext()

	$CHG = True
EndFunc

Func __QueueEncode()
	Local $S = ''

	$S &= Hex($BagSeed, 4)
	$S &= Hex($PieceH, 1) & Hex($Piece,  1)
	For $i = 0 To UBound($Bag) - 1
		$S &= Hex($Bag[$i], 1)
	Next

	If Mod(StringLen($S), 2) Then $S &= 'F'

	$S = Binary('0x'&$S)
	;$S = _LZNTCompress($S, 258)
	$S = B64_Encode($S)

	Return $S
EndFunc
Func __QueueDecode($QueueData)
	Local $Seed
	Local $Hold
	Local $Queue

	$S = B64_Decode($QueueData)
	$S = StringMid($S&'', 3)

	$Seed  = StringMid($S, 1, 4)
	$Hold  = StringMid($S, 5, 1)
	$Queue = StringMid($S, 6)
	$Queue = StringRight($Queue, 1) = 'F' ? StringTrimRight($Queue, 1) : $Queue

	;check data is correct lengths
	If StringLen($Seed) <> 4 Then Return
	If StringLen($Hold) <> 1 Then Return

	;conversts values to decimal
	$Seed  = Dec($Seed)
	$Hold  = Dec($Hold)
	$Queue = StringSplit($Queue, '', 2)

	;normalizes
	If $Hold = 15 Then $Hold = -1
	If $Hold > 7  Then $Hold = 7
	For $Q In $Queue
		$Q = Dec($Q) > 7 ? 7 : Dec($Q)
	Next

	Local  $Data[3] = [$Seed, $Hold, $Queue]
	Return $Data
EndFunc
Func __BoardEncode()
	Local $S = ''

	$S &= Hex(UBound($GRID, 1), 2)
	$S &= Hex(UBound($GRID, 2), 2)

	For $j = 0 To UBound($GRID, 2) - 1
		For $i = 0 To UBound($GRID, 1) - 1
			$S &= Hex($GRID[$i][$j], 1)
		Next
	Next

	If Mod(StringLen($S), 2) Then $S &= '0'

	$S = Binary('0x'&$S)
	$S = _LZNTCompress($S, 258)
	$S = B64_Encode($S)

	Return $S
EndFunc
Func __BoardDecode($BoardData)
	Local $Width
	Local $Height
	Local $Board

	$S = B64_Decode($BoardData)
	$S = _LZNTDecompress($S)
	$S = StringMid($S&'', 3)

	$Width  = StringMid($S, 1, 2)
	$Height = StringMid($S, 3, 2)
	$Board  = StringMid($S, 5)

	;check data is correct lengths
	If StringLen($Width)  <> 2 Then Return
	If StringLen($Height) <> 2 Then Return
	If Dec($Width ) <> UBound($GRID, 1) Then Return
	If Dec($Height) <> UBound($GRID, 2) Then Return
	If StringLen($Board) < Dec($Width)*Dec($Height) Then Return

	$S     = StringSplit($Board, '', 2)
	$Board = __MemCopy($GRID)

	Local $k = 0
	For $j = 0 To UBound($GRID, 2) - 1
		For $i = 0 To UBound($GRID, 1) - 1
			$Board[$i][$j] = Dec($S[$k]) > 8 ? 8 : Dec($S[$k])
			$k += 1
		Next
	Next

	Return $Board
EndFunc


Func Copy()
	ClipPut(StateEncode())
EndFunc
Func Paste()
	StateDecode(ClipGet())
EndFunc
Func Undo()
	If $UNDO_MAX = 0 Then Return
	If $REDO_MAX = 0 Then NewRedo()
	$UNDO_MAX  -= 1
	$REDO_MAX  += 1
	$UNDO_INDEX = Mod($UNDO_INDEX + UBound($UNDO) - 1, UBound($UNDO))

	SetBoard()
EndFunc
Func Redo()
	If $REDO_MAX = 0 Then Return
	$UNDO_MAX  += 1
	$REDO_MAX  -= 1
	$UNDO_INDEX = Mod($UNDO_INDEX + 1, UBound($UNDO))

	SetBoard()
EndFunc
Func NewUndo()
	$UNDO[$UNDO_INDEX][0] = $Piece
	$UNDO[$UNDO_INDEX][1] = $PieceH
	$UNDO[$UNDO_INDEX][2] = $Swapped
	$UNDO[$UNDO_INDEX][3] = $BtB
	$UNDO[$UNDO_INDEX][4] = $ClearCombo
	$UNDO[$UNDO_INDEX][5] = $BagSeed
	$UNDO[$UNDO_INDEX][6] = __MemCopy($GRID)
	$UNDO[$UNDO_INDEX][7] = __MemCopy($Bag)

	$REDO_MAX   = 0
	$UNDO_MAX  += 1
	$UNDO_INDEX = Mod($UNDO_INDEX+1, UBound($UNDO))

	If $UNDO_MAX > UBound($UNDO) Then $UNDO_MAX = UBound($UNDO)
EndFunc
Func NewRedo()
	NewUndo()
	$UNDO_INDEX = Mod($UNDO_INDEX + UBound($UNDO) - 1, UBound($UNDO))
	$UNDO_MAX  -= 1
EndFunc
Func SetBoard()
	$CHG 		= True
	$Lost       = False
	$Perfect    = False
	$AttackText = ""

	$Piece		= $UNDO[$UNDO_INDEX][0]
	$PieceH		= $UNDO[$UNDO_INDEX][1]
	$Swapped	= $UNDO[$UNDO_INDEX][2]
	$BtB		= $UNDO[$UNDO_INDEX][3]
	$ClearCombo	= $UNDO[$UNDO_INDEX][4]
	$BagSeed    = $UNDO[$UNDO_INDEX][5]
	$GRID 		= __MemCopy($UNDO[$UNDO_INDEX][6])
	$Bag		= __MemCopy($UNDO[$UNDO_INDEX][7])

	PieceReset()
EndFunc


Func SnapScreen()
	Local $Screen, $ScreenDC
	Local $HSnap, $Snap
	Local $DISPLAY, $DRW, $BUF, $GDI
	Local $Brush, $Blend

	Local $tPos    = _WinAPI_GetMousePos()
	Local $Monitor = _WinAPI_MonitorFromPoint($tPos)
	Local $Info    = _WinAPI_GetMonitorInfo($Monitor)
	Local $Size[4]
	$Size[0] = DllStructGetData($Info[0], 1)
	$Size[1] = DllStructGetData($Info[0], 2)
	$Size[2] = DllStructGetData($Info[0], 3)
	$Size[3] = DllStructGetData($Info[0], 4)
	Local $Bounds = BoundBox($Size[0], $Size[1], $Size[2]-$Size[0], $Size[3]-$Size[1])

	Local $W = $Size[2] - $Size[0]
	Local $H = $Size[3] - $Size[1]
	Local $Top, $Left

	$Screen   = _ScreenCapture_Capture("", $Size[0], $Size[1], $Size[2]-1, $Size[3]-1, False)
	$ScreenDC = _WinAPI_CreateCompatibleDC(0)

	$DISPLAY = GUICreate("", $W, $H, $Size[0], $Size[1], 0x90000000)
	$GDI   = _WinAPI_GetDC($DISPLAY)
	$BUF   = _WinAPI_CreateCompatibleBitmap($GDI, $W, $H)
	$DRW   = _WinAPI_CreateCompatibleDC($GDI)
	$Brush = _WinAPI_CreateSolidBrush(0xFFFFFF)
	$Blend = _WinAPI_CreateSolidBitmap($DISPLAY, 0x000000, 1, 1)
	GUISetState()

	_WinAPI_SelectObject($DRW, $BUF)

	_WinAPI_SelectObject($ScreenDC, $Screen)
	_WinAPI_BitBlt($DRW, 0, 0, $W, $H, $ScreenDC, 0, 0, $SRCCOPY)
 	_WinAPI_SelectObject($ScreenDC, $Blend)
	_WinAPI_AlphaBlend($DRW, 0, 0, $W, $H, $ScreenDC, 0, 0, 1, 1, 128)

	_WinAPI_BitBlt($GDI, 0, 0, $W, $H, $DRW, 0, 0, $SRCCOPY)

	Local $Pos[4]
	While True
		Switch GUIGetMsg()
			Case -3
				ExitLoop
			Case -7
				$m = GUIGetCursorInfo($DISPLAY)
				If IsArray($m) And $m[2] Then
					$Pos[0] = $m[0]
					$Pos[1] = $m[1]

					While GUIGetMsg() <> -8
						$m = GUIGetCursorInfo($DISPLAY)
						If IsArray($m) And $m[2] Then
							$Pos[2] = $m[0]
							$Pos[3] = $m[1]
						EndIf

						$Left = $Pos[0]
						If $Pos[0] > $Pos[2] Then $Left = $Pos[2]
						$Top  = $Pos[1]
						If $Pos[1] > $Pos[3] Then $Top  = $Pos[3]

						_WinAPI_SelectObject($ScreenDC, $Screen)
						_WinAPI_BitBlt    ($DRW, 0, 0, $W, $H, $ScreenDC, 0, 0, $SRCCOPY)
						_WinAPI_SelectObject($ScreenDC, $Blend)
						_WinAPI_AlphaBlend($DRW, 0, 0, $W, $H, $ScreenDC, 0, 0, 1, 1, 128)
						_WinAPI_SelectObject($ScreenDC, $Screen)

						_WinAPI_BitBlt($DRW, $Left, _
											 $Top, _
											 Abs($Pos[2]-$Pos[0])+1, _
											 Abs($Pos[3]-$Pos[1])+1, _
											 $ScreenDC, $Left, $Top, $SRCCOPY)
						_WinAPI_FrameRect($DRW, _
						Rect($Left-1, $Top-1, Abs($Pos[2]-$Pos[0])+3, Abs($Pos[3]-$Pos[1])+3), $Brush)

						_WinAPI_BitBlt($GDI, 0, 0, $W, $H, $DRW, 0, 0, $SRCCOPY)
					WEnd

					$HSnap = _ScreenCapture_Capture("", $Left+$Size[0], _
														$Top +$Size[1], _
														$Left+$Size[0] + Abs($Pos[2]-$Pos[0]), _
														$Top +$Size[1] + Abs($Pos[3]-$Pos[1]), False)
					ExitLoop
				EndIf
		EndSwitch

		If Not Bounds(MouseGetPos(), $Bounds) Then
			$tPos    = _WinAPI_GetMousePos()
			$Monitor = _WinAPI_MonitorFromPoint($tPos)
			$Info    = _WinAPI_GetMonitorInfo($Monitor)
			$Size[0] = DllStructGetData($Info[0], 1)
			$Size[1] = DllStructGetData($Info[0], 2)
			$Size[2] = DllStructGetData($Info[0], 3)
			$Size[3] = DllStructGetData($Info[0], 4)
			$Bounds  = BoundBox($Size[0], $Size[1], $Size[2]-$Size[0], $Size[3]-$Size[1])

			$W = $Size[2] - $Size[0]
			$H = $Size[3] - $Size[1]

			_WinAPI_DeleteObject($Screen)
			$Screen  = _ScreenCapture_Capture("", $Size[0], $Size[1], $Size[2]-1, $Size[3]-1, False)


			_WinAPI_SelectObject($ScreenDC, $Screen)
			_WinAPI_BitBlt($DRW, 0, 0, $W, $H, $ScreenDC, 0, 0, $SRCCOPY)
			_WinAPI_SelectObject($ScreenDC, $Blend)
			_WinAPI_AlphaBlend($DRW, 0, 0, $W, $H, $ScreenDC, 0, 0, 1, 1, 128)

			_WinAPI_MoveWindow($DISPLAY, $Size[0], $Size[1], $W, $H)
			_WinAPI_BitBlt($GDI, 0, 0, $W, $H, $DRW, 0, 0, $SRCCOPY)
		EndIf
	WEnd

	_WinAPI_DeleteDC($DRW)
	_WinAPI_DeleteDC($ScreenDC)
	_WinAPI_ReleaseDC($DISPLAY, $GDI)

	_WinAPI_DeleteObject($BUF)
	_WinAPI_DeleteObject($Brush)
	_WinAPI_DeleteObject($Blend)
	_WinAPI_DeleteObject($Screen)
	GUIDelete($DISPLAY)

	Return $HSnap
EndFunc
Func SnapBoard()
	Local $Snap

	GUISetState(@SW_HIDE)
	Sleep(200)

	$Snap = SnapScreen()
	If $Snap <> 0 Then FillBoardFromBitmap($Snap)

	_WinAPI_DeleteObject($Snap)
	GUISetState()
EndFunc
Func FillBoardFromBitmap($Bitmap)
	Local $BoardDC, $Pixel

	NewUndo()
	PieceReset()

	Local $i, $j
	For $i = 0 To UBound($GRID, 1) - 1
		For $j = 0 To UBound($GRID, 2) - 1
			$GRID[$i][$j] = 0
		Next
	Next
	$CHG = True

	$BoardDC = _WinAPI_CreateCompatibleDC(0)
	_WinAPI_SelectObject($BoardDC, $Bitmap)

	Local $tSize   = _WinAPI_GetBitmapDimension($Bitmap)
	Local $Size[2] = [DllStructGetData($tSize, 'X'), DllStructGetData($tSize, 'Y')]

	Local $Cell   = $Size[0] / UBound($GRID)
	Local $Center = $Cell / 2
	Local $Offset = $Size[1] - Floor($Size[1] / $Cell) * $Cell

	Local $k = UBound($GRID, 2) - Floor($Size[1] / $Cell)
	If $k < 0 Then $k = 0

	For $i = 0 To UBound($GRID) - 1
		For $j = 0 To UBound($GRID, 2) - $k - 1

			$Pixel = _WinAPI_GetPixel($BoardDC, Floor($i * $Cell) + $Center, Floor($Offset + $j * $Cell) + $Center)
			$RGB   = _ColorGetRGB(BitAND($Pixel, 0x00FFFFFF))
			$HSV   = _ColorConvertRGBtoHSL($RGB)

			If $HSV[2] > 50 Then
				If $HSV[1] < 20 Then
					$GRID[$i][$j+$k] = 8
				Else
					Switch $HSV[0]
						Case 220 To 240, 0 To 15 ;red
							$GRID[$i][$j+$k] = 5
						Case 15 To 27 ;orange
							$GRID[$i][$j+$k] = 6
						Case 27 To 45 ;yellow
							$GRID[$i][$j+$k] = 4
						Case 45 To 100 ;green
							$GRID[$i][$j+$k] = 3
						Case 100 To 135 ;cyan
							$GRID[$i][$j+$k] = 1
						Case 135 To 175 ;blue
							$GRID[$i][$j+$k] = 2
						Case 175 To 220 ;magenta
							$GRID[$i][$j+$k] = 7
						Case Else
							$GRID[$i][$j+$k] = 8
					EndSwitch
				EndIf
			Else
				$GRID[$i][$j+$k] = 0
			EndIf
		Next
	Next

	_WinAPI_DeleteDC($BoardDC)
EndFunc


Func GameInput()
	If Not $KEYBINDS[0][$KEYSTATE] And Not $KEYBINDS[1][$KEYSTATE] Then $DAS_DIR = ""
	If $DAS_DIR = "L" Then
		If $KEYBINDS[0][$KEYSTATE] Then
			If $KEYBINDS[0][$KEYTIME] + $DAS < _WinAPI_GetTickCount() Then
				While $KEYBINDS[0][$KEYTIME] + $DAS + $tARR < _WinAPI_GetTickCount()
					If Not MovePiece(0,-1,0) Then ExitLoop
					$tARR += $ARR
					If $ARR > 15 Then Sound("move")
				WEnd
			EndIf
		EndIf

		If Not $KEYBINDS[0][$KEYSTATE] And $KEYBINDS[1][$KEYSTATE] Then
			$KEYBINDS[1][$KEYTIME] = $KEYBINDS[0][$KEYTIME]
			$DAS_DIR = "R"
			$tARR = 0
		EndIf

	ElseIf $DAS_DIR = "R" Then
		If $KEYBINDS[1][$KEYSTATE] Then
			If $KEYBINDS[1][$KEYTIME] + $DAS < _WinAPI_GetTickCount() Then
				While $KEYBINDS[1][$KEYTIME] + $DAS + $tARR < _WinAPI_GetTickCount()
					If Not MovePiece(0,+1,0) Then ExitLoop
					$tARR += $ARR
					If $ARR > 15 Then Sound("move")
				WEnd
			EndIf
		EndIf

		If Not $KEYBINDS[1][$KEYSTATE] And $KEYBINDS[0][$KEYSTATE] Then
			$KEYBINDS[0][$KEYTIME] = $KEYBINDS[1][$KEYTIME]
			$DAS_DIR = "L"
			$tARR = 0
		EndIf
	EndIf

	If $KEYBINDS[2][$KEYSTATE] Then
		MovePiece(0, 0, +1)
	EndIf
EndFunc   ;==>GameInput
Func RotateCCW()
	If $Lost Then Return
	Return MovePiece(1, 0, 0)
EndFunc   ;==>RotateL
Func RotateCW()
	If $Lost Then Return
	Return MovePiece(3, 0, 0)
EndFunc   ;==>RotateR
Func Rotate180()
	If $Lost Then Return
	Return MovePiece(2, 0, 0)
EndFunc
Func MoveL()
	If $Lost Then Return
	Sound("move")

	$tARR = 0
	If $DAS_CAN Or Not $KEYBINDS[1][$KEYSTATE] Then
		$DAS_DIR = "L"
	Else
		$DAS_DIR = ""
	EndIf

	Return MovePiece(0, -1, 0)
EndFunc
Func MoveR()
	If $Lost Then Return
	Sound("move")

	$tARR = 0
	If $DAS_CAN Or Not $KEYBINDS[0][$KEYSTATE] Then
		$DAS_DIR = "R"
	Else
		$DAS_DIR = ""
	EndIf

	Return MovePiece(0, +1, 0)
EndFunc
Func MoveD()
	If $Lost Then Return
	Return MovePiece(0, 0, +1)
EndFunc
Func MoveU()
	If $Lost Then Return
	Return MovePiece(0, 0, -1)
EndFunc
Func Drop()
	If $Lost Then Return

	Do
	Until Not MovePiece(0, 0, +1)

	Place($Piece, $PieceA, $PieceX, $PieceY)
EndFunc
Func Tick()
	Return MovePiece(0, 0, +1)
EndFunc   ;==>Tick


Func BagFill()
	Local $Fill

	While UBound($Bag) < 7
		$Fill = __MemCopy($AllowedPieces)

		Switch $BagType
			Case 1 ;14-Bag
				__Concat($Fill, $AllowedPieces)
				For $i = 0 To UBound($Fill) - 1
					__Swap($Fill[$i], $Fill[BagRandom(0, UBound($Fill) - 1, 1)])
				Next

			Case 2 ;Random
				For $i = 0 To UBound($Fill) - 1
					$Fill[$i] = $AllowedPieces[BagRandom(0, UBound($Fill) - 1, 1)]
				Next

			Case Else ;7-Bag
				For $i = 0 To UBound($Fill) - 1
					__Swap($Fill[$i], $Fill[BagRandom(0, UBound($Fill) - 1, 1)])
				Next
		EndSwitch

		__Concat($Bag, $Fill)
	WEnd
EndFunc
Func BagNext()
	BagFill()
	_ArrayDelete($Bag, 0)
EndFunc
Func BagGetPiece()
	BagFill()
	Return $Bag[0]
EndFunc   ;==>BagGetPiece
Func BagReset()
	$Bag = 0
	BagFill()
EndFunc
Func BagRandom($Min, $Max, $Flag)
	SRandom($BagSeed)
	$BagSeed = Random(0, 65535, 1)
	Return Random($Min, $Max, $Flag)
EndFunc
Func HoldReset()
	$PieceH = -1
EndFunc
Func PieceReset()
	$PieceX = Floor(UBound($GRID)/2) - 2
	$PieceY = $GRID_H-2
	$PieceA = 0
	$tSpin  = False

	$tGravity = TimerDiff($GTimer) + (1000 / $Gravity)

	If Not PieceFits($Piece, $PieceA, $PieceX, $PieceY) Then lose_game()
EndFunc   ;==>PieceReset
Func PieceNext()
	$Piece   = BagGetPiece()
	$Swapped = False
	$CHG = True

	BagNext()
	PieceReset()
EndFunc
Func PieceHold()
	If $Swapped Or $Lost Then Return

	Local $X = $PieceX

	If $PieceH = -1 Then
		$PieceH = $Piece
		PieceNext()
	Else
		__Swap($Piece, $PieceH)
	EndIf

	PieceReset()

	$CHG = True
	If Not $InfiniteSwaps = True Then $Swapped = True
	Sound("hold")
EndFunc   ;==>PieceHold
Func StatsReset()
	$ClearCombo = 0
	$Damage  = 0
	$Lines   = 0
	$BtB     = False
	$Perfect = False
	$Swapped = False
	$Lost    = False

	$B2BText    = ""
	$AttackText = ""
EndFunc
Func GridReset()
	Local $i, $j

	For $i = 0 To UBound($GRID, 1) - 1
		For $j = 0 To UBound($GRID, 2) - 1
			$GRID[$i][$j] = 0
		Next
	Next
EndFunc
Func GridSpawnGarbage()
	Local $GarbageAmount = GetGarbageAmount()
	Local Static $HoleSize
	Local Static $HolePos

	Local $HoleChange = $GarbageAmount + $HoleSize
	Local $HoleLastPos

	For $i = $GarbageAmount To Int($GRID_Y / 2) - 1
		If $i = $HoleChange Then

			$HoleLastPos = $HolePos
			Do
				$HolePos = Random(0, UBound($GRID, 1) - 1, 1)
			Until $HolePos <> $HoleLastPos Or Not $GarbageAlternates

			$HoleChange += $GarbageType[Random(0, UBound($GarbageType)-1, 1)]
		EndIf

		AddLine($HolePos)
	Next

	$HoleSize = $HoleChange - $i
	$CHG = True
EndFunc
Func GridSpawn4W()
	Local $H = Floor(UBound($GRID) / 2) - 2
	Local $D = UBound($GRID, 2) - 1

	For $i = 0 To UBound($GRID, 1) - 1
		For $j = 0 To UBound($GRID, 2) - 1
			If $i < $H Or $i > $H+3 Then
				$GRID[$i][$j] = 8
			EndIf
		Next
	Next

	;add 3 blocks configuration on bottom

	Switch Random(0,5,1)
		Case 0
			$GRID[$H+0][$D] = 8
			$GRID[$H+1][$D] = 8
			$GRID[$H+2][$D] = 8
		Case 1
			$GRID[$H+1][$D] = 8
			$GRID[$H+2][$D] = 8
			$GRID[$H+3][$D] = 8
		Case 2
			$GRID[$H+0][$D] = 8
			$GRID[$H+0][$D-1] = 8
			$GRID[$H+1][$D-1] = 8
		Case 3
			$GRID[$H+3][$D] = 8
			$GRID[$H+3][$D-1] = 8
			$GRID[$H+2][$D-1] = 8
		Case 4
			$GRID[$H+0][$D] = 8
			$GRID[$H+0][$D-1] = 8
			$GRID[$H+1][$D] = 8
		Case 5
			$GRID[$H+3][$D] = 8
			$GRID[$H+3][$D-1] = 8
			$GRID[$H+2][$D] = 8
	EndSwitch

	$CHG = True
EndFunc


Func clear_board()
	BagReset()
	HoldReset()
	GridReset()
	StatsReset()

	PieceNext()

	Switch $GAMEMODE
		Case 0 ;standard
		Case 1 ;cheese rush
			GridSpawnGarbage()
		Case 2 ;combo training
			GridSpawn4W()
		Case 3 ;master mode
	EndSwitch
EndFunc   ;==>clear_board
Func lose_game()
	For $i = 0 To UBound($GRID, 1) - 1
		For $j = 0 To UBound($GRID, 2) - 1
			$GRID[$i][$j] = $GRID[$i][$j] ? 8 : 0
		Next
	Next

	Sound("lose")
	$Lost = True
EndFunc


Func MovePiece($Angle, $X, $Y)
	Local $Rotation = $Angle
	Local $Sound

	$Angle = Mod($PieceA + $Angle, 4)
	$X = $PieceX + $X
	$Y = $PieceY + $Y

	If PieceFits($Piece, $Angle, $X, $Y) Then
		$PieceA = $Angle
		$PieceX = $X
		$PieceY = $Y

		$tSpin = ($Rotation <> 0) And CheckTSpin()
		$sMini = ($Rotation <> 0) And CheckMini()
		$Sound = ($Rotation <> 0) And $tSpin ? Sound("kick") : Sound("rotate")

		$CHG = True
		Return True
	Else
		If $Rotation <> 0 Then ;trying to rotate
			If KickPiece($Angle, $X, $Y, $Rotation) Then
				$PieceA = $Angle
				$PieceX = $X
				$PieceY = $Y

				$tSpin = CheckTSpin()
				$sMini = CheckMini()
				$Sound = $tSpin ? Sound("kick") : Sound("rotate")

				$CHG = True
				Return True
			Else
				Return False
			EndIf
		Else
			Return False
		EndIf
	EndIf
EndFunc
Func KickPiece(ByRef $Angle, ByRef $X, ByRef $Y, $Rotation)
	If $Piece = 0 Then
		If $Rotation = 3 Then
			Switch $Angle
				Case 3
					Local $Offset[4][2] = _
							[[-2, 0], [+1, 0], _
							[-2, +1], [+1, -2]]
				Case 2
					Local $Offset[4][2] = _
							[[-1, 0], [+2, 0], _
							[-1, -2], [+2, +1]]
				Case 1
					Local $Offset[4][2] = _
							[[+2, 0], [-1, 0], _
							[+2, -1], [-1, +2]]
				Case 0
					Local $Offset[4][2] = _
							[[+1, 0], [-2, 0], _
							[+1, +2], [-2, +1]]
			EndSwitch
		ElseIf $Rotation = 1 Then
			Switch $Angle
				Case 1
					Local $Offset[4][2] = _
							[[-1, 0], [+2, 0], _
							[-1, -2], [+2, +1]]
				Case 2
					Local $Offset[4][2] = _
							[[-2, 0], [+1, 0], _
							[-2, +1], [+1, -2]]
				Case 3
					Local $Offset[4][2] = _
							[[+1, 0], [-2, 0], _
							[+1, +2], [-2, -1]]
				Case 0
					Local $Offset[4][2] = _
							[[+2, 0], [-1, 0], _
							[+2, -1], [-1, +2]]
			EndSwitch
		Else
			Return False
		EndIf
	Else
		If $Rotation = 3 Then
			Switch $Angle
				Case 0
					Local $Offset[4][2] = _
							[[-1, 0], [-1, +1], _
							[0, -2], [-1, -2]]
				Case 1
					Local $Offset[4][2] = _
							[[+1, 0], [+1, -1], _
							[0, +2], [+1, +2]]
				Case 2
					Local $Offset[4][2] = _
							[[+1, 0], [+1, +1], _
							[0, -2], [+1, -2]]
				Case 3
					Local $Offset[4][2] = _
							[[-1, 0], [-1, -1], _
							[0, +2], [-1, +2]]
			EndSwitch
		ElseIf $Rotation = 1 Then
			Switch $Angle
				Case 0
					Local $Offset[4][2] = _
							[[+1, 0], [+1, +1], _
							[0, -2], [+1, -2]]
				Case 1
					Local $Offset[4][2] = _
							[[+1, 0], [+1, -1], _
							[0, +2], [+1, +2]]
				Case 2
					Local $Offset[4][2] = _
							[[-1, 0], [-1, +1], _
							[0, -2], [-1, -2]]
				Case 3
					Local $Offset[4][2] = _
							[[-1, 0], [-1, -1], _
							[0, +2], [-1, +2]]
			EndSwitch
		ElseIf $Rotation = 2 Then
			Switch $Angle
				Case 2
					Local $Offset[5][2] = _
							[[0, -1], [+1, -1], _
							[-1, -1], [+1, 0], [-1, 0]]
				Case 3
					Local $Offset[5][2] = _
							[[+1, 0], [+1, -2], _
							[1, -1], [0, -2], [0, -1]]
				Case 0
					Local $Offset[5][2] = _
							[[0, +1], [-1, +1], _
							[+1, +1], [-1, 0], [1, 0]]
				Case 1
					Local $Offset[5][2] = _
							[[-1, 0], [-1, +2], _
							[-1, -1], [0, -2], [0, -1]]
			EndSwitch
		Else
			Return False
		EndIf
	EndIf

	For $i = 0 To UBound($Offset) - 1
		If PieceFits($Piece, $Angle, $X + $Offset[$i][0], $Y + $Offset[$i][1]) Then
			$X += $Offset[$i][0]
			$Y += $Offset[$i][1]
			$lKick = $i

			Return True
		EndIf
	Next

	Return False
EndFunc   ;==>KickPiece
Func PieceFits($Piece, $Angle, $X, $Y)
	Local $Shape = PieceGetShape($Piece, $Angle)
	Local $i, $j

	For $i = 0 To UBound($Shape, 1) - 1
		For $j = 0 To UBound($Shape, 2) - 1
			If BlockIsFull($GRID, $X+$i, $Y+$j) And $Shape[$i][$j] Then
				Return False
			EndIf
		Next
	Next

	Return True
EndFunc

Func CheckTSpin()
	If $Piece <> 6 Then Return False ;Not a T piece

	Local $Block = 0

	$Block += BlockIsFull($GRID, $PieceX + 0, $PieceY + 0) ? 1 : 0
	$Block += BlockIsFull($GRID, $PieceX + 2, $PieceY + 0) ? 1 : 0
	$Block += BlockIsFull($GRID, $PieceX + 0, $PieceY + 2) ? 1 : 0
	$Block += BlockIsFull($GRID, $PieceX + 2, $PieceY + 2) ? 1 : 0

	Return $Block >= 3 ? True : False
EndFunc   ;==>CheckTSpin
Func CheckMini()
	If $tSpin And $lKick <> 3 Then
		If $PieceA = 1 Then _
			Return BlockIsFull($GRID, $PieceX + 2, $PieceY + 0) And _
				   BlockIsFull($GRID, $PieceX + 2, $PieceY + 2)
		If $PieceA = 3 Then _
			Return BlockIsFull($GRID, $PieceX + 0, $PieceY + 0) And _
				   BlockIsFull($GRID, $PieceX + 0, $PieceY + 2)
	EndIf

	Return False
EndFunc

Func BlockIsFull(ByRef Const $GRID, $X, $Y)
	Return BlockOutOfBounds($GRID, $X, $Y) Or $GRID[$X][$Y]
EndFunc
Func BlockIsBlock(ByRef Const $GRID, $X, $Y)
	Return BlockInBounds($GRID, $X, $Y) And $GRID[$X][$Y]
EndFunc
Func BlockInBounds(ByRef Const $GRID, $X, $Y)
	Return Not BlockOutOfBounds($GRID, $X, $Y)
EndFunc
Func BlockOutOfBounds(ByRef Const $GRID, $X, $Y)
	Return $X < 0 Or $X >= UBound($GRID, 1) Or _
		   $Y < 0 Or $Y >= UBound($GRID, 2)
EndFunc

Func Place($Piece, $Angle, $X, $Y)
	$Shape = PieceGetShape($Piece, $Angle)
	NewUndo()

	Local $i, $j
	For $i = 0 To UBound($Shape, 1) - 1
		For $j = 0 To UBound($Shape, 2) - 1

			If $Shape[$i][$j] And BlockInBounds($GRID, $X+$i, $Y+$j) Then
				$GRID[$X+$i][$Y+$j] = $Piece + 1
			EndIf
		Next
	Next

	Sound("drop")

	PieceNext()
	CheckLines()
EndFunc
Func CheckLines()
	Local $Full, $Empty
	Local $FullClear = True
	Local $LineClear = 0
	Local $Points = 0

	Local $i, $j
	For $j = 0 To UBound($GRID, 2) - 1
		$Full = True
		$Empty = True
		For $i = 0 To UBound($GRID, 1) - 1
			If Not $GRID[$i][$j] Then $Full = False
			If $GRID[$i][$j] Then $Empty = False
		Next

		If $Full Then
			$LineClear += 1
			ClearLine($j)
		Else
			If Not $Empty Then $FullClear = False
		EndIf
	Next

	$Perfect = $FullClear
	$Lines  += $LineClear
	$Damage += 10 * $Perfect
	Switch $LineClear
		Case 0
			$ClearCombo = 0
		Case 1,2,3
			$ClearCombo += 1
			$CHG = True

			$Damage += $tSpin ? $LineClear * 2 : $LineClear - 1
			$Damage -= $sMini ? 2 : 0

			Sound($tSpin ? ($BtB ? "btb" : "tspin") : "clear")
		Case 4
			$ClearCombo += 1
			$CHG = True

			$Damage += 4

			Sound($BtB ? "btb" : "tetris")
	EndSwitch
	$Damage += $ClearCombo > 2
	$Damage += $ClearCombo > 4
	$Damage += $ClearCombo > 6
	$Damage += $ClearCombo > 8
	$Damage += $ClearCombo > 11

	$B2BText    = ""
	$AttackText = ""
	If $LineClear = 4 Or ($LineClear > 0 And $tSpin) Then
		If $BtB Then
			$Damage += 1
			$B2BText = "B2B"
		Else
			$BtB = True
		EndIf

		Switch $LineClear
			Case 0
				$AttackText = "T-SPIN      "
			Case 1
				$AttackText = $sMini ? "T-SPIN MINI " : "T-SPINSINGLE"
			Case 2
				$AttackText = "T-SPINDOUBLE"
			Case 3
				$AttackText = "T-SPINTRIPLE"
			Case 4
				$AttackText = "      TETRIS"
		EndSwitch
	ElseIf $LineClear <> 0 Then
		$BtB = False
	EndIf

	Switch $GAMEMODE
		Case 1 ;cheese_race
			If $LineClear = 0 Then GridSpawnGarbage()
		Case 2 ;4wide
			If $LineClear = 0 Then clear_board()
			AddWide()
		Case 3 ;pco
	EndSwitch
EndFunc   ;==>CheckLines
Func ClearLine($Line)
	Local $i, $j
	For $i = 0 To UBound($GRID, 1) - 1
		For $j = $Line - 1 To 0 Step -1
			$GRID[$i][$j + 1] = $GRID[$i][$j]
		Next
	Next

	For $i = 0 To UBound($GRID, 1) - 1
		$GRID[$i][0] = 0
	Next
EndFunc   ;==>ClearLine
Func AddLine($HolePos)
	Local $i, $j
	For $i = 0 To UBound($GRID, 1) - 1
		For $j = 1 To UBound($GRID, 2) - 1
			$GRID[$i][$j - 1] = $GRID[$i][$j]
		Next
	Next

	For $i = 0 To UBound($GRID, 1) - 1
		If $i = $HolePos Then
			$GRID[$i][UBound($GRID, 2)-1] = 0
		Else
			$GRID[$i][UBound($GRID, 2)-1] = 8
		EndIf
	Next
EndFunc
Func AddWide()
	Local $Hole = Floor(UBound($GRID)/2) - 2

	For $i = 0 To UBound($GRID) - 1
		If $i < $Hole Or $i > $Hole+3 Then
			$GRID[$i][0] = 8
		EndIf
	Next

	$CHG = True
EndFunc


Func GetGarbageAmount()
	Local $i, $j
	For $j = 0 To UBound($GRID, 2) - 1
		For $i = 0 To UBound($GRID, 1) - 1
			If $GRID[$i][$j] = 8 Then Return UBound($GRID, 2) -$j
		Next
	Next
	Return 0
EndFunc
Func PieceGetName($Piece)
	Local $Name[7] = ["I","J","S","O","Z","L","T"]
	If $Piece < 0 Then Return ""
	If $Piece > 6 Then Return "M"
	Return $Name[$Piece]
EndFunc
Func PieceGetID($Piece)
	Switch $Piece
		Case ""
			Return -1
		Case "I"
			Return 0
		Case "J"
			Return 1
		Case "S"
			Return 2
		Case "O"
			Return 3
		Case "Z"
			Return 4
		Case "L"
			Return 5
		Case "T"
			Return 6
		Case Else
			Return 7
	EndSwitch
EndFunc
Func PieceGetShape($Piece, $Angle)
	If $Angle > 3 Then $Angle = 3
	If $Angle < 0 Then $Angle = 0

	Switch $Piece
		Case 0 ;I
			Switch $Angle
				Case 0
					Local $Shape[4][4] = [ _
							[0, 1, 0, 0], _
							[0, 1, 0, 0], _
							[0, 1, 0, 0], _
							[0, 1, 0, 0]]
				Case 1
					Local $Shape[4][4] = [ _
							[0, 0, 0, 0], _
							[1, 1, 1, 1], _
							[0, 0, 0, 0], _
							[0, 0, 0, 0]]
				Case 2
					Local $Shape[4][4] = [ _
							[0, 0, 1, 0], _
							[0, 0, 1, 0], _
							[0, 0, 1, 0], _
							[0, 0, 1, 0]]
				Case 3
					Local $Shape[4][4] = [ _
							[0, 0, 0, 0], _
							[0, 0, 0, 0], _
							[1, 1, 1, 1], _
							[0, 0, 0, 0]]
			EndSwitch
		Case 1 ;J
			Switch $Angle
				Case 0
					Local $Shape[3][3] = [ _
							[1, 1, 0], _
							[0, 1, 0], _
							[0, 1, 0]]
				Case 1
					Local $Shape[3][3] = [ _
							[0, 0, 1], _
							[1, 1, 1], _
							[0, 0, 0]]
				Case 2
					Local $Shape[3][3] = [ _
							[0, 1, 0], _
							[0, 1, 0], _
							[0, 1, 1]]
				Case 3
					Local $Shape[3][3] = [ _
							[0, 0, 0], _
							[1, 1, 1], _
							[1, 0, 0]]
			EndSwitch
		Case 2 ;S
			Switch $Angle
				Case 0
					Local $Shape[3][3] = [ _
							[0, 1, 0], _
							[1, 1, 0], _
							[1, 0, 0]]
				Case 1
					Local $Shape[3][3] = [ _
							[1, 1, 0], _
							[0, 1, 1], _
							[0, 0, 0]]
				Case 2
					Local $Shape[3][3] = [ _
							[0, 0, 1], _
							[0, 1, 1], _
							[0, 1, 0]]
				Case 3
					Local $Shape[3][3] = [ _
							[0, 0, 0], _
							[1, 1, 0], _
							[0, 1, 1]]
			EndSwitch
		Case 3 ;O
				Local $Shape[3][3] = [ _
						[0, 0, 0], _
						[1, 1, 0], _
						[1, 1, 0]]
		Case 4 ;Z
			Switch $Angle
				Case 0
					Local $Shape[3][3] = [ _
							[1, 0, 0], _
							[1, 1, 0], _
							[0, 1, 0]]
				Case 1
					Local $Shape[3][3] = [ _
							[0, 1, 1], _
							[1, 1, 0], _
							[0, 0, 0]]
				Case 2
					Local $Shape[3][3] = [ _
							[0, 1, 0], _
							[0, 1, 1], _
							[0, 0, 1]]
				Case 3
					Local $Shape[3][3] = [ _
							[0, 0, 0], _
							[0, 1, 1], _
							[1, 1, 0]]
			EndSwitch
		Case 5 ;L
			Switch $Angle
				Case 0
					Local $Shape[3][3] = [ _
							[0, 1, 0], _
							[0, 1, 0], _
							[1, 1, 0]]
				Case 1
					Local $Shape[3][3] = [ _
							[1, 0, 0], _
							[1, 1, 1], _
							[0, 0, 0]]
				Case 2
					Local $Shape[3][3] = [ _
							[0, 1, 1], _
							[0, 1, 0], _
							[0, 1, 0]]
				Case 3
					Local $Shape[3][3] = [ _
							[0, 0, 0], _
							[1, 1, 1], _
							[0, 0, 1]]
			EndSwitch
		Case 6 ;T
			Switch $Angle
				Case 0
					Local $Shape[3][3] = [ _
							[0, 1, 0], _
							[1, 1, 0], _
							[0, 1, 0]]
				Case 1
					Local $Shape[3][3] = [ _
							[0, 1, 0], _
							[1, 1, 1], _
							[0, 0, 0]]
				Case 2
					Local $Shape[3][3] = [ _
							[0, 1, 0], _
							[0, 1, 1], _
							[0, 1, 0]]
				Case 3
					Local $Shape[3][3] = [ _
							[0, 0, 0], _
							[1, 1, 1], _
							[0, 1, 0]]
			EndSwitch
		Case 7 ; Monomino
			Local $Shape[3][3] = [ _
					[0, 0, 0], _
					[0, 1, 0], _
					[0, 0, 0]]
		Case Else
			Local $Shape[1][1] = [[1]]
	EndSwitch

	Return $Shape
EndFunc   ;==>PieceGetShape
Func PieceFromShape($Shape)
	Local $Count = 0

	For $i = 0 To UBound($Shape) - 1
		For $j = 0 To UBound($Shape, 2) - 1
			If $Shape[$i][$j] Then $Count += 1
		Next
	Next

	If $Count <> 4 Then Return 7
	If UBound($Shape) < 4 Then Return 7
	If UBound($Shape, 2) < 4 Then Return 7

	;I
	If $Shape[0][0] And $Shape[1][0] And $Shape[2][0] And $Shape[3][0] Then Return 0
	If $Shape[0][0] And $Shape[0][1] And $Shape[0][2] And $Shape[0][3] Then Return 0

	;J
	If $Shape[0][0] And $Shape[0][1] And $Shape[1][1] And $Shape[2][1] Then Return 1
	If $Shape[0][0] And $Shape[1][0] And $Shape[2][0] And $Shape[2][1] Then Return 1
	If $Shape[0][2] And $Shape[1][0] And $Shape[1][1] And $Shape[1][2] Then Return 1
	If $Shape[0][0] And $Shape[0][1] And $Shape[0][2] And $Shape[1][0] Then Return 1

	;S
	If $Shape[0][1] And $Shape[1][0] And $Shape[1][1] And $Shape[2][0] Then Return 2
	If $Shape[0][0] And $Shape[0][1] And $Shape[1][1] And $Shape[1][2] Then Return 2

	;O
	If $Shape[0][0] And $Shape[0][1] And $Shape[1][0] And $Shape[1][1] Then Return 3

	;Z
	If $Shape[0][0] And $Shape[1][0] And $Shape[1][1] And $Shape[2][1] Then Return 4
	If $Shape[0][1] And $Shape[0][2] And $Shape[1][0] And $Shape[1][1] Then Return 4

	;L
	If $Shape[0][1] And $Shape[1][1] And $Shape[2][0] And $Shape[2][1] Then Return 5
	If $Shape[0][0] And $Shape[0][1] And $Shape[1][0] And $Shape[2][0] Then Return 5
	If $Shape[0][0] And $Shape[0][1] And $Shape[0][2] And $Shape[1][2] Then Return 5
	If $Shape[0][0] And $Shape[1][0] And $Shape[1][1] And $Shape[1][2] Then Return 5

	;T
	If $Shape[0][1] And $Shape[1][0] And $Shape[1][1] And $Shape[2][1] Then Return 6
	If $Shape[0][0] And $Shape[1][0] And $Shape[1][1] And $Shape[2][0] Then Return 6
	If $Shape[0][0] And $Shape[0][1] And $Shape[0][2] And $Shape[1][1] Then Return 6
	If $Shape[0][1] And $Shape[1][0] And $Shape[1][1] And $Shape[1][2] Then Return 6

	Return 7
EndFunc
Func ShapeFromCoords($Coord)
	Local $Shape[4][4]

	Local $X = 9999999
	Local $Y = 9999999

	For $i = 0 To UBound($Coord) - 1
		If $X > $Coord[$i][0] Then $X = $Coord[$i][0]
		If $Y > $Coord[$i][1] Then $Y = $Coord[$i][1]
	Next

	For $i = 0 To UBound($Coord) - 1
		$Coord[$i][0] -= $X
		$Coord[$i][1] -= $Y

		If $Coord[$i][0] >= 0 And $Coord[$i][0] < 4 And $Coord[$i][1] >= 0 And $Coord[$i][1] < 4 Then
			$Shape[$Coord[$i][0]][$Coord[$i][1]] = 1
		EndIf
	Next

	Return $Shape
EndFunc


Func Bounds($Point, $BoundBox)
	If UBound($Point)    < 2 Then Return False
	If UBound($BoundBox) < 4 Then Return False

	Return ($Point[0] >= $BoundBox[0] And $Point[0] < $BoundBox[0]+$BoundBox[2]) And _
		   ($Point[1] >= $BoundBox[1] And $Point[1] < $BoundBox[1]+$BoundBox[3])
EndFunc
Func BoundBox($X, $Y, $Width, $Height)
	Local $Bounds[4] = [$X, $Y, $Width, $Height]
	Return $Bounds
EndFunc
Func Rect($X, $Y, $Width = 0, $Height = 0)
	Local $tRECT = DllStructCreate($tagRECT)
	DllStructSetData($tRECT, "Left",   $X)
	DllStructSetData($tRECT, "Top",    $Y)
	DllStructSetData($tRECT, "Right",  $X+$Width)
	DllStructSetData($tRECT, "Bottom", $Y+$Height)
	Return $tRECT
EndFunc


Func UnloadResources()
	_WinAPI_UnhookWindowsHookEx($KEYHOOK)
	DllCallbackFree($KEYPROC)

	_BASS_Free()

	_WinAPI_DeleteObject($Font9)
	_WinAPI_DeleteObject($Font10)
	_WinAPI_DeleteObject($Font20)
	_WinAPI_DeleteObject($Font30)
	_WinAPI_DeleteObject($Font50)

	_WinAPI_DeleteDC($DRW)
	_WinAPI_DeleteDC($BlendDC)
	_WinAPI_DeleteObject($BMP)
	_WinAPI_DeleteObject($SnapBMP)
	_WinAPI_ReleaseDC($GUI, $GDI)
EndFunc


Func __MemCopy($Mem)
	Return $Mem
EndFunc
Func __Swap(ByRef $a, ByRef $b)
	Local $c = $a
	$a = $b
	$b = $c
EndFunc   ;==>__Swap
Func __Concat(ByRef $a, ByRef Const $b)
	Local $Result[UBound($a) + UBound($b)]

	For $i = 0 To UBound($a) - 1
		$Result[$i] = $a[$i]
	Next

	For $i = 0 To UBound($b) - 1
		$Result[UBound($a) + $i] = $b[$i]
	Next

	$a = $Result
EndFunc   ;==>__Concat
Func __Measure($Function)
	Local $Timer = TimerInit()
	Execute($Function)
	Return TimerDiff($Timer)
EndFunc
Func __Pair($a, $b)
	Local $Pair[2] = [$a, $b]
	Return $Pair
EndFunc

Func _CreateFont($Size, $Weight = 400, $Family = "Arial")
	Return _WinAPI_CreateFont($Size, 0, 0, 0, $Weight, False, False, False, $DEFAULT_CHARSET, _
        $OUT_DEFAULT_PRECIS, $CLIP_DEFAULT_PRECIS, $DEFAULT_QUALITY, 0, $Family)
EndFunc
