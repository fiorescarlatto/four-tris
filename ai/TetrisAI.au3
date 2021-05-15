;This is a work in progress
;this code does nothing for now.

Func AI_Program()
	Local $M = __MemCopy($GRID)
	Local $NewX = -99
	Local $NewA = -99

	For $A = 0 To 3
	For $X = -1 To 9
		If PieceFits($Piece, $A, $X, 0) Then



			ExitLoop 2
		EndIf
	Next
	Next

	If $NewX <> -99 And $NewA <> -99 Then
		$PieceX = $X
		$PieceA = $A

		Drop()
	EndIf
EndFunc
