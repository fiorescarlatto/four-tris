#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=icon.ico
#AutoIt3Wrapper_Outfile=build\current\four-tris-x86.exe
#AutoIt3Wrapper_Outfile_x64=build\current\four-tris-x64.exe
#AutoIt3Wrapper_Compile_Both=y
#AutoIt3Wrapper_UseX64=y
#AutoIt3Wrapper_Res_Comment=Open source training tool for block-stacking games.
#AutoIt3Wrapper_Res_Description=four-tris
#AutoIt3Wrapper_Res_Fileversion=1.5.2.0
#AutoIt3Wrapper_Res_LegalCopyright=Copyright (C) 2020  github.com/fiorescarlatto.
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#cs
Copyright (C) 2020  github.com/fiorescarlatto

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/gpl.html>.
#ce

#include <WinAPIConstants.au3>
#include <WinAPIGDI.au3>
#include <WinAPISys.au3>
#include <WinAPIMisc.au3>
#include <WindowsConstants.au3>
#include <BorderConstants.au3>
#include <FontConstants.au3>
#include <ScreenCapture.au3>
#include <Clipboard.au3>
#include <Array.au3>
#include <Color.au3>


#include 'lib\Keyboard.au3'
#include 'lib\Base64.au3'
#include 'lib\Bass.au3'
#include 'lib\LZNT.au3'


Opt('TrayIconHide', 1)
FileChangeDir(@ScriptDir)
SRandom(Number(@SEC&@MSEC))

;fixed DPI resizing 2222222222222
DllCall('shcore.dll', 'uint', 'SetProcessDpiAwareness', 'uint', 2)
;auto resource unloading on exit
OnAutoItExitRegister('UnloadResources')

;installs the settings (only on the first launch)
FileInstall('settings.ini', 'settings.ini', 0)

#Region GAME SETTINGS
Global $DEBUG = (Not @Compiled)
Global $SCALE = Number(IniRead("settings.ini", "SETTINGS", "SCALE", 1))
Global $CURRENTVIEW = 0

Global $GRID_H = 4
Global $GRID_X = Number(IniRead('settings.ini', 'OTHER', 'CELL_AMOUNT_X', 10))
Global $GRID_Y = Number(IniRead('settings.ini', 'OTHER', 'CELL_AMOUNT_Y', 20))
Global $GRID_S = Number(IniRead('settings.ini', 'OTHER', 'CELL_SIZE', 30)) ;game cell size
Global $STYLE  = 1  ;game cell style
;ensure min 4x4 and max 32x32 including hidden lines
If $GRID_X <  4 Then $GRID_X =  4
If $GRID_X > 32 Then $GRID_X = 32
If $GRID_Y <  4 Then $GRID_Y =  4
If $GRID_Y > 28 Then $GRID_Y = 28

Global $GRID  [$GRID_X][$GRID_Y+$GRID_H] ;game grid
Global $HLIGHT[$GRID_X][$GRID_Y+$GRID_H] ;highlights


Global $WTITLE = $DEBUG ? 'four-tris test_build-' & @HOUR&':'&@MIN : 'four-tris'
Global $WSize[2] = [2*95 + $GRID_X*$GRID_S, 15*2 + ($GRID_Y+2)*$GRID_S]
;ensure minimum window size 300x610
If $WSize[0] < 300 Then $WSize[0] = 300
If $WSize[1] < 620 Then $WSize[1] = 620

;global alignments
Global $AlignL = 10
Global $AlignR = $WSize[0] - 85
Global $AlignT = 10
Global $AlignB = $WSize[1] - 16
Global $AlignC = $WSize[0] / 2
;calculates centered grid position
Global $GridX  = 95             + (($WSize[0] - 190) - $GRID_S * $GRID_X   ) / 2 ;game grid position X
Global $GridY  = 12 + 2*$GRID_S + (($WSize[1] -  33) - $GRID_S *($GRID_Y+2)) / 2 ;game grid position Y
Global $GBounds  = BoundBox($GridX, $GridY, $GRID_X * $GRID_S, $GRID_Y * $GRID_S)

;Popup information window
Global $CommentInfo[5] = [0,0,'','',False]

;current piece and hold
Global $PieceX
Global $PieceY
Global $PieceA
Global $PieceH = -1
Global $Swapped = False

Global $Bag
Global $BagSeed = Random(0, 65535, 1)
Global $BagType = Number(IniRead('settings.ini', 'SETTINGS', 'BAG_TYPE', 0))
Global $BagPieces[7] = [0,1,2,3,4,5,6]
;ensure standard bag-type
If $BagType <> 0 And $BagType <> 1 And $BagType <> 2 Then $BagType = 0

;gameplay control
Global $ARR     = Number(IniRead('settings.ini', 'SETTINGS', 'ARR', 17))
Global $DAS  	= Number(IniRead('settings.ini', 'SETTINGS', 'DAS', 133))
Global $DAS_DIR = ''
Global $SDD     = Number(IniRead('settings.ini', 'SETTINGS', 'SDD', 67))
Global $SDS     = Number(IniRead('settings.ini', 'SETTINGS', 'SDS',  1))

;garbage
Global $GarbageString = String(IniRead('settings.ini', 'SETTINGS', 'GARBAGE', '1'))
Global $GarbageType   = StringSplit($GarbageString, ',', 2)
Global $GarbageAlternates = True

;game variables
Global Enum $GM_TRAINING, $GM_CHEESE, $GM_FOUR, $GM_PC, $GM_MASTER, $GM_TOTAL
Global $GAMEMODE   = 0
Global $Gravity    = 0
Global $Stickyness = 0
Global $PCLeftover = 7

Global $Damage	= 0 ;damage sent
Global $Lines	= 0 ;lines cleared
Global $Moves   = 0 ;pieces used
Global $Lost	= False ;game has ended
Global $BtB		= False
Global $Perfect = False
Global $ClearCombo = 0
Global $B2BText	   = ''
Global $AttackText = ''

Global $tSpin   = False
Global $sMini   = False
Global $lKick   = 0 ;last kick type

;global settings
Global $EditColor     = 8
Global $EditEnabled   = True
Global $HighlightMode = False
Global $HighlightOn   = False

Global $StaticBag		= IniRead('settings.ini', 'OTHER', 'STATIC_BAG', False)			= 'True' ? True : False
Global $ShuffleBag		= IniRead('settings.ini', 'OTHER', 'SHUFFLE_BAG', False)		= 'True' ? True : False
Global $ShuffleHold		= IniRead('settings.ini', 'OTHER', 'SHUFFLE_HOLD', False)		= 'True' ? True : False
Global $HighlightClear	= IniRead('settings.ini', 'OTHER', 'HIGHLIGHT_CLEAR', True)		= 'True' ? True : False
Global $AutoColor		= IniRead('settings.ini', 'SETTINGS', 'AUTO_COLOR', True)		= 'True' ? True : False
Global $GhostPiece		= IniRead('settings.ini', 'SETTINGS', 'GHOST_PIECE', True)		= 'True' ? True : False
Global $InfiniteSwaps	= IniRead('settings.ini', 'SETTINGS', 'INFINITE_HOLD', False)	= 'True' ? True : False
Global $RenderTextures	= IniRead('settings.ini', 'SETTINGS', 'RENDER_TEXTURES', False)	= 'True' ? True : False
Global $DasCancel		= IniRead('settings.ini', 'SETTINGS', 'DAS_CANCELLATION', True)	= 'True' ? True : False
Global $MirrorQueue		= IniRead('settings.ini', 'SETTINGS', 'MIRROR_QUEUE', True)		= 'True' ? True : False

;drag file holder
Global $DROPFILE[2] = [False,'']

;undo queue
Global $UNDO[100]
Global $UNDO_INDEX = 0
Global $UNDO_MAX = 0
Global $REDO_MAX = 0

;timers
Global $GTimer = TimerInit()
Global $tInput   = 0
Global $tGravity = 0
Global $tSticky  = 0
Global $tARR = 0
Global $tSDS = 0

#EndRegion GAME SETTINGS
#Region GDI OBJECTS
Global $SSize[2] = [$WSize[0]*$SCALE,  $WSize[1]*$SCALE ]

;creates game window
Global $WSTYLE = BitOR($WS_MINIMIZEBOX, $WS_CAPTION, $WS_POPUP, $WS_SYSMENU, $WS_SIZEBOX)
Global $GUI = GUICreate($WTITLE, $WSize[0], $WSize[1], -1, -1, $WSTYLE)
_WinAPI_DragAcceptFiles($GUI, True)

;obtains offset position (size of bar and edges)
Local  $Pos = WinGetPos($GUI)
Global $WOffs[2] = [$Pos[2]-$WSize[0], $Pos[3]-$WSize[1]]

;Sets the final size
_WinAPI_SetWindowPos($GUI, 0,0,0, $SSize[0]+$WOffs[0], $SSize[1]+$WOffs[1], BitOR($SWP_NOZORDER, $SWP_NOMOVE))

;drawing tags
Global $CHG = True
Global $ANIMATION_PLAYING = False

;load custom texture
Global $TEXTURE_S
Global $TEXTURE_M[10] = [9, 4, 5, 3, 2, 0, 1, 6, 7, 8]
Global $TEXTURE_N = IniRead('settings.ini', 'SETTINGS', 'TEXTURE', 'template.png')
Global $TEXTURE = _LoadPNG('textures/' & $TEXTURE_N)
;set the size of a single block to the vertical size
$TEXTURE_S = _WinAPI_GetBitmapDimension($TEXTURE)
$TEXTURE_S = DllStructGetData($TEXTURE_S, 'Y')

;load game components and applies scaling
Global $GDI = _WinAPI_GetDC($GUI)
Global $BUF = _WinAPI_CreateCompatibleBitmap($GDI, $SSize[0], $SSize[1])
Global $DRW = _WinAPI_CreateCompatibleDC($GDI)
Global $BDC = _WinAPI_CreateCompatibleDC($GDI)
Global $ICONBMP = _WinAPI_LoadImage(0, 'buttons.bmp', $IMAGE_BITMAP, 0, 0, BitOR($LR_LOADFROMFILE, $LR_DEFAULTCOLOR))
Global $TRANSFORM = _WinAPI_CreateTransform($SCALE, 0, 0, $SCALE, 0, -$CURRENTVIEW)

_WinAPI_SelectObject   ($DRW, $BUF)
_WinAPI_SetGraphicsMode($DRW, $GM_ADVANCED)
_WinAPI_SetGraphicsMode($GDI, $GM_ADVANCED)
_WinAPI_SetWorldTransform($DRW, $TRANSFORM)
_WinAPI_SetWorldTransform($GDI, $TRANSFORM)

Global $Pen
Global $Color[14]
Global $Brush[14]
Global $Blend[14]

Global Enum $CBKG = 10, $CBOX, $CTXT, $CREV
Global $CSKIN = IniRead('settings.ini', 'SETTINGS', 'SKIN', 'DEFAULT')
Global $SKINS = IniReadSectionNames('colors.ini')
SetColors($CSKIN)

;font
Global $Font9  = _CreateFont(14, 200, 'Consolas')
Global $Font10 = _CreateFont(15, 400, 'Consolas')
Global $Font20 = _CreateFont(30, 400, 'Consolas')
Global $Font30 = _CreateFont(52, 400, 'Consolas')
Global $Font50 = _CreateFont(75, 400, 'Consolas')

#EndRegion GDI OBJECTS
#Region SOUND

_BASS_STARTUP ('se\bass'& (@AutoItX64 ? 'x64' : 'x86') &'.dll')
_BASS_Init    (0, -1, 44100, $GUI, '')

Global $VOLUME = Number(IniRead('settings.ini', 'SETTINGS', 'VOLUME', 70))
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
;key-code, action to perform, key pressed?, time of the last press/release, raising edge?
Global Enum $KEYCODE, $KEYACTION, $KEYSTATE, $KEYTIME, $KEYEDGE
Global		$KEYBINDS[21][5]
Global		$HOTKEYS [ 6][2]

;edge
$KEYBINDS[0 ][4] = 0
$KEYBINDS[1 ][4] = 0
$KEYBINDS[2 ][4] = 0
$KEYBINDS[3 ][4] = 0
$KEYBINDS[4 ][4] = 0
$KEYBINDS[5 ][4] = 0
$KEYBINDS[6 ][4] = 0
$KEYBINDS[7 ][4] = 0
$KEYBINDS[8 ][4] = 0
$KEYBINDS[9 ][4] = 0

$KEYBINDS[10][4] = 1
$KEYBINDS[11][4] = 1
$KEYBINDS[12][4] = 1
$KEYBINDS[13][4] = 1

$KEYBINDS[14][4] = 1
$KEYBINDS[15][4] = 1
$KEYBINDS[16][4] = 1
$KEYBINDS[17][4] = 1
$KEYBINDS[18][4] = 1
$KEYBINDS[19][4] = 1
$KEYBINDS[20][4] = 1

;functions
$KEYBINDS[0 ][1] = 'MoveL()'
$KEYBINDS[1 ][1] = 'MoveR()'
$KEYBINDS[2 ][1] = 'MoveD()'
$KEYBINDS[3 ][1] = 'Drop()'
$KEYBINDS[4 ][1] = 'PieceHold()'
$KEYBINDS[5 ][1] = 'RotateCCW()'
$KEYBINDS[6 ][1] = 'RotateCW()'
$KEYBINDS[7 ][1] = 'Rotate180()'
$KEYBINDS[8 ][1] = 'clear_board()'
$KEYBINDS[9 ][1] = 'GridClearFullLines()'

$KEYBINDS[10][1] = 'GridSpawnGarbage()'
$KEYBINDS[11][1] = 'GridSpawn4W()'
$KEYBINDS[12][1] = 'HighlightReset()'
$KEYBINDS[13][1] = 'HighlightModeToggle()'

$KEYBINDS[14][1] = 'PCSetLeftover(1)'
$KEYBINDS[15][1] = 'PCSetLeftover(2)'
$KEYBINDS[16][1] = 'PCSetLeftover(3)'
$KEYBINDS[17][1] = 'PCSetLeftover(4)'
$KEYBINDS[18][1] = 'PCSetLeftover(5)'
$KEYBINDS[19][1] = 'PCSetLeftover(6)'
$KEYBINDS[20][1] = 'PCSetLeftover(7)'

$HOTKEYS [0 ][1] = 'Undo'
$HOTKEYS [1 ][1] = 'Redo'
$HOTKEYS [2 ][1] = 'Redo'
$HOTKEYS [3 ][1] = 'Copy'
$HOTKEYS [4 ][1] = 'Paste'
$HOTKEYS [5 ][1] = 'BagSet'

;keybind
$KEYBINDS[0 ][0] = Number(IniRead('settings.ini', 'SETTINGS', 'KB0',  37)) ;LEFT
$KEYBINDS[1 ][0] = Number(IniRead('settings.ini', 'SETTINGS', 'KB1',  39)) ;RIGHT
$KEYBINDS[2 ][0] = Number(IniRead('settings.ini', 'SETTINGS', 'KB2',  40)) ;DOWN
$KEYBINDS[3 ][0] = Number(IniRead('settings.ini', 'SETTINGS', 'KB3',  38)) ;UP
$KEYBINDS[4 ][0] = Number(IniRead('settings.ini', 'SETTINGS', 'KB4',  67)) ;C
$KEYBINDS[5 ][0] = Number(IniRead('settings.ini', 'SETTINGS', 'KB5',  90)) ;Z
$KEYBINDS[6 ][0] = Number(IniRead('settings.ini', 'SETTINGS', 'KB6',  88)) ;X
$KEYBINDS[7 ][0] = Number(IniRead('settings.ini', 'SETTINGS', 'KB7', 160)) ;LSHIFT
$KEYBINDS[8 ][0] = Number(IniRead('settings.ini', 'SETTINGS', 'KB8', 115)) ;F4
$KEYBINDS[9 ][0] = Number(IniRead('settings.ini', 'SETTINGS', 'KB9',  13)) ;ENTER

$KEYBINDS[10][0] = 0;Number(IniRead('settings.ini', 'SETTINGS', 'KB11', 71)) ;G
$KEYBINDS[11][0] = 0;Number(IniRead('settings.ini', 'SETTINGS', 'KB12', 52)) ;4
$KEYBINDS[12][0] = Number(IniRead('settings.ini', 'SETTINGS', 'KB17',  8)) ;BACKSPACE
$KEYBINDS[13][0] = Number(IniRead('settings.ini', 'SETTINGS', 'KB18', 72)) ;H

$KEYBINDS[14][0] = 49 ;1
$KEYBINDS[15][0] = 50 ;2
$KEYBINDS[16][0] = 51 ;3
$KEYBINDS[17][0] = 52 ;4
$KEYBINDS[18][0] = 53 ;5
$KEYBINDS[19][0] = 54 ;6
$KEYBINDS[20][0] = 55 ;7

$HOTKEYS [0 ][0] = '^z'
$HOTKEYS [1 ][0] = '^+z'
$HOTKEYS [2 ][0] = '^y'
$HOTKEYS [3 ][0] = '^c'
$HOTKEYS [4 ][0] = '^v'
$HOTKEYS [5 ][0] = '^q'

Global $KEYACTIVE = False

Global $KEYPROC = DllCallbackRegister('KeyProc', 'long', 'int;wparam;lparam')
Global $MODULE  = _WinAPI_GetModuleHandle(0)
Global $KEYHOOK = _WinAPI_SetWindowsHookEx($WH_KEYBOARD_LL, DllCallbackGetPtr($KEYPROC), $MODULE)
Global $LASTKEYPRESSED = 0

#EndRegion
#Region BUTTONS
;standard buttons
Global Enum $MODEBUTTON, $SETTBUTTON, $FUMEN, $TESTBUTTON, _
			$HOLDBUTTON, $HOLDDELETE, $HOLDCHECK, _
			$NEXTBUTTON, $SHUFBUTTON, _
			$UNDOBUTTON, $REDOBUTTON, _
			$SNAPBUTTON, _
			$HILIBUTTON, $HCLRBUTTON, _
			$ACOLCHECK, _
			$MIRRBUTTON

Global $BUTTONS[16][3]
Global $BUTTONTEXT[4] = ['TRAINING  MODE  ', '        SETTINGS', '  F M N    U E  ', '          TEST  ']
If Not $DEBUG Then ReDim $BUTTONTEXT[3]

$BUTTONS[$TESTBUTTON][2] = BoundBox($AlignL, $AlignB - 120, 75, 35)
$BUTTONS[$MODEBUTTON][2] = BoundBox($AlignL, $AlignB -  80, 75, 35)
$BUTTONS[$SETTBUTTON][2] = BoundBox($AlignL, $AlignB -  40, 75, 35)

;special buttons
$BUTTONS[$HOLDBUTTON][2] = BoundBox($AlignL,      $AlignT + 150,  75,  80)
$BUTTONS[$HOLDDELETE][2] = BoundBox($AlignL + 50, $AlignT + 155,  20,  20)
$BUTTONS[$HOLDCHECK ][2] = BoundBox($AlignL,      $AlignT + 232,  75,  18)
$BUTTONS[$NEXTBUTTON][2] = BoundBox($AlignR,      $AlignT,        75, 240)
$BUTTONS[$SHUFBUTTON][2] = BoundBox($AlignR + 50, $AlignT +   5,  20,  20)
$BUTTONS[$UNDOBUTTON][2] = BoundBox($AlignR,      $AlignT + 250,  35,  35)
$BUTTONS[$REDOBUTTON][2] = BoundBox($AlignR + 40, $AlignT + 250,  35,  35)
$BUTTONS[$SNAPBUTTON][2] = BoundBox($AlignR,      $AlignB -  45,  75,  40)
$BUTTONS[$MIRRBUTTON][2] = BoundBox($AlignR,      $AlignB -  90,  75,  40)
$BUTTONS[$FUMEN][2] = BoundBox($AlignR,    $AlignB -  131,  75,  35)

$BUTTONS[$HILIBUTTON][2] = BoundBox($AlignR, $AlignT + 295, 75, 35)
$BUTTONS[$HCLRBUTTON][2] = BoundBox($AlignR, $AlignT + 335, 75, 35)

$BUTTONS[$ACOLCHECK ][2] = BoundBox($AlignR, $AlignT + 397, 75, 18)


;paint buttons
Global $PAINT[9][3]

$PAINT[0][2] = BoundBox($AlignR + 10, $AlignT + 330, 15, 15)
$PAINT[1][2] = BoundBox($AlignR + 30, $AlignT + 330, 15, 15)
$PAINT[2][2] = BoundBox($AlignR + 50, $AlignT + 330, 15, 15)
$PAINT[3][2] = BoundBox($AlignR + 10, $AlignT + 350, 15, 15)
$PAINT[4][2] = BoundBox($AlignR + 30, $AlignT + 350, 15, 15)
$PAINT[5][2] = BoundBox($AlignR + 50, $AlignT + 350, 15, 15)
$PAINT[6][2] = BoundBox($AlignR + 10, $AlignT + 370, 15, 15)
$PAINT[7][2] = BoundBox($AlignR + 30, $AlignT + 370, 15, 15)
$PAINT[8][2] = BoundBox($AlignR + 50, $AlignT + 370, 15, 15)

#EndRegion BUTTONS
#Region SETTINGS TAB
Global $SEPARATORS[4][2] = [['COLORS', 5], ['KEYBINDS', 195], ['GAMEPLAY', 490], ['SOUND', 770]]
Global $SETTINGS[26][7]
Global $SETTINGS_ACTIVE = False
Global $SETTINGS_PANELSIZE = 900
Local  $Y

;colors
$Y = $SEPARATORS[0][1]+37+5
$SETTINGS[10][2] = BoundBox($AlignC-85, $Y, 35,35)
$SETTINGS[11][2] = BoundBox($AlignC-45, $Y, 90,35)
$SETTINGS[12][2] = BoundBox($AlignC+50, $Y, 35,35)

$SETTINGS[20][2] = BoundBox($AlignC-140, $Y+40, 35, 35)
$SETTINGS[21][2] = BoundBox($AlignC-100, $Y+40, 200,35)
$SETTINGS[22][2] = BoundBox($AlignC+105, $Y+40, 35, 35)
$SETTINGS[13][2] = BoundBox($AlignC- 75, $Y+80, 140,19)

$SETTINGS[18][2] = BoundBox($AlignC-45, $Y+110, 90, 35)


;keybinds
$Y = $SEPARATORS[1][1]+37+5
$SETTINGS[0 ][2] = BoundBox($AlignC-92, $Y,     90,35)
$SETTINGS[1 ][2] = BoundBox($AlignC+2,  $Y,     90,35)
$SETTINGS[6 ][2] = BoundBox($AlignC-92, $Y+40,  90,35)
$SETTINGS[7 ][2] = BoundBox($AlignC+2,  $Y+40,  90,35)
$SETTINGS[5 ][2] = BoundBox($AlignC-45, $Y+80,  90,35)

$SETTINGS[2 ][2] = BoundBox($AlignC-140,$Y+125, 90,35)
$SETTINGS[3 ][2] = BoundBox($AlignC-45, $Y+125, 90,35)
$SETTINGS[4 ][2] = BoundBox($AlignC+50, $Y+125, 90,35)

$SETTINGS[8 ][2] = BoundBox($AlignC-45, $Y+170, 90,35)

$SETTINGS[9 ][2] = BoundBox($AlignC-92, $Y+215, 90,35)
$SETTINGS[23][2] = BoundBox($AlignC+2,  $Y+215, 90,35)


;gameplay
$Y = $SEPARATORS[2][1]+37+5
$SETTINGS[14][2] = BoundBox($AlignC-100, $Y,    200,35)
$SETTINGS[15][2] = BoundBox($AlignC-100, $Y+45, 200,35)
$SETTINGS[16][2] = BoundBox($AlignC-70,  $Y+90, 130,19)

$SETTINGS[24][2] = BoundBox($AlignC-100, $Y+125,200,35)
$SETTINGS[25][2] = BoundBox($AlignC-100, $Y+170,200,35)
$SETTINGS[17][2] = BoundBox($AlignC-70,  $Y+215,130,19)


;sound
$Y = $SEPARATORS[3][1]+37+5
$SETTINGS[19][2] = BoundBox($AlignC-100, $Y, 200,35)

;text
$SETTINGS[ 0][3] = 'MOVE LEFT'
$SETTINGS[ 1][3] = 'MOVE RIGHT'
$SETTINGS[ 2][3] = 'ROTATE CCW'
$SETTINGS[ 3][3] = 'ROTATE 180'
$SETTINGS[ 4][3] = 'ROTATE CW'
$SETTINGS[ 5][3] = 'HOLD PIECE'
$SETTINGS[ 6][3] = 'SOFT DROP'
$SETTINGS[ 7][3] = 'HARD DROP'

$SETTINGS[ 8][3] = 'RESET GAME'
$SETTINGS[ 9][3] = 'HLIGHT MODE'
$SETTINGS[23][3] = 'HLIGHT CLEAR'

$SETTINGS[10][3] = '<'
$SETTINGS[11][3] = 'SKIN'
$SETTINGS[12][3] = '>'
$SETTINGS[20][3] = '<'
$SETTINGS[21][3] = 'TEXTURE'
$SETTINGS[22][3] = '>'
$SETTINGS[13][3] = 'USE CUSTOM TEXTURES'
$SETTINGS[18][3] = 'RESET SIZE'

$SETTINGS[14][3] = 'ARR (ms)'
$SETTINGS[15][3] = 'DAS (ms)'
$SETTINGS[16][3] = 'DAS CANCELLATION'
$SETTINGS[24][3] = 'SOFTDROP SPEED (ms)'
$SETTINGS[25][3] = 'SOFTDROP DELAY (ms)'
$SETTINGS[17][3] = 'SHOW GHOST PIECE'

$SETTINGS[19][3] = 'VOLUME'


;current setting
$SETTINGS[ 0][4] = vKey($KEYBINDS[ 0][0])
$SETTINGS[ 1][4] = vKey($KEYBINDS[ 1][0])
$SETTINGS[ 2][4] = vKey($KEYBINDS[ 5][0])
$SETTINGS[ 3][4] = vKey($KEYBINDS[ 7][0])
$SETTINGS[ 4][4] = vKey($KEYBINDS[ 6][0])
$SETTINGS[ 5][4] = vKey($KEYBINDS[ 4][0])
$SETTINGS[ 6][4] = vKey($KEYBINDS[ 2][0])
$SETTINGS[ 7][4] = vKey($KEYBINDS[ 3][0])
$SETTINGS[ 8][4] = vKey($KEYBINDS[ 8][0])
$SETTINGS[ 9][4] = vKey($KEYBINDS[13][0])
$SETTINGS[23][4] = vKey($KEYBINDS[12][0])

$SETTINGS[10][4] = ''
$SETTINGS[11][4] = $CSKIN
$SETTINGS[12][4] = ''
$SETTINGS[20][4] = ''
$SETTINGS[21][4] = $TEXTURE_N
$SETTINGS[22][4] = ''
$SETTINGS[13][4] = $RenderTextures
$SETTINGS[18][4] = $SCALE

$SETTINGS[14][4] = $ARR
$SETTINGS[15][4] = $DAS
$SETTINGS[16][4] = $DasCancel
$SETTINGS[24][4] = $SDS
$SETTINGS[25][4] = $SDD
$SETTINGS[17][4] = $GhostPiece

$SETTINGS[19][4] = $VOLUME

;action
$SETTINGS[ 0][5] = 'SetKeybind(0,0)'
$SETTINGS[ 1][5] = 'SetKeybind(1,1)'
$SETTINGS[ 2][5] = 'SetKeybind(5,2)'
$SETTINGS[ 3][5] = 'SetKeybind(7,3)'
$SETTINGS[ 4][5] = 'SetKeybind(6,4)'
$SETTINGS[ 5][5] = 'SetKeybind(4,5)'
$SETTINGS[ 6][5] = 'SetKeybind(2,6)'
$SETTINGS[ 7][5] = 'SetKeybind(3,7)'
$SETTINGS[ 8][5] = 'SetKeybind(8,8)'
$SETTINGS[ 9][5] = 'SetKeybind(13,9)'
$SETTINGS[23][5] = 'SetKeybind(12,23)'

$SETTINGS[10][5] = 'SetSkin(-1, 11)'
$SETTINGS[11][5] = ''
$SETTINGS[12][5] = 'SetSkin(+1, 11)'
$SETTINGS[20][5] = 'SetTexture(-1, 21)'
$SETTINGS[21][5] = ''
$SETTINGS[22][5] = 'SetTexture(+1, 21)'
$SETTINGS[13][5] = 'ToggleCheckbox(13, "RENDER_TEXTURES", $RenderTextures)'
$SETTINGS[18][5] = 'Scaling(1.0)'

$SETTINGS[14][5] = 'SetSlider(14, 0,  32, "ARR", $ARR)'
$SETTINGS[15][5] = 'SetSlider(15, 0, 256, "DAS", $DAS)'
$SETTINGS[16][5] = 'ToggleCheckbox(16, "DAS_CANCELLATION", $DasCancel)'
$SETTINGS[24][5] = 'SetSlider(24, 0,  32, "SDS", $SDS)'
$SETTINGS[25][5] = 'SetSlider(25, 0, 256, "SDD", $SDD)'
$SETTINGS[17][5] = 'ToggleCheckbox(17, "GHOST_PIECE", $GhostPiece)'

$SETTINGS[19][5] = 'SetVolume(19)'

;trigger, 0 = falling edge, 1 = raising edge
$SETTINGS[ 0][6] = 1
$SETTINGS[ 1][6] = 1
$SETTINGS[ 2][6] = 1
$SETTINGS[ 3][6] = 1
$SETTINGS[ 4][6] = 1
$SETTINGS[ 5][6] = 1
$SETTINGS[ 6][6] = 1
$SETTINGS[ 7][6] = 1
$SETTINGS[ 8][6] = 1
$SETTINGS[ 9][6] = 1
$SETTINGS[10][6] = 1
$SETTINGS[11][6] = 1
$SETTINGS[12][6] = 1
$SETTINGS[18][6] = 1
$SETTINGS[20][6] = 1
$SETTINGS[21][6] = 1
$SETTINGS[22][6] = 1
$SETTINGS[23][6] = 1

#EndRegion
#Region TESTING
Func TestFunction()
	If Not $DEBUG Then Return
	HoldShuffle()
EndFunc

Func TestPCBag()
	Local $Size = 4

	Local $Fill = __MemCopy($BagPieces)
	For $i = 0 To UBound($Fill) - 1
		__Swap($Fill[$i], $Fill[Random($i, UBound($Fill) - 1, 1)])
	Next
	ReDim $Fill[$Size]

	$Bag = $Fill
	$CHG = True

	HoldReset()
	BagFill()
EndFunc
Func TestRNG()
	Local $RNG[14][2]

	For $i = 0 To 99999
		$RNG[Random(0,13, 1)][0] += 1
	Next
	For $i = 0 To 99999
		$RNG[Random(0,13, 1)][1] += 1
		If Mod($i, 7) = 0 Then SRandom(Random(0,65532,1))
	Next

	_ArrayDisplay($RNG)
EndFunc
Func TestFiltering()
	Local $Filter[4][6] = [ _
	[2,2,2,2,2,3], _
	[2,0,0,0,0,2], _
	[0,0,2,0,0,3], _
	[0,0,2,2,2,3]]

;~ 	Local $Filter[5][3] = [ _
;~ 	[2,2,2], _
;~ 	[2,0,2], _
;~ 	[0,0,0], _
;~ 	[0,0,2], _
;~ 	[3,2,2]]

	Local $Mirror = FilterMirror($Filter)

	Local $PL = FilterGrid($GRID, $Filter)
	Local $PR = FilterGrid($GRID, $Mirror)

	Local $Max = 0
	Local $Pos[3]

	For $i = 0 To UBound($PL, 1) - 1
		For $j = UBound($PL, 2) - 1 To 0 Step -1

			If $PL[$i][$j] > $Max Then
				$Max = $PL[$i][$j]
				$Pos[0] = $i
				$Pos[1] = $j
				$Pos[2] = 0
			EndIf

			If $PR[$i][$j] > $Max Then
				$Max = $PR[$i][$j]
				$Pos[0] = $i
				$Pos[1] = $j
				$Pos[2] = 1
			EndIf

		Next
	Next

	If $Max > 1 Then
		HighlightClear(4)
		For $i = 0 To UBound($Filter, 1) - 1
			For $j = 0 To UBound($Filter, 2) - 1

				If $Pos[2] = 0 Then
					If BlockInBounds($HLIGHT, $Pos[0] + $i, $Pos[1] + $j) And $Filter[$i][$j] = 2 Then
						$HLIGHT[$Pos[0] + $i][$Pos[1] + $j] = 4
					EndIf
				Else
					If BlockInBounds($HLIGHT, $Pos[0] + $i, $Pos[1] + $j) And $Mirror[$i][$j] = 2 Then
						$HLIGHT[$Pos[0] + $i][$Pos[1] + $j] = 4
					EndIf
				EndIf
			Next
		Next
	EndIf
EndFunc

Func FilterAt(ByRef $Filter, $x, $y)
	If $x < 0 Or $y < 0 Or $x >= UBound($Filter, 1) Or $y >= UBound($Filter, 2) Then Return 3
	Return $Filter[$x][$y]
EndFunc
Func FilterMatches(ByRef $GRID, ByRef $Filter, $x, $y)
	Local $Matching = 0
	Local $Free = 0

	For $i = 0 To UBound($Filter, 1) - 1
		For $j = 0 To UBound($Filter, 2) - 1
			If $Filter[$i][$j] = 0 And     BlockIsFull($GRID, $x+$i, $y+$j) Then Return 0 ;must be empty
			If $Filter[$i][$j] = 1 And Not BlockIsFull($GRID, $x+$i, $y+$j) Then Return 0 ;must be full

			If $Filter[$i][$j] = 2 Then ;must be fillable
				If BlockIsFull($GRID, $x+$i, $y+$j) Then
					$Matching += 1
				Else
					$Free = False

					If FilterAt($Filter, $i-1, $j) And Not BlockIsFull($GRID, $x+$i-1, $y+$j) Then $Free = True
					If FilterAt($Filter, $i+1, $j) And Not BlockIsFull($GRID, $x+$i+1, $y+$j) Then $Free = True
					If FilterAt($Filter, $i, $j-1) And Not BlockIsFull($GRID, $x+$i, $y+$j-1) Then $Free = True
					If FilterAt($Filter, $i, $j+1) And Not BlockIsFull($GRID, $x+$i, $y+$j+1) Then $Free = True

					If Not $Free Then Return 0
				EndIf
			EndIf

			If $Filter[$i][$j] = 3 Then ContinueLoop;$Matching += 1 ;can be any
		Next
	Next

	Return $Matching
EndFunc
Func FilterGrid(ByRef $GRID, ByRef $Filter)
	Local $Matching[UBound($GRID, 1)][UBound($GRID, 2)]

	For $x = 0 To UBound($GRID, 1) - UBound($Filter, 1)
		For $y = 0 To UBound($GRID, 2) - UBound($Filter, 2)
			$Matching[$x][$y] = FilterMatches($GRID, $Filter, $x, $y)
		Next
	Next

	Return $Matching
EndFunc
Func FilterMirror(ByRef $Filter)
	Local $Mirror[UBound($Filter, 1)][UBound($Filter, 2)]

	For $i = 0 to UBound($Filter, 1) - 1
		For $j = 0 To UBound($Filter, 2) - 1
			$Mirror[UBound($Filter, 1) - $i - 1][$j] = $Filter[$i][$j]
		Next
	Next

	Return $Mirror
EndFunc


#EndRegion

GUIRegisterMsg($WM_PAINT, 'WMPaint')
GUIRegisterMsg($WM_MOVE,  'WMPaint')
GUIRegisterMsg($WM_EXITSIZEMOVE,'WMResize')
GUIRegisterMsg($WM_DROPFILES, 	'WMDropFiles')
GUIRegisterMsg($WM_MBUTTONDOWN, 'WMMButtonDown')
GUIRegisterMsg($WM_MOUSEWHEEL,	'WMMouseWheel')

clear_board()
GUISetState()

While 1
	Main()
	DrawGame($DRW)

	While TimerDiff($GTimer) > $tInput
		GameInput()
		$tInput += 1000/60
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
		If $msg = -5 Then $CHG = True ;minimize/maximize

		$m = GUIGetMousePosition($GUI)
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
			If $BUTTONS[$TESTBUTTON][0] Then Return TestFunction()
			If $BUTTONS[$MODEBUTTON][0] Then Return SwitchMode()
			If $BUTTONS[$SETTBUTTON][0] Then Return Settings()
			If $BUTTONS[$SHUFBUTTON][0] Then Return BagShuffle()
			If $BUTTONS[$NEXTBUTTON][0] Then Return BagSet()
			If $BUTTONS[$HOLDCHECK ][0] Then Return HoldModeToggle()
			If $BUTTONS[$HOLDDELETE][0] Then Return HoldReset()
			If $BUTTONS[$HOLDBUTTON][0] Then Return HoldSet()
			If $BUTTONS[$SNAPBUTTON][0] Then Return SnapBoard()
			If $BUTTONS[$FUMEN][0] Then Return Fumen()
			If $BUTTONS[$MIRRBUTTON][0] Then Return GridMirror()
			If $BUTTONS[$UNDOBUTTON][0] Then Return Undo()
			If $BUTTONS[$REDOBUTTON][0] Then Return Redo()

			If $BUTTONS[$HILIBUTTON][0] Then Return HighlightModeToggle()
			If $BUTTONS[$HCLRBUTTON][0] And $HighlightMode Then Return HighlightReset()

			If Not $HighlightMode Then
				If $BUTTONS[$ACOLCHECK][0] Then Return AutoColorToggle()

				For $i = 0 To 7
					If $PAINT[$i][0] Then Return EditColorSet($i+1)
				Next
				If $PAINT[8][0] Then
					NewUndo()
					FillColor($GRID, 8)
				EndIf
			EndIf
		EndIf

		If ($msg = -7 Or $msg = -9) And $EditEnabled And Bounds($m, $GBounds) Then
			If $HighlightMode Then
				EditHighlight($HLIGHT, $msg = -9 ? 0 : $CREV)
			Else
				EditBoard($GRID,   $msg = -9 ? 0 : $EditColor)
			EndIf
		EndIf

	Until $msg = 0
EndFunc   ;==>Main
Func GUIGetMousePosition($GUI)
	Local $Return = [-1,-1,0,0,0]
	Local $Pos = GUIGetCursorInfo($GUI)

	If IsArray($Pos) Then
		$Pos[0] =  $Pos[0]/$SCALE
		$Pos[1] = ($Pos[1]+$CURRENTVIEW)/$SCALE
		Return $Pos
	Else
		Return $Return
	EndIf
EndFunc


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
		Local $vkCode    = DllStructGetData($tKEYHOOKS, 'vkCode')
		Local $scanCode  = DllStructGetData($tKEYHOOKS, 'scanCode')
		Local $msgTime   = DllStructGetData($tKEYHOOKS, 'time')

		;Avoid Weird Windows behaviour when hitting NUMPAD keys and SHIFT
		If BitAND($scanCode, 512) Then Return _WinAPI_CallNextHookEx($KEYHOOK, $nCode, $wParam, $lParam)

		;Only allows CTRL as a single Key
		Local $CTRL = ($vkCode = 162 Or $vkCode = 163 Or Not BitAND(_WinAPI_GetAsyncKeyState(0x11), 0x8000))

		If $wParam = $WM_KEYDOWN And $CTRL Then
			$LASTKEYPRESSED = $vkCode
			For $i = 0 To UBound($KEYBINDS) - 1
				If Not $KEYBINDS[$i][$KEYSTATE] And $KEYBINDS[$i][$KEYCODE] = $vkCode Then
					$KEYBINDS[$i][$KEYSTATE] = True
					$KEYBINDS[$i][$KEYTIME ] = $msgTime
					If Not $KEYBINDS[$i][$KEYEDGE] Then Execute($KEYBINDS[$i][$KEYACTION])
				EndIf
			Next

		ElseIf $wParam = $WM_KEYUP Then
			For $i = 0 To UBound($KEYBINDS) - 1
				If $KEYBINDS[$i][$KEYSTATE] And $KEYBINDS[$i][$KEYCODE] = $vkCode Then
					$KEYBINDS[$i][$KEYSTATE] = False
					$KEYBINDS[$i][$KEYTIME ] = $msgTime
					If $KEYBINDS[$i][$KEYEDGE] And $CTRL Then Execute($KEYBINDS[$i][$KEYACTION])
				EndIf
			Next
		EndIf
	EndIf

	Return _WinAPI_CallNextHookEx($KEYHOOK, $nCode, $wParam, $lParam)
EndFunc
Func FileProc($FileName)
	Local $Bitmap = _LoadPng($FileName)
	If $Bitmap <> 0 Then FillBoardFromBitmap($Bitmap)
	_WinAPI_DeleteObject($Bitmap)
EndFunc
Func WMPaint($hWnd, $iMsg, $wParam, $lParam)
	$CHG = True
EndFunc
Func WMResize($hWnd, $iMsg, $wParam, $lParam)
	Local $Pos = WinGetClientSize($GUI)
	Scaling($Pos[1]/$WSize[1])
	$CHG = True
EndFunc
Func WMDropFiles($hWnd, $iMsg, $wParam, $lParam)
	Local $Drop

	$Drop = _WinAPI_DragQueryFileEx($wParam, 1)
		    _WinAPI_DragFinish($wParam)

	$DROPFILE[0] = True
	$DROPFILE[1] = $Drop[1]
EndFunc
Func WMMButtonDown($hWnd, $iMsg, $wParam, $lParam)
	Local $m = GUIGetMousePosition($GUI)
	If Not IsArray($m) Then Return

	If $EditEnabled And Bounds($m, $GBounds) Then
		$m[0] = Floor(($m[0] - $GridX) / $GRID_S)
		$m[1] = Floor(($m[1] - $GridY) / $GRID_S) + $GRID_H

		EditHighlight($HLIGHT, $HLIGHT[$m[0]][$m[1]] = 0 ? $CREV : 0)
	EndIf
EndFunc
Func WMMouseWheel($hWnd, $iMsg, $wParam, $lParam)
	Local $CTRL = BitAND(_WinAPI_GetAsyncKeyState(0x11), 0x8000)
	Local $ALT  = BitAND(_WinAPI_GetAsyncKeyState(0x12), 0x8000)
	Local $DIRECTION = (BitShift($wParam, 16) < 0)

	If $SETTINGS_ACTIVE Then
		If $DIRECTION Then			;wheel down
			Scroll(+100, $SETTINGS_PANELSIZE)
		Else 						;wheel up
			Scroll(-100, $SETTINGS_PANELSIZE)
		EndIf
	Else
		If $DIRECTION Then 			;wheel down
			If $CTRL Then GridShift(-1)
			If $ALT  Then GridRoll (-1)
		Else 						;wheel up
			If $CTRL Then GridShift(+1)
			If $ALT  Then GridRoll (+1)
		EndIf
	EndIf
EndFunc


Func EditHighlight(ByRef $GRID, $c = 0)
	Local $cm, $om, $msg, $mb
	Local $m[2] = [-1,-1]
	Local $o[2] = [-1,-1]
	Local $CTRL  = BitAND(_WinAPI_GetAsyncKeyState(0x11), 0x8000) ;ctrl

	$HighlightOn = True
	$cm = GUIGetMousePosition($GUI)
	$mb = BitAND(_WinAPI_GetAsyncKeyState(0x04), 0x8000)
	Do
		GUIGetMsg() ;releases cpu cycles
		$om = $cm
		$cm = GUIGetMousePosition($GUI)
		$mb = BitAND(_WinAPI_GetAsyncKeyState(0x04), 0x8000)

		For $k = 1 To 7 ;to avoid sparse dots
			$m[0] = $om[0] + ($cm[0]-$om[0]) * $k/7
			$m[1] = $om[1] + ($cm[1]-$om[1]) * $k/7
			$m[0] = Floor(($m[0] - $GridX) / $GRID_S)
			$m[1] = Floor(($m[1] - $GridY) / $GRID_S) + $GRID_H

			If ($m[0] <> $o[0] Or $m[1] <> $o[1]) And BlockInBounds($GRID, $m[0], $m[1]) Then
				$o[0] = $m[0]
				$o[1] = $m[1]

				If $CTRL Then
					HighlightReset()
					ExitLoop
				Else
					If $GRID[$m[0]][$m[1]] <> $c Then
						$GRID[$m[0]][$m[1]] = $c
						$CHG = True
					EndIf
				EndIf
			EndIf
		Next

		DrawGame($DRW)

	Until Not ($cm[2] Or $cm[3] Or $mb)

	;flushes remaining messages that could trigger other buttons
	While GUIGetMsg()
	WEnd
EndFunc
Func EditBoard(ByRef $GRID, $c = 0)
	Local $cm, $om, $msg
	Local $m[2] = [-1,-1]
	Local $o[2] = [-1,-1]

	Local $CTRL  = BitAND(_WinAPI_GetAsyncKeyState(0x11), 0x8000) ;ctrl

	Local $StrokeCoord[4][2]
	Local $Stroke = 0

	NewUndo()
	$cm = GUIGetMousePosition($GUI)

	Do
		GUIGetMsg() ;releases cpu cycles
		$om = $cm
		$cm = GUIGetMousePosition($GUI)

		For $k = 1 To 7 ;to avoid sparse dots
			$m[0] = $om[0] + ($cm[0]-$om[0]) * $k/7
			$m[1] = $om[1] + ($cm[1]-$om[1]) * $k/7
			$m[0] = Floor(($m[0] - $GridX) / $GRID_S)
			$m[1] = Floor(($m[1] - $GridY) / $GRID_S) + $GRID_H

			If ($m[0] <> $o[0] Or $m[1] <> $o[1]) And BlockInBounds($GRID, $m[0], $m[1]) Then
				$o[0] = $m[0]
				$o[1] = $m[1]

				If $CTRL Then
					For $i = 0 To UBound($GRID) - 1
						$GRID[$i][$m[1]] = $c
						If $m[0] = $i Then $GRID[$i][$m[1]] = 0
					Next
					$CHG = True

				Else
					If $GRID[$m[0]][$m[1]] <> $c Then
						$GRID[$m[0]][$m[1]] = $c
						$CHG = True

						If $Stroke < 4 Then
							$StrokeCoord[$Stroke][0] = $m[0]
							$StrokeCoord[$Stroke][1] = $m[1]
						EndIf
						$Stroke += 1

						If $c = 8 And $AutoColor Then AutoColor($GRID, $m[0],$m[1], $Stroke, $StrokeCoord)
						If $c = 0 And $AutoColor Then
							AutoColor($GRID, $m[0]-1, $m[1])
							AutoColor($GRID, $m[0]+1, $m[1])
							AutoColor($GRID, $m[0], $m[1]-1)
							AutoColor($GRID, $m[0], $m[1]+1)
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
Func EditColorSet($Color)
	$EditColor = $Color
	$CHG = True
EndFunc
Func AutoColorToggle()
	$AutoColor = $AutoColor ? False : True
	IniWrite('settings.ini', 'SETTINGS', 'AUTO_COLOR', $AutoColor)

	$CHG = True
EndFunc
Func AutoColor(ByRef $GRID, $X, $Y, $Stroke = 0, $StrokeCoord = 0)

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
			Recolor($GRID, $Coord, $Piece+1)
		EndIf

	ElseIf $Stroke = 4 Then
		Local $Shape, $Piece

		$Shape = ShapeFromCoords($StrokeCoord)
		$Piece = PieceFromShape($Shape)
		Recolor($GRID, $StrokeCoord, $Piece+1)

	ElseIf $Stroke = 5 Then
		Recolor($GRID, $StrokeCoord, 8)
	EndIf
EndFunc
Func FillColor(ByRef $GRID, $c = 0)
	For $i = 0 To UBound($GRID, 1) - 1
		For $j = 0 To UBound($GRID, 2) - 1
			$GRID[$i][$j] = $GRID[$i][$j] ? $c : 0
		Next
	Next
	$CHG = True
EndFunc
Func Recolor(ByRef $GRID, $Coord, $c)
	$CHG = True
	For $i = 0 To UBound($Coord) - 1
		$GRID[$Coord[$i][0]][$Coord[$i][1]] = $c
	Next
EndFunc


Func SwitchMode()
	SetMode(Mod($GAMEMODE+1, $GM_TOTAL))
EndFunc
Func SetMode($Mode)
	$GAMEMODE = $Mode
	Switch $GAMEMODE
		Case $GM_TRAINING ;training
			DeleteComment()
			$BUTTONTEXT[$MODEBUTTON] = 'TRAINING  MODE  '
			$Gravity = 0
		Case $GM_CHEESE ;cheese race
			DeleteComment()
			$BUTTONTEXT[$MODEBUTTON] = ' CHEESE   MODE  '
			$Gravity = 0
		Case $GM_FOUR ;4wide
			DeleteComment()
			$BUTTONTEXT[$MODEBUTTON] = '  FOUR    MODE  '
			$Gravity = 0
		Case $GM_MASTER ;master mode
			DeleteComment()
			$BUTTONTEXT[$MODEBUTTON] = ' MASTER   MODE  '
			$Gravity = 1000
		Case $GM_PC ;perfect-clear mode
			DrawComment(0, 1750, 'PC MODE', 'Use KEYS 1-7 to set the Nth. PC.')
			$BUTTONTEXT[$MODEBUTTON] = '   PC     MODE  '
			$Gravity = 0
	EndSwitch
	clear_board()
EndFunc
Func Settings()
	Local $BUF = _WinAPI_CreateCompatibleBitmap($GDI, $SSize[0], $SETTINGS_PANELSIZE*$SCALE)
	_WinAPI_SelectObject($DRW, $BUF)

	$CHG = True
	DrawSettings($DRW, 0)
	DrawTransition($DRW, 150)
	$CHG = True

	SetHotkeys(1)
	$KEYACTIVE = False
	$SETTINGS_ACTIVE = True

	Local $msg, $m
	While True
		$msg = GUIGetMsg()
		If $msg = -3 Then ExitLoop
		If $msg = -5 Then $CHG = True ;minimize

		$m = GUIGetMousePosition($GUI)
		If Not IsArray($m) Then ContinueLoop

		For $i = 0 To UBound($SETTINGS) - 1
			$SETTINGS[$i][0] = Bounds($m, $SETTINGS[$i][2])

			If $SETTINGS[$i][0] <> $SETTINGS[$i][1] Then
				$SETTINGS[$i][1] = $SETTINGS[$i][0]
				$CHG = True
			EndIf
		Next

		For $i = 0 To UBound($SETTINGS) - 1
			If $SETTINGS[$i][0] And $msg+$SETTINGS[$i][6] = -7 Then
				Execute($SETTINGS[$i][5])
				$CHG = True
			EndIf
		Next

		DrawSettings($DRW)
	WEnd

	$SETTINGS_ACTIVE = False
	Scroll(-$SETTINGS_PANELSIZE, $SETTINGS_PANELSIZE) ;resets the scroll position

	$CHG = True
	DrawGame($DRW, 0)
	DrawTransition($DRW, 150)
	$CHG = True

	_WinAPI_DeleteObject($BUF)
EndFunc


Func Scroll($Amount, $PanelSize)
	$CURRENTVIEW += $Amount

	;Clamps the view to the panel size
	If $CURRENTVIEW > $PanelSize - $WSize[1] Then $CURRENTVIEW = $PanelSize - $WSize[1]
	If $CURRENTVIEW < 0 Then $CURRENTVIEW = 0

	;Creates and applies the new matrix transform
	$TRANSFORM = _WinAPI_CreateTransform($SCALE, 0, 0, $SCALE, 0, -$CURRENTVIEW)
	_WinAPI_SetWorldTransform($DRW, $TRANSFORM)
	_WinAPI_SetWorldTransform($GDI, $TRANSFORM)
	$CHG = True
EndFunc
Func Scaling($S)
	;Calculates new $SCALE
	$SCALE    = Round($S,10)
	$SSize[0] = Int($WSize[0]*$SCALE)
	$SSize[1] = Int($WSize[1]*$SCALE)

	;Updates the number in settings
	$SETTINGS[18][4] = $SCALE

	;Sets new position
	_WinAPI_SetWindowPos($GUI, 0,0,0, $SSize[0]+$WOffs[0], $SSize[1]+$WOffs[1], BitOR($SWP_NOZORDER, $SWP_NOMOVE))
	;Resizes the Buffer and the Transform
	_WinAPI_DeleteObject($BUF)
	$BUF       = _WinAPI_CreateCompatibleBitmap($GDI, $SSize[0], $SSize[1])
	$TRANSFORM = _WinAPI_CreateTransform($SCALE, 0, 0, $SCALE, 0, -$CURRENTVIEW)

	;Applies changes
	_WinAPI_SelectObject($DRW, $BUF)
	_WinAPI_SetWorldTransform($DRW, $TRANSFORM)
	_WinAPI_SetWorldTransform($GDI, $TRANSFORM)

	IniWrite("settings.ini", "SETTINGS", "SCALE", $SCALE)
EndFunc


Func SetColors($ColorSet)
	$Color[0 ] = IniRead('colors.ini', $ColorSet, 'E', 0x000000)
	$Color[1 ] = IniRead('colors.ini', $ColorSet, 'I', 0x00D0FF)
	$Color[2 ] = IniRead('colors.ini', $ColorSet, 'J', 0x4080FF)
	$Color[3 ] = IniRead('colors.ini', $ColorSet, 'S', 0x40D040)
	$Color[4 ] = IniRead('colors.ini', $ColorSet, 'O', 0xFFE020)
	$Color[5 ] = IniRead('colors.ini', $ColorSet, 'Z', 0xFF4020)
	$Color[6 ] = IniRead('colors.ini', $ColorSet, 'L', 0xFF8020)
	$Color[7 ] = IniRead('colors.ini', $ColorSet, 'T', 0xA040F0)
	$Color[8 ] = IniRead('colors.ini', $ColorSet, 'G', 0xCCCCCC)
	$Color[9 ] = IniRead('colors.ini', $ColorSet, 'F', 0x2F3136)

	$Color[10] = IniRead('colors.ini', $ColorSet, 'BKG', 0x2F3136)
	$Color[11] = IniRead('colors.ini', $ColorSet, 'BOX', 0x000000)
	$Color[12] = IniRead('colors.ini', $ColorSet, 'TXT', 0xFFFFFF)
	$Color[13] = BitAND(0x00FFFFFF, BitXOR(0xFFFFFF, $Color[0]))

	$STYLE = Number(IniRead('colors.ini', $ColorSet, 'STYLE', 1))
	If $STYLE <> 0 And $STYLE <> 1 Then $STYLE = 1

	For $i = 0 To UBound($Brush) - 1
		_WinAPI_DeleteObject($Brush[$i])
		_WinAPI_DeleteObject($Blend[$i])
		$Color[$i] = _ColorSetCOLORREF(_ColorGetRGB($Color[$i]))
		$Brush[$i] = _WinAPI_CreateSolidBrush($Color[$i])
		$Blend[$i] = _WinAPI_CreateSolidBitmap($GUI, $Color[$i], 1, 1, 0)
	Next
EndFunc
Func SetSkin($D, $S)
	Local $i
	For $i = 1 To UBound($SKINS) - 1
		If $CSKIN = $SKINS[$i] Then ExitLoop
	Next

	$i += $D
	If $i < 1 		  Then $i = $SKINS[0]
	If $i > $SKINS[0] Then $i = 1

	$CSKIN           = $SKINS[$i]
	$SETTINGS[$S][4] = $SKINS[$i]
	IniWrite('settings.ini','SETTINGS','SKIN',$CSKIN)

	SetColors($CSKIN)
EndFunc
Func SetTexture($D, $S)
	Local $FileSearch
	Local $FileName
	Local $FirstFile = ''

	$FileSearch = FileFindFirstFile('textures/*.png')
	While 1
		$FileName = FileFindNextFile($FileSearch)
		If @error Then ExitLoop
		If $FirstFile = '' Then $FirstFile = $FileName
		If $FileName = $TEXTURE_N Then
			$TEXTURE_N = FileFindNextFile($FileSearch)
			If @error Then $TEXTURE_N = $FirstFile
		EndIf
	WEnd
	FileClose($FileSearch)

	$SETTINGS[$S][4] = $TEXTURE_N
	IniWrite('settings.ini','SETTINGS','TEXTURE',$TEXTURE_N)

	;load custom texture
	_WinAPI_DeleteObject($TEXTURE)
	$TEXTURE = _LoadPNG('textures/' & $TEXTURE_N)
	$TEXTURE_S = _WinAPI_GetBitmapDimension($TEXTURE)
	$TEXTURE_S = DllStructGetData($TEXTURE_S, 'Y')
EndFunc

Func SetKeybind($KB, $STT)
	DrawKeyCapture($STT)

	$KEYACTIVE = True
	$LASTKEYPRESSED = 27 ;esc key
	While $LASTKEYPRESSED = 27
		If GUIGetMsg() = -3 Then Return
	WEnd

	$SETTINGS[$STT][4]       = vKey($LASTKEYPRESSED)
	$KEYBINDS[$KB][$KEYCODE] = $LASTKEYPRESSED
	$KEYACTIVE = False

	ConsoleWrite($KEYBINDS[$KB][$KEYCODE]&@LF)

	IniWrite('settings.ini','SETTINGS','KB'&$KB,$LASTKEYPRESSED)
EndFunc
Func SetSlider($S, $Min, $Max, $Key, ByRef $Value)
	Local $m, $b = $SETTINGS[$S][2]

	Do
		GUIGetMsg()
		$m = GUIGetMousePosition($GUI)
		$m[0] -= $b[0]

		If $m[0] < 0 Then $m[0] = 0
		If $m[0] > $b[2] Then $m[0] = $b[2]

		$SETTINGS[$S][4] = $Min + Round($m[0] / $b[2] * ($Max - $Min))

		DrawSlider($GDI, $S, $m[0] / $b[2])
	Until Not ($m[2] Or $m[3])
	$Value = $SETTINGS[$S][4]
	$CHG = True

	IniWrite('settings.ini', 'SETTINGS', $Key, $Value)
EndFunc
Func ToggleCheckbox($S, $Key, ByRef $Value)
	$SETTINGS[$S][4] = $SETTINGS[$S][4] ? False : True
	$Value = $SETTINGS[$S][4]
	$CHG = True

	IniWrite('settings.ini', 'SETTINGS', $Key, $Value)
EndFunc
Func SetVolume($S)
	SetSlider($S, 0, 100, 'VOLUME', $VOLUME)
	SoundSetWaveVolume($VOLUME)
EndFunc


Func DrawGame($DRW, $Render = True)
	If Not $ANIMATION_PLAYING And Not $CHG Then Return 0
	$CHG = False

	_WinAPI_SelectObject($DRW, $Brush[$CBKG])
	_WinAPI_PatBlt($DRW, 0, 0, $WSize[0], $WSize[1], $PATCOPY)

	DrawGrid($DRW)
	If $GhostPiece Then DrawGuide($DRW)
	DrawPiece($DRW)
	DrawHighlight($DRW)

	DrawNext($DRW)
	DrawHold($DRW)
	DrawScore($DRW)

	DrawSnapButton($DRW)
	DrawMirrorButton($DRW)
	DrawUndoButton($DRW)
	DrawButtons($DRW)

	If $HighlightMode Then
		DrawHighlightButtons()
	Else
		DrawPaintButtons($DRW)
	EndIf

	DrawCheckboxes($DRW)
	DrawAttack($DRW)
	DrawCombo($DRW)

	DrawLose($DRW)
	DrawPerfect($DRW)
	DrawComment($DRW)

	If $Render Then _WinAPI_BitBlt($GDI, 0, 0, $WSize[0], $WSize[1], $DRW, 0, 0, $SRCCOPY)
EndFunc   ;==>Draw
Func DrawGrid($DRW)
	_WinAPI_SelectObject($DRW, $Brush[9])
	_WinAPI_PatBlt($DRW, $GBounds[0], $GBounds[1]-$GRID_S*2, $GBounds[2]-1, $GBounds[3]+$GRID_S*2-1, $PATCOPY)

	Local $i, $j

	For $j = $GRID_H-2 To $GRID_H
		For $i = 0 To UBound($GRID, 1) - 1
			If $GRID[$i][$j] <> 0 Then
				DrawBlock($DRW, $i, $j, $GRID[$i][$j])
			EndIf
		Next
	Next

	For $j = $GRID_H To UBound($GRID, 2) - 1
		For $i = 0 To UBound($GRID, 1) - 1
			DrawBlock($DRW, $i, $j, $GRID[$i][$j])
		Next
	Next
EndFunc   ;==>DrawGrid
Func DrawPiece($DRW)
	Local $Piece = BagGetPiece()
	Local $Shape = PieceGetShape($Piece, $PieceA)
	Local $X = $PieceX
	Local $Y = $PieceY

	Local $i, $j
	For $i = 0 To UBound($Shape, 1) - 1
		For $j = 0 To UBound($Shape, 2) - 1
			If Not $Shape[$i][$j] Then ContinueLoop
			DrawBlock($DRW, $X + $i, $Y + $j, $Piece + 1)
		Next
	Next
EndFunc   ;==>DrawPiece
Func DrawGuide($DRW)
	Local $Piece = BagGetPiece()
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
			If Not $Shape[$i][$j] Then ContinueLoop
			DrawBlock($DRW, $X + $i, $Y + $j, 9)
		Next
	Next
EndFunc
Func DrawBlock($DRW, $i, $j, $k)
	Local $X = $GridX + $i * $GRID_S
	Local $Y = $GridY + ($j-$GRID_H) * $GRID_S
	Local $S = $GRID_S - $STYLE

	Return DrawMiniBlock($DRW, $X, $Y, $S, $k)
EndFunc
Func DrawMiniBlock($DRW, $X, $Y, $S, $k)
	Local $T = $TEXTURE_S * $TEXTURE_M[$k]

	If $RenderTextures And $TEXTURE Then
		_WinAPI_SelectObject($BDC, $TEXTURE)
		_WinAPI_AlphaBlend($DRW, $X, $Y, $S, $S, $BDC, $T, 0, $TEXTURE_S, $TEXTURE_S, 255, True)
	Else
		If $k = 9 Then
			_WinAPI_FrameRect($DRW, Rect($X, $Y, $S-1, $S-1), $Brush[BagGetPiece() + 1])
		Else
			_WinAPI_SelectObject($DRW, $Brush[$k])
			_WinAPI_PatBlt($DRW, $X, $Y, $S, $S, $PATCOPY)
		EndIf
	EndIf
EndFunc

Func DrawHighlight($DRW)
	Local $i, $j
	Local $Full

	For $j = $GRID_H To UBound($GRID, 2) - 1
		$Full = True
		For $i = 0 To UBound($GRID, 1) - 1
			If $GRID[$i][$j] = 0 Then
				$Full = False
				ExitLoop
			EndIf
		Next

		If $Full Then
			DrawHRow($DRW, $j)
		EndIf
	Next

	For $i = 0 To UBound($HLIGHT, 1) - 1
		For $j = $GRID_H-2 To UBound($HLIGHT, 2) - 1

			If Not $HLIGHT[$i][$j] Then ContinueLoop

			If Not BlockIsNeighbour($HLIGHT, $i-1, $j, $HLIGHT[$i][$j]) Then DrawVEdge($DRW, $i, $j, 0, $HLIGHT[$i][$j])
			If Not BlockIsNeighbour($HLIGHT, $i+1, $j, $HLIGHT[$i][$j]) Then DrawVEdge($DRW, $i, $j, 1, $HLIGHT[$i][$j])
			If Not BlockIsNeighbour($HLIGHT, $i, $j-1, $HLIGHT[$i][$j]) Then DrawHEdge($DRW, $i, $j, 0, $HLIGHT[$i][$j])
			If Not BlockIsNeighbour($HLIGHT, $i, $j+1, $HLIGHT[$i][$j]) Then DrawHEdge($DRW, $i, $j, 1, $HLIGHT[$i][$j])
		Next
	Next
EndFunc
Func DrawHEdge($DRW, $X, $Y, $Type, $Color)
	Local $S = 3
	$X = $GridX + $X * $GRID_S
	$Y = $GridY + ($Y-$GRID_H) * $GRID_S - $S + $Type * ($GRID_S + $S - 1)

	_WinAPI_SelectObject($DRW, $Brush[$Color])
	_WinAPI_PatBlt($DRW, $X, $Y, $GRID_S, $S, $PATCOPY)
EndFunc
Func DrawVEdge($DRW, $X, $Y, $Type, $Color)
	Local $S = 3
	$X = $GridX + $X * $GRID_S - $S + $Type * ($GRID_S + $S - 1)
	$Y = $GridY + ($Y-$GRID_H) * $GRID_S

	_WinAPI_SelectObject($DRW, $Brush[$Color])
	_WinAPI_PatBlt($DRW, $X, $Y, $S, $GRID_S, $PATCOPY)
EndFunc
Func DrawHRow($DRW, $Row)
	Local $B = BoundBox($GridX, $GridY + ($Row-$GRID_H) * $GRID_S, $GRID_X*$GRID_S, $GRID_S)

	_WinAPI_SelectObject($BDC, $Blend[$CBKG])
	_WinAPI_AlphaBlend($DRW, $B[0], $B[1], $B[2], $B[3], $BDC, 0, 0, 1, 1, 96)
EndFunc

Func DrawNext($DRW)
	Local $Shape
	Local $Size = 14
	Local $Distance = 2.7857
	Local $B = $BUTTONS[$NEXTBUTTON][2]

	_WinAPI_SelectObject($DRW, $Font10)
	_WinAPI_SetBkMode   ($DRW, $TRANSPARENT)
	_WinAPI_SetTextColor($DRW, $Color[$CREV])

	_WinAPI_SelectObject($DRW, $Brush[0])
	_WinAPI_PatBlt($DRW, $B[0], $B[1], $B[2], $B[3], $PATCOPY)
	If $BUTTONS[$NEXTBUTTON][0] Then _WinAPI_FrameRect($DRW, Rect($B[0], $B[1], $B[2], $B[3]), $Brush[$CREV])
	_WinAPI_DrawText($DRW, 'NEXT', Rect($B[0] + 12, $B[1] + 10, 55, 20), $DT_LEFT)

	Local $X, $Y
	Local $i, $j, $k
	Local $S = (BagGetSeparator())[1]

	For $k = 1 To 6
		If $Bag[$k] = -1 Then ExitLoop

		If $k < 6 Then
		$Shape = PieceGetShape($Bag[$k], 0)

		;placement correction
		$X = ($Bag[$k] <> 0 And $Bag[$k] <> 3) ? $B[0]+10 + $Size/2 : $B[0]+10
		$Y = ($Bag[$k] == 0) ? $B[1] - $Size/2 : $B[1]
		$Y+= $Size*$Distance*$k

		For $i = 0 To UBound($Shape, 1) - 1
			For $j = 0 To UBound($Shape, 2) - 1
				If Not $Shape[$i][$j] Then ContinueLoop
				DrawMiniBlock($DRW, $X + $i*$Size, $Y + $j*$Size, $Size-$STYLE, $Bag[$k] + 1)
			Next
		Next
		EndIf

		;bag separator
		If $k = $S Then _WinAPI_FillRect($DRW, Rect($B[0]+5, $B[1] + $Size*$Distance*$k - $Size/2, $B[2]-10, 1), $Brush[$CREV])
	Next


	$B = $BUTTONS[$SHUFBUTTON][2]
	If $BUTTONS[$SHUFBUTTON][0] Then _WinAPI_FrameRect($DRW, Rect($B[0], $B[1], $B[2], $B[3]), $Brush[$CREV])

	_WinAPI_SelectObject($BDC, $ICONBMP)
	_WinAPI_BitBlt($DRW, $B[0]+1, $B[1]+1, 18, 18, $BDC, 0, 40, $SRCINVERT)
EndFunc   ;==>DrawNext
Func DrawHold($DRW)
	Local $Shape = PieceGetShape($PieceH, 0)
	Local $Size = 14
	Local $B = $BUTTONS[$HOLDBUTTON][2]

	_WinAPI_SelectObject($DRW, $Brush[0])
	_WinAPI_PatBlt($DRW, $B[0], $B[1], $B[2], $B[3], $PATCOPY)
	If $BUTTONS[$HOLDBUTTON][0] Then _WinAPI_FrameRect($DRW, Rect($B[0], $B[1], $B[2], $B[3]), $Brush[$CREV])
	_WinAPI_DrawText($DRW, 'HOLD', Rect($B[0] + 12, $B[1] + 10, 55, 20), $DT_LEFT)

	If $PieceH <> -1 Then
		Local $i, $j

		For $i = 0 To UBound($Shape, 1) - 1
			For $j = 0 To UBound($Shape, 2) - 1
				If Not $Shape[$i][$j] Then ContinueLoop
				DrawMiniBlock($DRW, $B[0]+10 + $i*$Size, $B[1]+35 + $j*$Size, $Size-$STYLE, $PieceH+1)
			Next
		Next
	EndIf

	If $Swapped Then
		_WinAPI_SelectObject($BDC, $Blend[0])
		_WinAPI_AlphaBlend($DRW, $B[0], $B[1], $B[2], $B[3], $BDC, 0, 0, 1, 1, 128)
	EndIf

	If $PieceH <> -1 Then
		$B = $BUTTONS[$HOLDDELETE][2]

		_WinAPI_SelectObject($BDC, $ICONBMP)
		_WinAPI_BitBlt($DRW, $B[0]+3, $B[1]+3, 14, 14, $BDC, 0, 59, $SRCINVERT)

		If $BUTTONS[$HOLDDELETE][0] Then _WinAPI_FrameRect($DRW, Rect($B[0], $B[1], $B[2], $B[3]), $Brush[$CREV])
	EndIf
EndFunc   ;==>DrawHold

Func DrawScore($DRW)
	Local $X
	Local $M = ($Moves > 0) ? $Moves : 1
	Local $APP = StringLeft(Round($Damage / $M, 4) + 1e-8, 6)
	If $APP < 1e-6 Then $APP = 0

	$X = $AlignL

	_WinAPI_FillRect($DRW, Rect($X, 10, 75, 140), $Brush[$CBOX])
	_WinAPI_SetTextColor($DRW, $Color[$CTXT])

	$X += 2
	_WinAPI_DrawText($DRW, 'CLEAR',  Rect($X + 10,  20, 55, 15), $DT_LEFT)
	_WinAPI_DrawText($DRW, 'ATTACK', Rect($X + 10,  50, 55, 15), $DT_LEFT)
	_WinAPI_DrawText($DRW, 'PIECES', Rect($X + 10,  80, 55, 15), $DT_LEFT)
	_WinAPI_DrawText($DRW, 'APP',    Rect($X + 10, 110, 55, 15), $DT_LEFT)
	_WinAPI_DrawText($DRW, StringRight('000000' & $Lines,  6), Rect($X + 10,  32, 55, 20), $DT_LEFT)
	_WinAPI_DrawText($DRW, StringRight('000000' & $Damage, 6), Rect($X + 10,  62, 55, 20), $DT_LEFT)
	_WinAPI_DrawText($DRW, StringRight('000000' & $Moves,  6), Rect($X + 10,  92, 55, 20), $DT_LEFT)
	_WinAPI_DrawText($DRW, StringRight('000000' & $APP,    6), Rect($X + 10, 122, 55, 20), $DT_LEFT)
EndFunc   ;==>DrawScore
Func DrawButtons($DRW)
	Local $B, $X

	_WinAPI_SelectObject($DRW, $Font9)
	_WinAPI_SetBkMode   ($DRW, $TRANSPARENT)
	_WinAPI_SetTextColor($DRW, $Color[$CTXT])

	For $i = 0 To UBound($BUTTONTEXT) - 1
		$B = $BUTTONS[$i][2]

		_WinAPI_FillRect($DRW, Rect($B[0], $B[1], $B[2], $B[3]), $Brush[$CBOX])
		If $BUTTONS[$i][0] Then _WinAPI_FrameRect($DRW, Rect($B[0], $B[1], $B[2], $B[3]), $Brush[$CTXT])

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

	_WinAPI_FillRect($DRW, Rect($B[0], $B[1], $B[2], $B[3]), $Brush[$CBOX])
	If $BUTTONS[$SNAPBUTTON][0] Then _WinAPI_FrameRect($DRW, Rect($B[0], $B[1], $B[2], $B[3]), $Brush[$CTXT])

	_WinAPI_SelectObject($BDC, $ICONBMP)
	_WinAPI_BitBlt($DRW, $B[0] + 8, $B[1] + 3, 58, 35, $BDC, 20, 0, $SRCINVERT)
EndFunc
Func DrawMirrorButton($DRW)
	Local $B = $BUTTONS[$MIRRBUTTON][2]

	_WinAPI_FillRect($DRW, Rect($B[0], $B[1], $B[2], $B[3]), $Brush[$CBOX])
	If $BUTTONS[$MIRRBUTTON][0] Then _WinAPI_FrameRect($DRW, Rect($B[0], $B[1], $B[2], $B[3]), $Brush[$CTXT])

	_WinAPI_SelectObject($BDC, $ICONBMP)
	_WinAPI_BitBlt($DRW, $B[0] + 8, $B[1] + 3, 58, 35, $BDC, 20, 36, $SRCINVERT)
EndFunc
Func DrawUndoButton($DRW)
	Local $X, $Y

	$X = $AlignR
	$Y = $AlignT + 250

	_WinAPI_FillRect($DRW, Rect($X,    $Y, 35, 35), $Brush[$CBOX])
	_WinAPI_FillRect($DRW, Rect($X+40, $Y, 35, 35), $Brush[$CBOX])
	If $BUTTONS[$UNDOBUTTON][0] Then _WinAPI_FrameRect($DRW, Rect($X,    $Y, 35, 35), $Brush[$CTXT])
	If $BUTTONS[$REDOBUTTON][0] Then _WinAPI_FrameRect($DRW, Rect($X+40, $Y, 35, 35), $Brush[$CTXT])

	_WinAPI_SelectObject($DRW, $Brush[5])
	_WinAPI_SelectObject($BDC, $ICONBMP)
	_WinAPI_BitBlt($DRW, $X+10, $Y+12, 16, 12, $BDC, 0, 0, $SRCINVERT)
	_WinAPI_BitBlt($DRW, $X+50, $Y+12, 16, 12, $BDC, 0,13, $SRCINVERT)

	_WinAPI_SelectObject($BDC, $Blend[$CBOX])
	If $UNDO_MAX = 0 Then _WinAPI_AlphaBlend($DRW, $X,    $Y, 36, 36, $BDC, 0, 0, 1, 1, 190)
	If $REDO_MAX = 0 Then _WinAPI_AlphaBlend($DRW, $X+40, $Y, 36, 36, $BDC, 0, 0, 1, 1, 190)
EndFunc
Func DrawPaintButtons($DRW)
	Local $B

	_WinAPI_FillRect ($DRW, Rect($AlignR, $AlignT + 295, 75, 100), $Brush[$CBOX])
	If $BUTTONS[$HILIBUTTON][0] Then _WinAPI_FrameRect($DRW, Rect($AlignR, $AlignT + 295, 75, 100), $Brush[$CTXT])
	_WinAPI_DrawText($DRW, 'COLOR', Rect($AlignR + 12, $AlignT + 305, 55, 20), $DT_LEFT)

	For $i = 0 To 7
		$B = $PAINT[$i][2]
		_WinAPI_FillRect($DRW, Rect($B[0], $B[1], $B[2], $B[3]), $Brush[$i+1])
	Next

	_WinAPI_SelectObject($BDC, $Blend[$CBOX])
	_WinAPI_AlphaBlend($DRW, $AlignR+10, $AlignT + 330, 55, 55, $BDC, 0, 0, 1, 1, 140)

	For $i = 0 To 7
		$B = $PAINT[$i][2]
		If $PAINT[$i][0] Then _WinAPI_FrameRect($DRW, Rect($B[0], $B[1], $B[2], $B[3]), $Brush[$CTXT])
	Next

	$B = $PAINT[$EditColor-1][2]
	_WinAPI_FillRect ($DRW, Rect($B[0], $B[1], $B[2], $B[3]), $Brush[$EditColor])
	_WinAPI_FrameRect($DRW, Rect($B[0]-1, $B[1]-1, $B[2]+2, $B[3]+2), $Brush[$CTXT])

	$B = $PAINT[8][2]

	_WinAPI_SelectObject($BDC, $ICONBMP)
	_WinAPI_BitBlt($DRW, $B[0]+1, $B[1]+1, 13, 13, $BDC, 0, 26, $SRCINVERT)
EndFunc
Func DrawHighlightButtons()
	_WinAPI_FillRect($DRW, Rect($AlignR, $AlignT + 295, 75, 35), $Brush[$CBOX])
	If $BUTTONS[$HILIBUTTON][0] Then _WinAPI_FrameRect($DRW, Rect($AlignR, $AlignT + 295, 75, 35), $Brush[$CTXT])
	_WinAPI_DrawText($DRW, 'H-LIGHT',  Rect($AlignR + 12, $AlignT + 305, 55, 20), $DT_LEFT)

	If $HighlightOn Then
		_WinAPI_FillRect($DRW, Rect($AlignR, $AlignT + 335, 75, 35), $Brush[$CBOX])
		If $BUTTONS[$HCLRBUTTON][0] Then _WinAPI_FrameRect($DRW, Rect($AlignR, $AlignT + 335, 75, 35), $Brush[$CTXT])
		_WinAPI_DrawText($DRW, ' CLEAR',  Rect($AlignR + 12, $AlignT + 345, 55, 20), $DT_LEFT)
	EndIf
EndFunc
Func DrawCheckboxes($DRW)
	$B = $BUTTONS[$HOLDCHECK][2]

	_WinAPI_DrawText($DRW, "INFINITE", Rect($B[0] + 16, $B[1] + 3, 55, 15), $DT_LEFT)
	_WinAPI_FrameRect($DRW, Rect($B[0] + 2, $B[1] + 4, 11, 11), $Brush[$CTXT])
	If $InfiniteSwaps = True Then _WinAPI_FillRect($DRW, Rect($B[0] + 4, $B[1] + 6,  7,  7), $Brush[8])

	If $HighlightMode Then Return

	$B = $BUTTONS[$ACOLCHECK][2]

	_WinAPI_DrawText($DRW, "AUTOCOLR", Rect($B[0] + 16, $B[1] + 3, 55, 15), $DT_LEFT)
	_WinAPI_FrameRect($DRW, Rect($B[0] + 2, $B[1] + 4, 11, 11), $Brush[$CTXT])
	If $AutoColor = True Then _WinAPI_FillRect($DRW, Rect($B[0] + 4, $B[1] + 6,  7,  7), $Brush[8])
EndFunc
Func DrawAttack($DRW)
	If $AttackText = '' Then Return

	Local $X = 10
	Local $Y = 310
	Local $Text[2] = [StringStripWS(StringLeft($AttackText, 6),7), _
					  StringStripWS(StringTrimLeft($AttackText, 6),7)]

	If $B2BText <> '' Then $Text[0] = 'B2B '&$Text[0]

	_WinAPI_DrawText($DRW, $Text[0], Rect($X,$Y,75,30), $DT_CENTER)
	_WinAPI_DrawText($DRW, $Text[1], Rect($X,$Y+11,75,30), $DT_CENTER)
EndFunc
Func DrawCombo($DRW)
	If $ClearCombo < 2 Then Return

	Local $X = 10
	Local $Y = 260

	_WinAPI_SelectObject($DRW, $Font20)
	_WinAPI_DrawText($DRW, 'x' & $ClearCombo - 1, Rect($X,$Y+10,75,30), $DT_CENTER)
EndFunc
Func DrawLose($DRW)
	If Not $Lost Then Return

	_WinAPI_SelectObject($DRW, $Font50)
	_WinAPI_SetBkMode($DRW, $TRANSPARENT)
	_WinAPI_SetTextColor($DRW, $Color[9])
	_WinAPI_DrawText($DRW, 'TOP OUT', Rect($GBounds[0]+5, $GBounds[1]+$GBounds[3]/2 - 31, $GBounds[2], $GBounds[3]), $DT_CENTER)
	_WinAPI_SetTextColor($DRW, $Color[$CREV])
	_WinAPI_DrawText($DRW, 'TOP OUT', Rect($GBounds[0], $GBounds[1]+$GBounds[3]/2 - 36, $GBounds[2], $GBounds[3]), $DT_CENTER)
EndFunc
Func DrawPerfect($DRW)
	If Not $Perfect Then Return

	_WinAPI_SelectObject($DRW, $Font30)
	_WinAPI_SetBkMode($DRW, $TRANSPARENT)
	_WinAPI_SetTextColor($DRW, $Color[6])
	_WinAPI_DrawText($DRW, 'PERFECT', Rect($GBounds[0], $GBounds[1]+$GBounds[3]/2-1, $GBounds[2], $GBounds[3]), $DT_CENTER)
	_WinAPI_SelectObject($DRW, $Font50)
	_WinAPI_DrawText($DRW, 'CLEAR', Rect($GBounds[0], $GBounds[1]+$GBounds[3]/2+25, $GBounds[2], $GBounds[3]), $DT_CENTER)
EndFunc

Func DrawSettings($DRW, $Render = True)
	If Not $ANIMATION_PLAYING And Not $CHG Then Return 0
	$CHG = False

	If $WSize[0] < 400 Then
		_WinAPI_FillRect($DRW, Rect(0, 0, $WSize[0], $SETTINGS_PANELSIZE), $Brush[$CBKG])
		DrawSeparators($DRW)
	Else
		_WinAPI_FillRect($DRW, Rect($WSize[0]/7,0, $WSize[0]*5/7, $SETTINGS_PANELSIZE), $Brush[$CBKG])
		DrawSeparators($DRW)
		DrawPieces($DRW)
	EndIf

	For $i = 0 To 12
		DrawButton($DRW, $i)
	Next

	DrawCheckbox($DRW, 13)
	DrawSlider($DRW, 14, $ARR/32)
	DrawSlider($DRW, 15, $DAS/256)
	DrawCheckbox($DRW, 16)
	DrawSlider($DRW, 24, $SDS/32)
	DrawSlider($DRW, 25, $SDD/256)
	DrawCheckbox($DRW, 17)
	DrawSlider($DRW, 19, $VOLUME/100)

	For $i = 20 To 23
		DrawButton($DRW, $i)
	Next
	DrawButton($DRW, 18)

	If $Render Then _WinAPI_BitBlt($GDI, 0, 0, $WSize[0], $SETTINGS_PANELSIZE, $DRW, 0, 0, $SRCCOPY)
EndFunc
Func DrawSeparators($DRW)
	_WinAPI_SelectObject($DRW, $Font30)
	_WinAPI_SetBkMode   ($DRW, $TRANSPARENT)
	_WinAPI_SetTextColor($DRW, BitXOR(0xFFFFFF,$Color[$CBKG]))

	For $i = 0 To UBound($SEPARATORS) - 1
		_WinAPI_DrawText($DRW, $SEPARATORS[$i][0], Rect($WSize[0]/7+5, $SEPARATORS[$i][1], 300, 34), $DT_LEFT)
		_WinAPI_FillRect($DRW, 					   Rect(0, $SEPARATORS[$i][1] + 34, $WSize[0], 3), $Brush[$CBOX])
	Next
EndFunc
Func DrawButton($DRW, $S)
	_WinAPI_SelectObject($DRW, $Font9)
	_WinAPI_SetBkMode   ($DRW, $TRANSPARENT)

	$B = $SETTINGS[$S][2]

	_WinAPI_FillRect($DRW, Rect($B[0], $B[1], $B[2], $B[3]), $Brush[$CBOX])
	If $SETTINGS[$S][0] Then _WinAPI_FrameRect($DRW, Rect($B[0], $B[1], $B[2], $B[3]), $Brush[$CTXT])

	_WinAPI_SetTextColor($DRW, $Color[$CTXT])
	_WinAPI_DrawText($DRW, $SETTINGS[$S][3], Rect($B[0], $B[1]+5, $B[2], $B[3]/2), $DT_CENTER)
	_WinAPI_SetTextColor($DRW, $Color[5])
	_WinAPI_DrawText($DRW, $SETTINGS[$S][4], Rect($B[0], $B[1]+$B[3]/2, $B[2], $B[3]/2), $DT_CENTER)
EndFunc
Func DrawSlider($DRW, $S, $V)
	_WinAPI_SelectObject($DRW, $Font9)
	_WinAPI_SetBkMode   ($DRW, $TRANSPARENT)

	$B = $SETTINGS[$S][2]
	If $V > 1 Then $V = 1
	If $V < 0 Then $V = 0

	_WinAPI_FillRect($DRW, Rect($B[0], $B[1], $B[2], $B[3]), $Brush[$CBOX])
	If $SETTINGS[$S][0] Then _WinAPI_FrameRect($DRW, Rect($B[0], $B[1], $B[2], $B[3]), $Brush[$CTXT])

	_WinAPI_SetTextColor($DRW, $Color[$CTXT])
	_WinAPI_DrawText($DRW, $SETTINGS[$S][3], Rect($B[0], $B[1]+5, $B[2], $B[3]/2), $DT_CENTER)

	_WinAPI_SetTextColor($DRW, $Color[5])
	_WinAPI_DrawText($DRW, $SETTINGS[$S][4], Rect($B[0], $B[1]+$B[3]/2, $B[2], $B[3]/2), $DT_CENTER)

	_WinAPI_FillRect($DRW, Rect($B[0], $B[1]+$B[3], $B[2], 3), $Brush[$CBKG])
	_WinAPI_FillRect($DRW, Rect($B[0], $B[1]+$B[3], $V*$B[2], 3), $Brush[5])
EndFunc
Func DrawCheckbox($DRW, $S)
	_WinAPI_SelectObject($DRW, $Font9)
	_WinAPI_SetBkMode   ($DRW, $TRANSPARENT)
	_WinAPI_SetTextColor($DRW, $Color[$CTXT])

	$B = $SETTINGS[$S][2]

	_WinAPI_FillRect ($DRW, Rect($B[0], $B[1], $B[2], $B[3]), $Brush[$CBKG])
	_WinAPI_DrawText ($DRW, $SETTINGS[$S][3], Rect($B[0] + 16, $B[1] + 3, $B[2], $B[3]), $DT_LEFT)
	_WinAPI_FrameRect($DRW, Rect($B[0] + 2, $B[1] + 4, 11, 11), $Brush[$CTXT])
	If $SETTINGS[$S][4] Then _WinAPI_FillRect($DRW, Rect($B[0] + 4, $B[1] + 6,  7,  7), $Brush[8])
EndFunc
Func DrawPieces($DRW)
	Local $Time = TimerDiff($GTimer)
	Local $Timings[7] = [1130, 0570, 2589, 0900, 0783, 0340, 1309]
	Local $Size = 14
	Local $Shape

	Local $X, $Y = 55 + $CURRENTVIEW/$SCALE

	_WinAPI_FillRect($DRW, Rect(0              ,0, $WSize[0]*(1/7),$SETTINGS_PANELSIZE), $Brush[0])
	_WinAPI_FillRect($DRW, Rect($WSize[0]*(6/7),0, $WSize[0]*(1/7),$SETTINGS_PANELSIZE), $Brush[0])

	For $k = 0 To 6
		$Shape = PieceGetShape($k, Mod(Floor($Time/$Timings[$k]), 4))

		For $i = 0 To UBound($Shape, 1) - 1
			For $j = 0 To UBound($Shape, 2) - 1
				If $Shape[$i][$j] Then
					$X = 14
					If $k = 0 Or $k = 3 Then $X = 8
					DrawMiniBlock($DRW, $X + $i*$Size, $Y + $j*$Size, $Size-$STYLE, $k+1)
					$X = $WSize[0] - 55
					If $k = 0 Or $k = 3 Then $X = $WSize[0] - 62
					DrawMiniBlock($DRW, $X + $i*$Size, $Y + $j*$Size, $Size-$STYLE, $k+1)
				EndIf
			Next
		Next
		$Y += ($WSize[1]-55)/7
	Next
EndFunc

Func DrawKeyCapture($STT)
	Local $B = $SETTINGS[$STT][2]
	_WinAPI_SelectObject($BDC, $Blend[$CBOX])
	_WinAPI_AlphaBlend($GDI, 0, 0, $B[0], $SETTINGS_PANELSIZE, $BDC, 0, 0, 1, 1, 128)
	_WinAPI_AlphaBlend($GDI, $B[0], 0, $B[2], $B[1], $BDC, 0, 0, 1, 1, 128)
	_WinAPI_AlphaBlend($GDI, $B[0]+$B[2], 0, $WSize[0], $SETTINGS_PANELSIZE, $BDC, 0, 0, 1, 1, 128)
	_WinAPI_AlphaBlend($GDI, $B[0], $B[1]+$B[3], $B[2], $SETTINGS_PANELSIZE, $BDC, 0, 0, 1, 1, 128)
EndFunc
Func DrawTransition($DRW, $Time)
	Local $Timer = TimerInit()
	Local $Y

	While TimerDiff($Timer) < $Time
		$Y = Floor($WSize[1] * (1 - TimerDiff($Timer)/$Time))

		_WinAPI_BitBlt($GDI, 0, $Y, $WSize[0], $WSize[1]-$Y, $DRW, 0, 0, $SRCCOPY)
	WEnd
EndFunc
Func DrawComment($DRW, $Time = 0, $Title = '', $Comment = '')
	Local $Timer

	If $Time <> 0 And ($Title <> '' Or $Comment <> '') Then
		$CommentInfo[0] = TimerDiff($GTimer)
		$CommentInfo[1] = $Time
		$CommentInfo[2] = $Title
		$CommentInfo[3] = $Comment

		$ANIMATION_PLAYING = True
		Return
	EndIf

	$Timer = TimerDiff($GTimer) - $CommentInfo[0]

	;if ended draw taller
	If $CommentInfo[4] Then
		_WinAPI_FillRect ($DRW, Rect(10, $AlignB, $WSize[0]-20, 20), $Brush[$CBOX])
		;_WinAPI_FrameRect($DRW, Rect(10, $AlignB, $WSize[0]-20, 20), $Brush[$CTXT])

		_WinAPI_SelectObject($DRW, $Font9)
		_WinAPI_SetBkColor  ($DRW, $Color[5])
		_WinAPI_SetTextColor($DRW, $Color[$CTXT])

		_WinAPI_DrawText($DRW, $CommentInfo[3], Rect(10, $AlignB, $WSize[0]-20, 20), $DT_CENTER)
	Else
		_WinAPI_FillRect ($DRW, Rect(10, $AlignB+10, $WSize[0]-20, 20), $Brush[$CBOX])
		;_WinAPI_FrameRect($DRW, Rect(10, $AlignB+10, $WSize[0]-20, 20), $Brush[$CTXT])
	EndIf


	If $Timer < $CommentInfo[1] Then
		Local $X, $Y
		Local $T

		$T = ($CommentInfo[1] - $Timer) / $CommentInfo[1]
		$Y = $WSize[1]/7 * Popup($T)
		$X = 4

		If $T < 0.5 Then $CommentInfo[4] = True

		_WinAPI_FillRect ($DRW, Rect(10, $WSize[1]-$Y, $WSize[0]-20, $Y+0), $Brush[$CBOX])
		_WinAPI_FrameRect($DRW, Rect(10, $WSize[1]-$Y, $WSize[0]-20, $Y+5), $Brush[$CTXT])

		_WinAPI_SelectObject($DRW, $Font30)
		_WinAPI_SetBkColor  ($DRW, $Color[5])
		_WinAPI_SetTextColor($DRW, $Color[$CTXT])
		_WinAPI_DrawText($DRW, $CommentInfo[2], Rect(10, $WSize[1]-$Y + $X, $WSize[0]-20, 55), $DT_CENTER)

		$X += $CommentInfo[2] = '' ? 14 : 53

		_WinAPI_SelectObject($DRW, $Font20)
		_WinAPI_DrawText($DRW, $CommentInfo[3], Rect(10, $WSize[1]-$Y + $X, $WSize[0]-20, $Y), $DT_CENTER)
	Else
		$ANIMATION_PLAYING = False
	EndIf
EndFunc
Func DeleteComment()
	$CommentInfo[0] = 0
	$CommentInfo[1] = 0
	$CommentInfo[2] = ''
	$CommentInfo[3] = ''
	$CommentInfo[4] = False

	$ANIMATION_PLAYING = False
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
		Case 'move'
			_BASS_ChannelPlay($Sound[0][2], True)
		Case 'rotate'
			_BASS_ChannelPlay($Sound[1][2], True)
		Case 'drop'
			_BASS_ChannelPlay($Sound[2][2], True)
		Case 'hold'
			_BASS_ChannelPlay($Sound[3][2], True)
		Case 'kick'
			_BASS_ChannelPlay($Sound[4][2], True)
		Case 'clear'
			_BASS_ChannelPlay($Sound[5][2], True)
		Case 'tetris'
			_BASS_ChannelPlay($Sound[6][2], True)
		Case 'tspin'
			_BASS_ChannelPlay($Sound[7][2], True)
		Case 'b2b', 'btb'
			_BASS_ChannelPlay($Sound[8][2], True)
		Case 'fall'
			_BASS_ChannelPlay($Sound[9][2], True)
		Case 'lose'
			_BASS_ChannelPlay($Sound[10][2], True)
	EndSwitch

EndFunc


Func SaveState()
	Local $SaveState[10]

	$SaveState[0] = $Damage
	$SaveState[1] = $Lines
	$SaveState[2] = $Moves
	$SaveState[3] = $PieceH
	$SaveState[4] = $Swapped
	$SaveState[5] = $BtB
	$SaveState[6] = $ClearCombo
	$SaveState[7] = $BagSeed
	$SaveState[8] = __MemCopy($GRID)
	$SaveState[9] = __MemCopy($Bag)

	Return $SaveState
EndFunc
Func LoadState($SaveState)
	If UBound($SaveState) < 10 Then Return 0

	StatsReset()
	$Damage		= $SaveState[0]
	$Lines		= $SaveState[1]
	$Moves		= $SaveState[2]
	$PieceH		= $SaveState[3]
	$Swapped	= $SaveState[4]
	$BtB		= $SaveState[5]
	$ClearCombo	= $SaveState[6]
	$BagSeed    = $SaveState[7]
	$GRID 		= __MemCopy($SaveState[8])
	$Bag		= __MemCopy($SaveState[9])
	PieceReset()

	$CHG		= True
	$Lost       = False
	$Perfect    = False
	$AttackText = ''
EndFunc

Func StateEncode()
	Local $Title     = '' ;unused
	Local $Comment   = '' ;unused
	Local $QueueData = ''
	Local $BoardData = ''

	$QueueData = '[' & __QueueEncode() ;4 bits per piece + 16 bits (bag seed)
	$BoardData = '[' & __BoardEncode() ;4 bits per block, compressed

	Return $QueueData&$BoardData
EndFunc
Func StateDecode($Data)
	Local $Title     = ''
	Local $Comment   = ''
	Local $QueueData = ''
	Local $BoardData = ''

	;strip whitespace later becuse we want to read comment first
	$Data = StringSplit  ($Data, '[')
	If $Data[0] > 0 Then $Comment   = StringStripWS($Data[1], 7)
	If $Data[0] > 1 Then $QueueData = StringStripWS($Data[2], 8)
	If $Data[0] > 2 Then $BoardData = StringStripWS($Data[3], 8)

	;decode and decompress the data
	$QueueData = __QueueDecode($QueueData)
	If Not IsArray($QueueData) Then Return False
	$BoardData = __BoardDecode($BoardData)
	If Not IsArray($BoardData) Then Return False

	;we now divide the info into title and comment
	$Comment = StringReplace($Comment, @CR, '')
	$Comment = StringReplace($Comment, @LF, '')
	$Comment = StringSplit  ($Comment, '|')
	If $Comment[0] > 1 Then
		$Title   = StringLeft($Comment[1], 19)
		$Comment = StringLeft($Comment[2], 33)
	ElseIf $Comment[1] <> '' Then
		$Comment = StringLeft($Comment[1], 33) & @LF & _
				   StringMid ($Comment[1], 34, 33)
	Else
		$Comment = ''
	EndIf

	StatsReset()
	PieceReset()
	$BagSeed = $QueueData[0]
	$PieceH  = $QueueData[1]
	$Bag     = $QueueData[2]
	$GRID    = $BoardData
	DrawComment(0, 2000, $Title, $Comment)
	$CHG = True

	Return True
EndFunc

Func __QueueEncode()
	Local $S = ''

	$S &= Hex($BagSeed, 4)
	$S &= Hex($PieceH, 1)
	For $i = 0 To UBound($Bag) - 1
		$S &= Hex($Bag[$i], 1)
	Next

	If Mod(StringLen($S), 2) Then $S &= 'E'
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
	$Queue = StringRight($Queue, 1) = 'E' ? StringTrimRight($Queue, 1) : $Queue
	$Queue = StringSplit($Queue, '', 2)

	;check data is correct lengths
	If StringLen($Seed) <> 4 Then Return
	If StringLen($Hold) <> 1 Then Return

	;conversts values to decimal
	$Seed  = Dec($Seed)
	$Hold  = Dec($Hold)
	For $i = 0 To UBound($Queue) - 1
		$Queue[$i] = Dec($Queue[$i])
	Next

	;normalizes
	If $Hold = 15 Then $Hold = -1
	If $Hold > 7  Then $Hold = 7
	For $i = 0 To UBound($Queue) - 1
		If $Queue[$i] = 15 Then $Queue[$i] = -1
		If $Queue[$i] > 7  Then $Queue[$i] = 7
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
	If StateDecode(ClipGet()) Then
		If $ShuffleBag Then
			If $ShuffleHold Then HoldShuffle()
			BagShuffle()
			BagReseed()
		EndIf

	;StateDecode() Failed, Clipboard contains BMP?
	ElseIf _ClipBoard_IsFormatAvailable($CF_BITMAP) Then

		If _ClipBoard_Open($GUI) Then
			$Snap = _ClipBoard_GetDataEx($CF_BITMAP)
			If $Snap <> 0 Then FillBoardFromBitmap($Snap)

			_ClipBoard_Close()
		EndIf
	EndIf
EndFunc
Func Undo()
	If $UNDO_MAX = 0 Then Return
	If $REDO_MAX = 0 Then NewRedo()
	$UNDO_MAX  -= 1
	$REDO_MAX  += 1
	$UNDO_INDEX = Mod($UNDO_INDEX + UBound($UNDO) - 1, UBound($UNDO))

	LoadState($UNDO[$UNDO_INDEX])
EndFunc
Func Redo()
	If $REDO_MAX = 0 Then Return
	$UNDO_MAX  += 1
	$REDO_MAX  -= 1
	$UNDO_INDEX = Mod($UNDO_INDEX + 1, UBound($UNDO))

	LoadState($UNDO[$UNDO_INDEX])
EndFunc
Func NewUndo()
	$UNDO[$UNDO_INDEX] = SaveState()

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


Func SnapScreen()
	Local $Screen, $ScreenDC
	Local $HSnap, $Snap
	Local $DISPLAY, $DRW, $BUF, $GDI
	Local $Brush, $Blend

	Local $tPos    = _WinAPI_GetMousePos()
	Local $Monitor = _WinAPI_MonitorFromPoint($tPos)
	Local $Info    = (_WinAPI_GetMonitorInfo($Monitor))[0]
	Local $Size[4]
	$Size[0] = DllStructGetData($Info, 1)
	$Size[1] = DllStructGetData($Info, 2)
	$Size[2] = DllStructGetData($Info, 3)
	$Size[3] = DllStructGetData($Info, 4)
	Local $Bounds = BoundBox($Size[0], $Size[1], $Size[2]-$Size[0], $Size[3]-$Size[1])

	Local $W = $Size[2] - $Size[0]
	Local $H = $Size[3] - $Size[1]
	Local $Top, $Left

	$Screen   = _ScreenCapture_Capture('', $Size[0], $Size[1], $Size[2]-1, $Size[3]-1, False)
	$ScreenDC = _WinAPI_CreateCompatibleDC(0)

	$DISPLAY = GUICreate('', $W, $H, $Size[0], $Size[1], 0x90000000)
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

					$HSnap = _ScreenCapture_Capture('', $Left+$Size[0], _
														$Top +$Size[1], _
														$Left+$Size[0] + Abs($Pos[2]-$Pos[0]), _
														$Top +$Size[1] + Abs($Pos[3]-$Pos[1]), False)
					ExitLoop
				EndIf
		EndSwitch

		If Not Bounds(MouseGetPos(), $Bounds) Then
			$tPos    = _WinAPI_GetMousePos()
			$Monitor = _WinAPI_MonitorFromPoint($tPos)
			$Info    = (_WinAPI_GetMonitorInfo($Monitor))[0]
			$Size[0] = DllStructGetData($Info, 1)
			$Size[1] = DllStructGetData($Info, 2)
			$Size[2] = DllStructGetData($Info, 3)
			$Size[3] = DllStructGetData($Info, 4)
			$Bounds  = BoundBox($Size[0], $Size[1], $Size[2]-$Size[0], $Size[3]-$Size[1])

			$W = $Size[2] - $Size[0]
			$H = $Size[3] - $Size[1]

			_WinAPI_DeleteObject($Screen)
			$Screen  = _ScreenCapture_Capture('', $Size[0], $Size[1], $Size[2]-1, $Size[3]-1, False)


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


Func _FumenValueEncode($value, $encodeNum)
	;~ 64 characters
	Local $FumenDict[64] = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '+', '/']
	Local $temp = $FumenDict[Mod($value, 64)] 
	For $i = 1 To $encodeNum - 1
		$value = Int($value/64)
		$temp &= $FumenDict[Mod($value, 64)]
	Next
	Return $temp
EndFunc

Func Fumen()
	Local $FumenEncode = ""
	Local $FumenUrl = "https://fumen.zui.jp/?v115@"
	;~ space, I, J, S, O, Z, L, T, garbage
	Local $ColorToFumenColor = [0, 1, 6, 7, 3, 4, 2, 5, 8]

	;~ board encoding
	Local $curColor = 0
	Local $curStart = 0
	Local $curEnd = -1
	For $j = 1 To UBound($GRID, 2) - 1
		For $i = 0 To UBound($GRID, 1) - 1
			$thisColor = $ColorToFumenColor[$GRID[$i][$j]]
			If $thisColor <> $curColor Then
				Local $cnt = $curEnd - $curStart
				If $cnt >= 0 Then
					Local $val = ($curColor + 8) * 240 + $cnt
					$FumenEncode &= _FumenValueEncode($val, 2)
				EndIf
				$curColor = $thisColor
				$curStart = $curEnd+1
			EndIf
			$curEnd += 1
		Next
	Next
	if $curColor = 0 Then
		$curEnd += 10
	Else
		Local $cnt = $curEnd - $curStart
		Local $val = ($curColor + 8) * 240 + $cnt
		$FumenEncode &= _FumenValueEncode($val, 2)
		$curColor = 0
		$curStart = $curEnd+1
		$curEnd += 10
	EndIf
	Local $cnt = $curEnd - $curStart
	Local $val = ($curColor + 8) * 240 + $cnt
	$FumenEncode &= _FumenValueEncode($val, 2)

	if $FumenEncode = "vh" Then
		$FumenEncode &= "A"
	EndIf

	;~ flag encoding
	;~ piece = none, rotation = 0, location = 0, raise = 0, mirror = 0, color = 1, comment = 1, lock = !1
	Local $FumenFlagParam = [1, 8, 32, 7680, 15360, 30720, 61440, 122880]
	;~ Local $FumenFlagValue = 0*$FumenFlagParam[0] + 0*$FumenFlagParam[1] + 0*$FumenFlagParam[2] + 0*$FumenFlagParam[3] + 0*$FumenFlagParam[4] + 1*$FumenFlagParam[5] + 0*$FumenFlagParam[6] + 0*$FumenFlagParam[7]
	Local $FumenFlagValue = 1*$FumenFlagParam[5] + 1*$FumenFlagParam[6]
	$FumenEncode &= _FumenValueEncode($FumenFlagValue, 3)
	;~ queue encoding
	;~ #Q=[]()
	;~ # = 3, Q = 49, = = 29, [ = 59, ] = 61, ( = 8, ) = 9
	Local $QueueCommentLenth = 7 + UBound($Bag)
	If $PieceH <> -1 Then
		$QueueCommentLenth += 1
	EndIf
	$FumenEncode &= _FumenValueEncode($QueueCommentLenth, 2)
	;~ I, J, S, O, Z, L, T
	Local $CaptionDict = [41, 42, 51, 47, 58, 44, 52]
	Local $QueueInVal[$QueueCommentLenth]
	Local $QueueIdx
	$QueueInVal[0] = 3
	$QueueInVal[1] = 49
	$QueueInVal[2] = 29
	$QueueInVal[3] = 59
	If $PieceH <> -1 Then
		$QueueInVal[4] = $CaptionDict[$PieceH]
		$QueueInVal[5] = 61
		$QueueIdx = 6
	Else
		$QueueInVal[4] = 61
		$QueueIdx = 5
	EndIf
	$QueueInVal[$QueueIdx] = 8
	$QueueInVal[$QueueIdx+1] = $CaptionDict[$Bag[0]]
	$QueueInVal[$QueueIdx+2] = 9
	$QueueIdx += 3
	For $i = 1 To UBound($Bag) - 1
		$QueueInVal[$QueueIdx] = $CaptionDict[$Bag[$i]]
		$QueueIdx += 1
	Next

	Local $QueueVal = 0
	Local $CaptionParam = [1, 96, 9216, 884736]
	For $i = 0 To $QueueCommentLenth-1
		Local $param = $CaptionParam[Mod($i,4)]
		$QueueVal += $QueueInVal[$i] * $param
		If Mod($i, 4) = 3 Then
			$FumenEncode &= _FumenValueEncode($QueueVal, 5)
			$QueueVal = 0
		EndIf
	Next
	If $QueueVal > 0 Then
		$FumenEncode &= _FumenValueEncode($QueueVal, 5)
	EndIf
	ShellExecute($FumenUrl & $FumenEncode)
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

			If $HSV[2] > 20 Then
				If $HSV[1] < 20 Then
					$GRID[$i][$j+$k] = 8
				Else
					Switch $HSV[0]
						Case 0 To 15, 345 To 360 ;red
							$GRID[$i][$j+$k] = 5
						Case 15 To 27 ;orange
							$GRID[$i][$j+$k] = 6
						Case 27 To 75 ;yellow
							$GRID[$i][$j+$k] = 4
						Case 75 To 150 ;green
							$GRID[$i][$j+$k] = 3
						Case 150 To 210 ;cyan
							$GRID[$i][$j+$k] = 1
						Case 210 To 270 ;blue
							$GRID[$i][$j+$k] = 2
						Case 270 To 330 ;magenta
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
	Local Static $tSDS = 0

	If Not $KEYBINDS[0][$KEYSTATE] And Not $KEYBINDS[1][$KEYSTATE] Then $DAS_DIR = ''
	If $DAS_DIR = 'L' Then
		If $KEYBINDS[0][$KEYSTATE] Then
			While $KEYBINDS[0][$KEYTIME] + $DAS + $tARR < _WinAPI_GetTickCount()
				If Not PieceMove(0,-1,0) Then ExitLoop
				$tARR += $ARR
				If $ARR > 15 Then Sound('move')
			WEnd
		EndIf

		If Not $KEYBINDS[0][$KEYSTATE] And $KEYBINDS[1][$KEYSTATE] Then
			$KEYBINDS[1][$KEYTIME] = $KEYBINDS[0][$KEYTIME]
			$DAS_DIR = 'R'
			$tARR = 0
		EndIf

	ElseIf $DAS_DIR = 'R' Then
		If $KEYBINDS[1][$KEYSTATE] Then
			While $KEYBINDS[1][$KEYTIME] + $DAS + $tARR < _WinAPI_GetTickCount()
				If Not PieceMove(0,+1,0) Then ExitLoop
				$tARR += $ARR
				If $ARR > 15 Then Sound('move')
			WEnd
		EndIf

		If Not $KEYBINDS[1][$KEYSTATE] And $KEYBINDS[0][$KEYSTATE] Then
			$KEYBINDS[0][$KEYTIME] = $KEYBINDS[1][$KEYTIME]
			$DAS_DIR = 'L'
			$tARR = 0
		EndIf
	EndIf

	If Not $KEYBINDS[2][$KEYSTATE] Then $tSDS = 0
	If $KEYBINDS[2][$KEYSTATE] Then
		While $KEYBINDS[2][$KEYTIME] + $SDD + $tSDS < _WinAPI_GetTickCount()
			If Not PieceMove(0,0,+1) Then ExitLoop
			$tSDS += $SDS
		WEnd
	EndIf

EndFunc   ;==>GameInput
Func RotateCCW()
	If $Lost Then Return
	Return PieceMove(1, 0, 0)
EndFunc   ;==>RotateL
Func RotateCW()
	If $Lost Then Return
	Return PieceMove(3, 0, 0)
EndFunc   ;==>RotateR
Func Rotate180()
	If $Lost Then Return
	Return PieceMove(2, 0, 0)
EndFunc
Func MoveL()
	If $Lost Then Return
	Sound('move')

	$tARR = 0
	If $DasCancel Or Not $KEYBINDS[1][$KEYSTATE] Then
		$DAS_DIR = 'L'
	Else
		$DAS_DIR = ''
	EndIf

	Return PieceMove(0, -1, 0)
EndFunc
Func MoveR()
	If $Lost Then Return
	Sound('move')

	$tARR = 0
	If $DasCancel Or Not $KEYBINDS[0][$KEYSTATE] Then
		$DAS_DIR = 'R'
	Else
		$DAS_DIR = ''
	EndIf

	Return PieceMove(0, +1, 0)
EndFunc
Func MoveD()
	If $Lost Then Return

	$tSDS = 0

	Return PieceMove(0, 0, +1)
EndFunc
Func MoveU()
	If $Lost Then Return
	Return PieceMove(0, 0, -1)
EndFunc
Func Drop()
	If $Lost Then Return

	Do
	Until Not PieceMove(0, 0, +1)

	NewUndo()
	Sound('drop')
	$Moves += 1

	PieceFreeze($GRID, BagGetPiece(), $PieceA, $PieceX, $PieceY)
	CheckLines()

	PieceNext()
EndFunc
Func Tick()
	Return PieceMove(0, 0, +1)
EndFunc   ;==>Tick


Func BagSet()
	SetHotkeys(1)
	$KEYACTIVE = False

	Local $W, $Q = ''
	For $i = 0 To UBound($Bag) - 1
		$Q &= PieceGetName($Bag[$i])
	Next

	$W = WinGetPos($GUI)
	$Q = InputBox($WTITLE, 'Set the queue (TLJZSOI)', $Q, '', 250, 130, $W[0]+$W[2]/2-125, $W[1]+$W[3]/2-65, 0, $GUI)
	If @error Then Return

	BagLoadFromString($Q)
EndFunc
Func BagLoadFromString($Q)
	$Q = StringStripWS($Q, 8)
	$Q = StringSplit  ($Q, '', 2)

	For $i = 0 To UBound($Q) - 1
		$Q[$i] = PieceGetID($Q[$i])
	Next
	$Bag = $Q
	$CHG = True

	PieceReset()
EndFunc
Func BagFill()
	Local $Fill

	While UBound($Bag) < 7
		$Fill = __MemCopy($BagPieces)

		BagSeed()
		Switch $BagType
			Case 0 ;7-Bag
				For $i = 0 To UBound($Fill) - 1
					__Swap($Fill[$i], $Fill[Random($i, UBound($Fill) - 1, 1)])
				Next

			Case 1 ;14-Bag
				__Concat($Fill, $BagPieces)
				For $i = 0 To UBound($Fill) - 1
					__Swap($Fill[$i], $Fill[Random($i, UBound($Fill) - 1, 1)])
				Next

			Case 2 ;Random-Bag
				For $i = 0 To UBound($Fill) - 1
					$Fill[$i] = $BagPieces[Random(0, UBound($BagPieces) - 1, 1)]
				Next
		EndSwitch
		BagReseed()

		__Concat($Bag, $Fill)
	WEnd

EndFunc
Func BagNext()
	BagFill()

	If $Bag[1] = -1 Then
		If $PieceH = -1 Then
			_ArrayDelete($Bag, 0)
			_ArrayDelete($Bag, 0)
		Else
			__Swap($PieceH, $Bag[0])
			$PieceH = -1
		EndIf
	Else
		_ArrayDelete($Bag, 0)
	EndIf
EndFunc
Func BagGetPiece()
	BagFill()
	Return $Bag[0]
EndFunc
Func BagGetSeparator()
	Local $BagCount = Mod(UBound($Bag), ($BagType+1)*7)
	Local $BagSeparator = '0'

	While $BagCount <= UBound($Bag)
		$BagSeparator &= '|' & $BagCount
		$BagCount += ($BagType+1)*7
	WEnd

	Return StringSplit($BagSeparator, '|', 2)
EndFunc
Func BagShuffle()
	Local $BagSeparator = BagGetSeparator()

	For $k = 1 To UBound($BagSeparator) - 1
		For $i = $BagSeparator[$k-1] To $BagSeparator[$k] - 1
			__Swap($Bag[$i], $Bag[Random($i, $BagSeparator[$k] - 1, 1)])
		Next
	Next

	$CHG = True
EndFunc
Func BagMirror()
	Local $Mirror = __MemCopy($Bag)
	Local $LOOKUP[7] = [0, 5, 4, 3, 2, 1, 6]

	For $i = 0 To UBound($Bag) - 1
		If $Bag[$i] < 0 Or $Bag[$i] > 6 Then ContinueLoop
		$Mirror[$i] = $LOOKUP[$Bag[$i]]
	Next

	$Bag = $Mirror
	$CHG = True
EndFunc
Func BagReset()
	$Bag = 0
	If $StaticBag Then
		BagLoadFromString(FileRead('piece_list.txt'))
	EndIf

	BagFill()
EndFunc
Func BagSeed()
	SRandom($BagSeed)
EndFunc
Func BagReseed()
	$BagSeed = Random(0, 65535, 1)
EndFunc


Func PCSetLeftover($Leftover)
	If $GAMEMODE <> $GM_PC Then Return

	Local $PCSizes[7] = [7,4,1,5,2,6,3]
	Local $Comment

	$PCLeftover = $PCSizes[$Leftover-1]
	Switch $Leftover
		Case 1
			$Comment = '1st'
		Case 2
			$Comment = '2nd'
		Case 3
			$Comment = '3rd'
		Case Else
			$Comment = $Leftover&'th.'
	EndSwitch

	DrawComment(0, 1000, $Comment&' PC', 'Bag leftover: '&$PCLeftover&' piece' & (($PCLeftover = 1)?'.':'s.'))
	clear_board()
EndFunc
Func PCSetBag($Leftover)
	Local $Fill

	Do
		$Fill = __MemCopy($BagPieces)
		For $i = 0 To UBound($Fill) - 1
			__Swap($Fill[$i], $Fill[Random($i, UBound($Fill) - 1, 1)])
		Next
		ReDim $Fill[$Leftover]
	Until Not PCRerollBag($Fill)

	$Bag = $Fill
	$CHG = True

	HoldReset()
	BagFill()
EndFunc
Func PCRerollBag(ByRef $Bag)
	If UBound($Bag) <> 4 Then Return False
	Local $P[7]

	For $i = 0 To UBound($Bag) - 1
		$P[$Bag[$i]] = 1
	Next

	Return ($P[1] And $P[5] And $P[6]); has [J,L,T]
EndFunc


Func HoldSet()
	SetHotkeys(1)
	$KEYACTIVE = False

	Local $W, $Q

	$Q = PieceGetName($PieceH)

	$W = WinGetPos($GUI)
	$Q = InputBox($WTITLE, 'Set the hold piece. (TLJZSOI)', $Q, '', 250, 130, $W[0]+$W[2]/2-125, $W[1]+$W[3]/2-65, 0, $GUI)
	If @error Then Return

	$Q = StringStripWS($Q, 8)
	$Q = StringLeft   ($Q, 1)
	If $Q = '' Then
		$PieceH = -1 ;empty hold
	Else
		$PieceH = PieceGetID($Q)
	EndIf

	$Swapped = False
	$CHG = True
EndFunc
Func HoldReset()
	$Swapped = False
	$PieceH = -1
	$CHG = True
EndFunc
Func HoldModeToggle()
	$InfiniteSwaps = $InfiniteSwaps ? False : True
	If $InfiniteSwaps Then $Swapped = False

	IniWrite('settings.ini', 'SETTINGS', 'INFINITE_HOLD', $InfiniteSwaps)

	$CHG = True
EndFunc
Func HoldMirror()
	Local $LOOKUP[7] = [0, 5, 4, 3, 2, 1, 6]
	If $PieceH >= 0 And $PieceH < UBound($LOOKUP) Then $PieceH = $LOOKUP[$PieceH]
EndFunc
Func HoldShuffle()
	Local $BagSeparator

	If $PieceH <> -1 Then
		$BagSeparator = BagGetSeparator()
		__Swap($PieceH, $Bag[Random($BagSeparator[0], $BagSeparator[1] - 1, 1)])
	EndIf

	$CHG = True
EndFunc


Func PieceReset()
	$PieceX = Floor(UBound($GRID)/2) - 2
	$PieceY = $GRID_H-2
	$PieceA = 0

	$tSpin    = False

	;resets all timers so that the piece will not teleport around
	$KEYBINDS[0][$KEYTIME] = _WinAPI_GetTickCount() - $DAS
	$KEYBINDS[1][$KEYTIME] = _WinAPI_GetTickCount() - $DAS
	$KEYBINDS[2][$KEYTIME] = _WinAPI_GetTickCount() - $SDD
	$tGravity = TimerDiff($GTimer) + (1000 / $Gravity)
	$tARR = 0
	$tSDS = 0

	$CHG = True
EndFunc   ;==>PieceReset
Func PieceNext()
	BagNext()
	PieceReset()

	$Swapped = False
	$CHG = True

	If Not PieceFits(BagGetPiece(), $PieceA, $PieceX, $PieceY) Then Return lose_game()
EndFunc
Func PieceHold()
	If $Swapped Or $Lost Then Return

	PieceReset()
	If $PieceH = -1 Then
		$PieceH = BagGetPiece()
		PieceNext()
	Else
		__Swap($Bag[0], $PieceH)
	EndIf

	If Not $InfiniteSwaps = True Then $Swapped = True
	$CHG = True

	Sound('hold')

	If Not PieceFits(BagGetPiece(), $PieceA, $PieceX, $PieceY) Then Return lose_game()
EndFunc   ;==>PieceHold


Func StatsReset()
	$Damage  = 0
	$Lines   = 0
	$Moves   = 0
	$BtB     = False
	$Perfect = False
	$Swapped = False
	$Lost    = False
	$ClearCombo = 0

	$B2BText    = ''
	$AttackText = ''
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
	Local $GarbageAmount = GridGetGarbageLevel()
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

		GridAddGarbageLine($HolePos)
	Next

	$HoleSize = $HoleChange - $i
	$CHG = True
EndFunc
Func GridAddGarbageLine($HolePos)
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
Func GridGetGarbageLevel()
	Local $i, $j
	For $j = 0 To UBound($GRID, 2) - 1
		For $i = 0 To UBound($GRID, 1) - 1
			If $GRID[$i][$j] = 8 Then Return UBound($GRID, 2) -$j
		Next
	Next
	Return 0
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
Func GridClearFullLines()
	Local $i, $j
	Local $Full
	Local $Save = True

	For $j = 0 To UBound($GRID, 2) - 1
		$Full = True
		For $i = 0 To UBound($GRID, 1) - 1
			If Not $GRID[$i][$j] Then $Full = False
		Next

		If $Full Then
			If $Save Then
				NewUndo()
				$Save = False
			EndIf

			ClearLine($GRID, $j)
			If $HighlightClear Then ClearLine($HLIGHT, $j)
		EndIf
	Next

	$CHG = True
EndFunc
Func GridShift($Direction)
	;shift down
	While $Direction < 0
		ClearLine($GRID, UBound($GRID, 2) - 1)
		$Direction += 1
	WEnd

	;shift up
	While $Direction > 0
		PushLine($GRID, UBound($GRID, 2) - 1)
		$Direction -= 1
	WEnd

	$CHG = True
EndFunc
Func GridRoll($Direction)
	Local $Mem = __MemCopy($GRID)

	;shift right
	While $Direction < 0
		For $i = 0 To UBound($Mem, 1) - 1
			For $j = 0 To UBound($Mem, 2) - 1
				$GRID[$i][$j] = $Mem[Mod($i+UBound($Mem, 1)-1, UBound($Mem, 1))][$j]
			Next
		Next
		$Direction += 1
	WEnd

	;shift left
	While $Direction > 0
		For $i = 0 To UBound($Mem, 1) - 1
			For $j = 0 To UBound($Mem, 2) - 1
				$GRID[$i][$j] = $Mem[Mod($i+1, UBound($Mem, 1))][$j]
			Next
		Next
		$Direction -= 1
	WEnd

	$CHG = True
EndFunc
Func GridMirror()
	NewUndo()

	Local $Mirror = __MemCopy($GRID)
	Local $LOOKUP[9] = [0,1,6,5,4,3,2,7,8]

	For $i = 0 To UBound($GRID, 1) - 1
		For $j = 0 To UBound($GRID, 2) - 1
			$Mirror[UBound($GRID, 1) - 1 - $i][$j] = $LOOKUP[$GRID[$i][$j]]
		Next
	Next

	$GRID = $Mirror
	$CHG = True

	If $MirrorQueue Then
		BagMirror()
		HoldMirror()
	EndIf
EndFunc


Func HighlightReset()
	For $i = 0 To UBound($HLIGHT, 1) - 1
		For $j = 0 To UBound($HLIGHT, 2) - 1
			$HLIGHT[$i][$j] = 0
		Next
	Next
	$HighlightOn = False
	$CHG = True
EndFunc
Func HighlightClear($Color)
	For $i = 0 To UBound($HLIGHT, 1) - 1
		For $j = 0 To UBound($HLIGHT, 2) - 1
			If $HLIGHT[$i][$j] = $Color Then $HLIGHT[$i][$j] = 0
		Next
	Next
	$CHG = True
EndFunc
Func HighlightModeToggle()
	$HighlightMode = $HighlightMode ? False : True
	$CHG = True
EndFunc


Func clear_board()
	BagReset()
	HoldReset()
	GridReset()
	StatsReset()
	PieceReset()

	Switch $GAMEMODE
		Case $GM_TRAINING	;training mode
		Case $GM_CHEESE 	;cheese mode
			GridSpawnGarbage()
		Case $GM_FOUR		;4wide mode
			GridSpawn4W()
		Case $GM_MASTER		;master mode
		Case $GM_PC			;pc training
			PCSetBag($PCLeftover)
	EndSwitch
EndFunc   ;==>clear_board
Func lose_game()
	FillColor($GRID, 8)
	$Lost = True

	Sound('lose')
EndFunc

Func CheckTSpin()
	If BagGetPiece() <> 6 Then Return False ;Not a T piece

	Local $Block = 0

	$Block += BlockIsFull($GRID, $PieceX + 0, $PieceY + 0) ? 1 : 0
	$Block += BlockIsFull($GRID, $PieceX + 2, $PieceY + 0) ? 1 : 0
	$Block += BlockIsFull($GRID, $PieceX + 0, $PieceY + 2) ? 1 : 0
	$Block += BlockIsFull($GRID, $PieceX + 2, $PieceY + 2) ? 1 : 0

	Return $Block >= 3 ? True : False
EndFunc   ;==>CheckTSpin
Func CheckMini()
	If $tSpin And $lKick <> 3 Then
		If $PieceA = 0 Then _
			Return Not (BlockIsFull($GRID, $PieceX + 2, $PieceY + 0) And _
						BlockIsFull($GRID, $PieceX + 0, $PieceY + 0))
		If $PieceA = 1 Then _
			Return Not (BlockIsFull($GRID, $PieceX + 0, $PieceY + 0) And _
						BlockIsFull($GRID, $PieceX + 0, $PieceY + 2))
		If $PieceA = 2 Then _
			Return Not (BlockIsFull($GRID, $PieceX + 0, $PieceY + 2) And _
						BlockIsFull($GRID, $PieceX + 2, $PieceY + 2))
		If $PieceA = 3 Then _
 			Return Not (BlockIsFull($GRID, $PieceX + 2, $PieceY + 2) And _
						BlockIsFull($GRID, $PieceX + 2, $PieceY + 0))
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
Func BlockIsNeighbour(ByRef Const $GRID, $X, $Y, $Block)
	Return BlockInBounds($GRID, $X, $Y) And $GRID[$X][$Y] = $Block
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
			ClearLine($GRID,   $j)
			If $HighlightClear Then ClearLine($HLIGHT, $j)
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
			$Damage += $tSpin ? $LineClear * 2 : $LineClear - 1
			$Damage -= $sMini ? 2 : 0

			Sound($tSpin ? ($BtB ? 'btb' : 'tspin') : 'clear')
		Case 4
			$ClearCombo += 1
			$Damage += 4

			Sound($BtB ? 'btb' : 'tetris')
	EndSwitch
	$CHG = True

	$Damage += $ClearCombo > 2
	$Damage += $ClearCombo > 4
	$Damage += $ClearCombo > 6
	$Damage += $ClearCombo > 8
	$Damage += $ClearCombo > 11

	$B2BText    = ''
	$AttackText = ''
	If $LineClear = 4 Or ($LineClear > 0 And $tSpin) Then
		If $BtB Then
			$Damage += 1
			$B2BText = 'B2B'
		Else
			$BtB = True
		EndIf

		Switch $LineClear
			Case 0
				$AttackText = 'T-SPIN      '
			Case 1
				$AttackText = $sMini ? 'T-SPIN MINI ' : 'T-SPINSINGLE'
			Case 2
				$AttackText = 'T-SPINDOUBLE'
			Case 3
				$AttackText = 'T-SPINTRIPLE'
			Case 4
				$AttackText = ' FOUR  TRIS '
		EndSwitch
	ElseIf $LineClear <> 0 Then
		$BtB = False
	EndIf

	Switch $GAMEMODE
		Case $GM_CHEESE	;cheese_race
			If $LineClear = 0 Then GridSpawnGarbage()
		Case $GM_FOUR ;4wide
			If $LineClear = 0 Then lose_game()
			AddWide($LineClear)
		Case $GM_PC ;pco
	EndSwitch
EndFunc
Func ClearLine(ByRef $GRID, $Line)
	Local $i, $j
	For $i = 0 To UBound($GRID, 1) - 1
		For $j = $Line - 1 To 0 Step -1
			$GRID[$i][$j + 1] = $GRID[$i][$j]
		Next
	Next

	For $i = 0 To UBound($GRID, 1) - 1
		$GRID[$i][0] = 0
	Next
EndFunc
Func PushLine(ByRef $GRID, $Line)
	Local $i, $j
	For $i = 0 To UBound($GRID, 1) - 1
		For $j = 0 To $Line - 1
			$GRID[$i][$j] = $GRID[$i][$j+1]
		Next
	Next

	For $i = 0 To UBound($GRID, 1) - 1
		$GRID[$i][$Line] = 0
	Next
EndFunc
Func AddWide($Amount = 1)
	Local $Hole = Floor(UBound($GRID)/2) - 2

	For $j = 0 To $Amount
		For $i = 0 To UBound($GRID) - 1
			If $i < $Hole Or $i > $Hole+3 Then
				$GRID[$i][$j] = 8
			EndIf
		Next
	Next

	$CHG = True
EndFunc


Func PieceMove($Angle, $X, $Y)
	Local $Rotation = $Angle
	Local $Sound

	$Angle = Mod($PieceA + $Angle, 4)
	$X = $PieceX + $X
	$Y = $PieceY + $Y

	If PieceFits(BagGetPiece(), $Angle, $X, $Y) Then
		$PieceA = $Angle
		$PieceX = $X
		$PieceY = $Y

		$tSpin = ($Rotation <> 0) And CheckTSpin()
		$sMini = ($Rotation <> 0) And CheckMini()
		$Sound = ($Rotation <> 0) And $tSpin ? Sound('kick') : Sound('rotate')

		$CHG = True
		Return True
	Else
		If $Rotation <> 0 Then ;trying to rotate
			If PieceKick($Angle, $X, $Y, $Rotation) Then
				$PieceA = $Angle
				$PieceX = $X
				$PieceY = $Y

				$tSpin = CheckTSpin()
				$sMini = CheckMini()
				$Sound = $tSpin ? Sound('kick') : Sound('rotate')

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
Func PieceKick(ByRef $Angle, ByRef $X, ByRef $Y, $Rotation)
	Local $Piece = BagGetPiece()

	If $Piece = 0 Then ;I piece
		Switch $Rotation
			Case 1 ;CCW
				Local $Offset[4][4][2] = [ _
				[[+2, 0],[-1, 0],[+2,-1],[-1,+2]], _
				[[-1, 0],[+2, 0],[-1,-2],[+2,+1]], _
				[[-2, 0],[+1, 0],[-2,+1],[+1,-2]], _
				[[+1, 0],[-2, 0],[+1,+2],[-2,+1]]]
			Case 3 ;CW
				Local $Offset[4][4][2] = [ _
				[[+1, 0],[-2, 0],[+1,+2],[-2,-1]], _
				[[+2, 0],[-1, 0],[+2,-1],[-1,+2]], _
				[[-1, 0],[+2, 0],[-1,-2],[+2,+1]], _
				[[-2, 0],[+1, 0],[-2,+1],[+1,-2]]]
			Case Else
				Return False
		EndSwitch
	Else
		Switch $Rotation
			Case 1 ;CCW
				Local $Offset[4][4][2] = [ _
				[[+1, 0],[+1,+1],[ 0,-2],[+1,-2]], _
				[[+1, 0],[+1,-1],[ 0,+2],[+1,+2]], _
				[[-1, 0],[-1,+1],[ 0,-2],[-1,-2]], _
				[[-1, 0],[-1,-1],[ 0,+2],[-1,+2]]]
			Case 2 ;180
				Local $Offset[4][5][2] = [ _
				[[ 0,+1],[-1,+1],[+1,+1],[-1, 0],[+1, 0]], _
				[[+1, 0],[+1,-2],[+1,-1],[ 0,-2],[ 0,-1]], _
				[[ 0,-1],[+1,-1],[-1,-1],[+1, 0],[-1, 0]], _
				[[-1, 0],[-1,+2],[-1,-1],[ 0,-2],[ 0,-1]]]
			Case 3 ;CW
				Local $Offset[4][4][2] = [ _
				[[-1, 0],[-1,+1],[ 0,-2],[-1,-2]], _
				[[+1, 0],[+1,-1],[ 0,+2],[+1,+2]], _
				[[+1, 0],[+1,+1],[ 0,-2],[+1,-2]], _
				[[-1, 0],[-1,-1],[ 0,+2],[-1,+2]]]
			Case Else
				Return False
		EndSwitch
	EndIf

	For $i = 0 To UBound($Offset, 2) - 1
		If PieceFits($Piece, $Angle, $X + $Offset[$Angle][$i][0], $Y + $Offset[$Angle][$i][1]) Then
			$X += $Offset[$Angle][$i][0]
			$Y += $Offset[$Angle][$i][1]
			$lKick = $i
			Return True
		EndIf
	Next

	Return False
EndFunc
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
Func PieceFreeze(ByRef $GRID, $Piece, $Angle, $X, $Y)
	Local $Shape = PieceGetShape($Piece, $Angle)
	Local $i, $j
	For $i = 0 To UBound($Shape, 1) - 1
		For $j = 0 To UBound($Shape, 2) - 1

			If $Shape[$i][$j] And BlockInBounds($GRID, $X+$i, $Y+$j) Then
				$GRID[$X+$i][$Y+$j] = $Piece + 1
			EndIf
		Next
	Next
EndFunc
Func PieceGetName($Piece)
	Local $LOOKUP[7] = ['I','J','S','O','Z','L','T']
	If $Piece < 0 Then Return '-'
	If $Piece > 6 Then Return 'M'
	Return $LOOKUP[$Piece]
EndFunc
Func PieceGetID($Piece)
	Switch $Piece
		Case '-'
			Return -1
		Case 'I'
			Return 0
		Case 'J'
			Return 1
		Case 'S'
			Return 2
		Case 'O'
			Return 3
		Case 'Z'
			Return 4
		Case 'L'
			Return 5
		Case 'T'
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
		Case Else ; Monomino
			Local $Shape[3][3] = [ _
					[0, 0, 0], _
					[0, 1, 0], _
					[0, 0, 0]]
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
	DllStructSetData($tRECT, 'Left',   $X)
	DllStructSetData($tRECT, 'Top',    $Y)
	DllStructSetData($tRECT, 'Right',  $X+$Width)
	DllStructSetData($tRECT, 'Bottom', $Y+$Height)
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
	_WinAPI_DeleteDC($BDC)

	_WinAPI_DeleteObject($BUF)
	_WinAPI_DeleteObject($TEXTURE)
	_WinAPI_DeleteObject($ICONBMP)

	For $i = 0 To UBound($Brush) - 1
		_WinAPI_DeleteObject($Brush[$i])
		_WinAPI_DeleteObject($Blend[$i])
	Next

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

Func _CreateFont($Size, $Weight = 400, $Family = 'Arial')
	Return _WinAPI_CreateFont($Size, 0, 0, 0, $Weight, False, False, False, $DEFAULT_CHARSET, _
        $OUT_DEFAULT_PRECIS, $CLIP_DEFAULT_PRECIS, $DEFAULT_QUALITY, 0, $Family)
EndFunc
Func _LoadPng($FileName)
	Local $Image
	Local $HBITMAP

	_GDIPlus_Startup()
	$Image = _GDIPlus_ImageLoadFromFile($FileName)
	$HBITMAP = _GDIPlus_BitmapCreateHBITMAPFromBitmap($Image)
	_GDIPlus_ImageDispose($Image)
	_GDIPlus_Shutdown()

	Return $HBITMAP
EndFunc


