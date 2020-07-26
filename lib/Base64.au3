#include-once

Global $B64_ENCODING[65] = [ _
'A','B','C','D','E','F','G','H', _
'I','J','K','L','M','N','O','P', _
'Q','R','S','T','U','V','W','X', _
'Y','Z','a','b','c','d','e','f', _
'g','h','i','j','k','l','m','n', _
'o','p','q','r','s','t','u','v', _
'w','x','y','z','0','1','2','3', _
'4','5','6','7','8','9','-','_', _
""] ;removed padding (usually '=')


Func __B64_REVERSE($C)
	$C = Asc($C)

	Switch $C
		Case Asc('A') To Asc('Z')
			Return $C - Asc('A')
		Case Asc('a') To Asc('z')
			Return $C - Asc('a') + 26
		Case Asc('0') To Asc('9')
			Return $C - Asc('0') + 52
		Case Asc('-')
			Return 62
		Case Asc('_')
			Return 63
		Case Asc('=')
			Return 0
	EndSwitch

	Return 0
EndFunc


Func B64_Encode($Binary)
	Local $Base64 = ''

	Local $Buffer
	Local $BIN[3]
	Local $B64[4]

	For $i = 1 To BinaryLen($Binary) Step 3
		$Buffer = BinaryMid($Binary, $i, 3)

		If BinaryLen($Buffer) = 1 Then
			$BIN[0] = BinaryMid($Buffer, 1, 1)

			$B64[0] = BitShift($BIN[0], 2)
			$B64[1] = BitShift(BitAND($BIN[0], 3),-4)
			$B64[2] = 64
			$B64[3] = 64

		ElseIf BinaryLen($Buffer) = 2 Then
			$BIN[0] = BinaryMid($Buffer, 1, 1)
			$BIN[1] = BinaryMid($Buffer, 2, 1)

			$B64[0] = BitShift($BIN[0], 2)
			$B64[1] = BitShift(BitAND($BIN[0], 3),-4) + BitShift($BIN[1], 4)
			$B64[2] = BitShift(BitAND($BIN[1],15),-2)
			$B64[3] = 64

		Else
			$BIN[0] = BinaryMid($Buffer, 1, 1)
			$BIN[1] = BinaryMid($Buffer, 2, 1)
			$BIN[2] = BinaryMid($Buffer, 3, 1)

			$B64[0] = BitShift($BIN[0], 2)
			$B64[1] = BitShift(BitAND($BIN[0], 3),-4) + BitShift($BIN[1], 4)
			$B64[2] = BitShift(BitAND($BIN[1],15),-2) + BitShift($BIN[2], 6)
			$B64[3] = BitAND  ($BIN[2],63)
		EndIf

		For $j = 0 To 3
			$Base64 &= $B64_ENCODING[$B64[$j]]
		Next
	Next

	Return $Base64
EndFunc

Func B64_Decode($Base64)
	Local $Binary = '0x'

	Local $Buffer
	Local $BIN
	Local $B64[4]

	For $i = 1 To StringLen($Base64) Step 4
		$Buffer = StringMid($Base64, $i, 4)

		If StringLen($Buffer) < 4 Then _
			$Buffer = StringMid($Buffer & '===', 1, 4)

		$B64[0] = __B64_REVERSE(StringMid($Buffer, 1, 1))
		$B64[1] = __B64_REVERSE(StringMid($Buffer, 2, 1))
		$B64[2] = __B64_REVERSE(StringMid($Buffer, 3, 1))
		$B64[3] = __B64_REVERSE(StringMid($Buffer, 4, 1))

		$BIN = 0

		$BIN += BitShift($B64[0], -18)
		$BIN += BitShift($B64[1], -12)
		$BIN += BitShift($B64[2],  -6)
		$BIN += BitShift($B64[3],   0)

		If     StringMid($Buffer, 2, 3) = '===' Then
			$BIN = BitShift($BIN, 16)
			$Binary &= Hex($BIN, 2)
		ElseIf StringMid($Buffer, 3, 2) = '=='  Then
			$BIN = BitShift($BIN, 16)
			$Binary &= Hex($BIN, 2)
		ElseIf StringMid($Buffer, 4, 1) = '='   Then
			$BIN = BitShift($BIN, 8)
			$Binary &= Hex($BIN, 4)
		Else
			$Binary &= Hex($BIN, 6)
		EndIf
	Next

	Return Binary($Binary)
EndFunc

