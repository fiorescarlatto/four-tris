#include-once

; #FUNCTION# ;===============================================================================
;
; Name...........: _LZNTDecompress
; Description ...: Decompresses input data.
; Syntax.........: _LZNTDecompress ($bBinary)
; Parameters ....: $vInput - Binary data to decompress.
; Return values .: Success - Returns decompressed binary data.
;                          - Sets @error to 0
;                  Failure - Returns empty string and sets @error:
;                  |1 - Error decompressing.
; Author ........: trancexx
; Related .......: _LZNTCompress
; Link ..........; http://msdn.microsoft.com/en-us/library/bb981784.aspx
;
;==========================================================================================
Func _LZNTDecompress($bBinary)

    $bBinary = Binary($bBinary)

    Local $tInput = DllStructCreate("byte[" & BinaryLen($bBinary) & "]")
    DllStructSetData($tInput, 1, $bBinary)

    Local $tBuffer = DllStructCreate("byte[" & 16 * DllStructGetSize($tInput) & "]") ; initially oversizing buffer

    Local $a_Call = DllCall("ntdll.dll", "int", "RtlDecompressBuffer", _
            "ushort", 2, _
            "ptr", DllStructGetPtr($tBuffer), _
            "dword", DllStructGetSize($tBuffer), _
            "ptr", DllStructGetPtr($tInput), _
            "dword", DllStructGetSize($tInput), _
            "dword*", 0)

    If @error Or $a_Call[0] Then
        Return SetError(1, 0, "") ; error decompressing
    EndIf

    Local $tOutput = DllStructCreate("byte[" & $a_Call[6] & "]", DllStructGetPtr($tBuffer))

    Return SetError(0, 0, DllStructGetData($tOutput, 1))

EndFunc   ;==>_LZNTDecompress



; #FUNCTION# ;===============================================================================
;
; Name...........: _LZNTCompress
; Description ...: Compresses input data.
; Syntax.........: _LZNTCompress ($vInput [, $iCompressionFormatAndEngine])
; Parameters ....: $vInput - Data to compress.
;                  $iCompressionFormatAndEngine - Compression format and engine type. Default is 2 (standard compression). Can be:
;                  |2 - COMPRESSION_FORMAT_LZNT1 | COMPRESSION_ENGINE_STANDARD
;                  |258 - COMPRESSION_FORMAT_LZNT1 | COMPRESSION_ENGINE_MAXIMUM
; Return values .: Success - Returns compressed binary data.
;                          - Sets @error to 0
;                  Failure - Returns empty string and sets @error:
;                  |1 - Error determining workspace buffer size.
;                  |2 - Error compressing.
; Author ........: trancexx
; Related .......: _LZNTDecompress
; Link ..........; http://msdn.microsoft.com/en-us/library/bb981783.aspx
;
;==========================================================================================
Func _LZNTCompress($vInput, $iCompressionFormatAndEngine = 2)

    If Not ($iCompressionFormatAndEngine = 258) Then
        $iCompressionFormatAndEngine = 2
    EndIf

    Local $bBinary = Binary($vInput)

    Local $tInput = DllStructCreate("byte[" & BinaryLen($bBinary) & "]")
    DllStructSetData($tInput, 1, $bBinary)

    Local $a_Call = DllCall("ntdll.dll", "int", "RtlGetCompressionWorkSpaceSize", _
            "ushort", $iCompressionFormatAndEngine, _
            "dword*", 0, _
            "dword*", 0)

    If @error Or $a_Call[0] Then
        Return SetError(1, 0, "") ; error determining workspace buffer size
    EndIf

    Local $tWorkSpace = DllStructCreate("byte[" & $a_Call[2] & "]") ; workspace is needed for compression

    Local $tBuffer = DllStructCreate("byte[" & 16 * DllStructGetSize($tInput) & "]") ; initially oversizing buffer

    Local $a_Call = DllCall("ntdll.dll", "int", "RtlCompressBuffer", _
            "ushort", $iCompressionFormatAndEngine, _
            "ptr", DllStructGetPtr($tInput), _
            "dword", DllStructGetSize($tInput), _
            "ptr", DllStructGetPtr($tBuffer), _
            "dword", DllStructGetSize($tBuffer), _
            "dword", 4096, _
            "dword*", 0, _
            "ptr", DllStructGetPtr($tWorkSpace))

    If @error Or $a_Call[0] Then
        Return SetError(2, 0, "") ; error compressing
    EndIf

    Local $tOutput = DllStructCreate("byte[" & $a_Call[7] & "]", DllStructGetPtr($tBuffer))

    Return SetError(0, 0, DllStructGetData($tOutput, 1))

EndFunc   ;==>_LZNTCompress