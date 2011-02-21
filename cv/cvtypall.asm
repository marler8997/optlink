		TITLE	CVTYPALL - Copyright (c) SLR Systems 1994

		INCLUDE	MACROS

if	fg_cvpack

		INCLUDE	CVTYPES

		PUBLIC	CV_TYPES_ALL_4


		.DATA

		EXTERNDEF	CV_TEMP_RECORD:BYTE,SYMBOL_TEXT:BYTE

		EXTERNDEF	CURNMOD_NUMBER:DWORD,CURNMOD_NUMBER:DWORD,CV_PUB_TXT_OFFSET:DWORD,CV_PUB_SYMBOL_ID:DWORD
		EXTERNDEF	CVG_SEGMENT:DWORD,BYTES_SO_FAR:DWORD,CVG_SYMBOL_OFFSET:DWORD,CVG_SEGMENT_OFFSET:DWORD
		EXTERNDEF	CVG_SYMBOL_HASH:DWORD,FINAL_HIGH_WATER:DWORD

		EXTERNDEF	CV_GTYPE_GARRAY:STD_PTR_S,CV_GTYPE_STUFF:ALLOCS_STRUCT

		EXTERNDEF	CV_DWORD_ALIGN:DWORD

                .CODE	PASS1_TEXT
		EXTERNDEF	RELEASE_CV_GTYPE_GARRAY:PROC

		.CODE	CVPACK_TEXT

		EXTERNDEF	MOVE_EAX_TO_FINAL_HIGH_WATER:PROC,HANDLE_CV_INDEX:PROC,FLUSH_CV_TEMP:PROC,STORE_CV_SYMBOL_INFO:PROC
		EXTERNDEF	OUTPUT_CV_SYMBOL_ALIGN:PROC,FLUSH_CV_SYMBOL_HASHES:PROC
		EXTERNDEF	_release_minidata:proc,GET_NEW_LOG_BLK:PROC,MOVE_EAX_TO_EDX_FINAL:PROC
		EXTERNDEF	RELEASE_BLOCK:PROC,SAY_VERBOSE:PROC,WARN_ASCIZ_RET:PROC,MOVE_NEWOMF_ASCIZ:PROC

		EXTERNDEF	CVP_STILL_FWDREF_ERR:ABS


CVT_ZEROS_SIZE	EQU	1024


CVTYP_VARS	STRUC

CVT_ZEROS_BP		DB	CVT_ZEROS_SIZE DUP(?)
CVT_SECTION_OFFSET_BP	DD	?	;
CVT_HDR_FINAL_BP	DD	?
CVT_TYPE_PUT_PTR_BP	DD	?
CVT_TYPE_PUT_PTR_LIMIT_BP DD	?
CVT_TYPES_OFFSET_BP	DD	?
CVT_OFFSET_PUT_PTR_BP	DD	?
CVT_TYPE_PUT_BLK_BP	DD	?
CVT_PAGE_BYTES_BP	DD	?
CVT_OFFSET_LIMIT_BP	DD	?

CVTYP_VARS	ENDS


FIX	MACRO	X

X	EQU	([EBP-SIZE CVTYP_VARS].(X&_BP))

	ENDM


FIX	CVT_ZEROS
FIX	CVT_SECTION_OFFSET
FIX	CVT_HDR_FINAL
FIX	CVT_TYPE_PUT_PTR
FIX	CVT_TYPE_PUT_PTR_LIMIT
FIX	CVT_TYPES_OFFSET
FIX	CVT_OFFSET_PUT_PTR
FIX	CVT_TYPE_PUT_BLK
FIX	CVT_PAGE_BYTES
FIX	CVT_OFFSET_LIMIT


CV_TYPES_ALL_4	PROC
		;
		;OUTPUT GLOBALTYPES TABLE
		;
		CMP	CV_GTYPE_GARRAY._STD_LIMIT,1
		JAE	L0$

		RET

L0$:
		MOV	EAX,OFF DOING_SSTGLOBALTYPES_MSG
		CALL	SAY_VERBOSE

		;
		;INITIALIZE STUFF
		;
		CALL	CV_DWORD_ALIGN

		PUSHM	EDI,ESI,EBX,EBP

		MOV	EBP,ESP
		ASSUME	EBP:PTR CVTYP_VARS
		SUB	ESP,SIZE CVTYP_VARS

		XOR	EAX,EAX
		MOV	ECX,CVT_ZEROS_SIZE/4

		LEA	EDI,CVT_ZEROS
		MOV	CVT_TYPES_OFFSET,EAX

		REP	STOSD

		MOV	CVT_PAGE_BYTES,EAX
		MOV	EAX,BYTES_SO_FAR		;STORE ADDRESS FOR SSTGLOBALTYPES INDEX LATER

		MOV	CVT_SECTION_OFFSET,EAX
		MOV	EAX,FINAL_HIGH_WATER		;PLACE TO WRITE BUFFERED TYPE INDEXES

		MOV	CVT_HDR_FINAL,EAX
		MOV	EAX,CV_GTYPE_GARRAY._STD_LIMIT

		SHL	EAX,2				;CALCULATE WHERE WE WILL WRITE TYPES

		ADD	EAX,8

		ADD	FINAL_HIGH_WATER,EAX
		ADD	BYTES_SO_FAR,EAX

		CALL	GET_NEW_LOG_BLK			;PLACE TO BUFFER OUTPUT TYPES

		MOV	CVT_TYPE_PUT_BLK,EAX
		MOV	ECX,OFF CV_TEMP_RECORD

		MOV	CVT_OFFSET_PUT_PTR,ECX
		ADD	ECX,CV_TEMP_SIZE

		MOV	CVT_TYPE_PUT_PTR,EAX
		ADD	EAX,PAGE_SIZE

		MOV	CVT_OFFSET_LIMIT,ECX
		MOV	CVT_TYPE_PUT_PTR_LIMIT,EAX

		MOV	EAX,1
		CALL	STORE_EAX_TYPEOFF

		MOV	EAX,CV_GTYPE_GARRAY._STD_LIMIT
		CALL	STORE_EAX_TYPEOFF

		MOV	EAX,1
L1$:
		PUSH	EAX
		CONVERT	ESI,EAX,CV_GTYPE_GARRAY

		MOV	ECX,DPTR [ESI].CV_GTYPE_STRUCT._CV_GTYPE_LENGTH
		MOV	AL,[ESI].CV_GTYPE_STRUCT._CV_GTYPE_FLAGS

		TEST	AL,MASK CV_LTYPE_FWDREF
		JNZ	L15$
L16$:
		ADD	ESI,CV_GTYPE_STRUCT._CV_GTYPE_LENGTH
		;
		;ESI IS GLOBAL TYPE
		;
		MOV	EBX,ECX
		ADD	ECX,2+3

		SHR	EBX,16
		AND	ECX,0FFFCH

		MOV	EAX,CVT_PAGE_BYTES

		MOV	EDX,L_TO_G[EBX*4]	;CONVERT TYPE BACK TO NORMAL
		ADD	EAX,ECX
		;
		;DO 48K ALIGNMENT CALCULATION
		;
		MOV	BPTR [ESI+2],DL
		CMP	EAX,48K

		MOV	BPTR [ESI+3],DH
		JB	L3$

		JZ	L29$
L2$:
		MOV	EAX,48K
		PUSHM	ESI

		MOV	EDX,CVT_PAGE_BYTES
		PUSH	ECX

		SUB	EAX,EDX			;EAX IS # OF ZEROS TO WRITE
L21$:
		LEA	ESI,CVT_ZEROS
		;
		;MOVE IN CVT_ZEROS_SIZE PIECES
		;
		MOV	ECX,CVT_ZEROS_SIZE
		PUSH	EAX

		CMP	EAX,ECX
		JBE	L22$

		MOV	EAX,ECX
L22$:
		PUSH	EAX
		CALL	MOVE_ESIEAX_TO_TYPEOUT

		POPM	ECX,EAX

		SUB	EAX,ECX
		JNZ	L21$

		POPM	ECX,ESI

		MOV	EAX,ECX
		JMP	L3$

L15$:
		CALL	DO_FWDREF
		JMP	L16$

L29$:
		XOR	EAX,EAX
L3$:
		MOV	CVT_PAGE_BYTES,EAX
		;
		;STORE IN BUFFER
		;
		MOV	EDX,CVT_TYPES_OFFSET

		MOV	EAX,ECX
		PUSH	EDX

;		PUSH	ECX
		CALL	MOVE_ESIEAX_TO_TYPEOUT

;		POP	ECX
;		XOR	EAX,EAX
;
;		SUB	EAX,ECX
;
;		AND	EAX,3
;		JZ	L4$
;
;		LEA	ESI,CVT_ZEROS
;
;		ADD	CVT_PAGE_BYTES,EAX
;		CALL	MOVE_ESIEAX_TO_TYPEOUT
L4$:
		;
		;NOW, STORE OFFSET PLEASE
		;
		POP	EAX
		CALL	STORE_EAX_TYPEOFF

		POP	EAX
		MOV	ECX,CV_GTYPE_GARRAY._STD_LIMIT

		INC	EAX

		CMP	ECX,EAX
		JAE	L1$

		MOV	EAX,OFF CV_GTYPE_STUFF
		push	EAX
		call	_release_minidata
		add	ESP,4

		CALL	RELEASE_CV_GTYPE_GARRAY
		;
		;  1.  DO NAME HASH TABLE
		;  2.  DO ADDRESS HASH TABLE
		;  3.  WRITE HEADER
		;  4.  DO CV_INDEX
		;
		CALL	FLUSH_TYPEOFF

		CALL	FLUSH_CVT_TYPE_BUFFER

		MOV	EAX,CVT_TYPE_PUT_BLK
		CALL	RELEASE_BLOCK

		MOV	CURNMOD_NUMBER,-1

		MOV	EAX,CVT_SECTION_OFFSET
		MOV	ECX,012BH

		CALL	HANDLE_CV_INDEX		;BACKWARDS

		MOV	ESP,EBP

		POPM	EBP,EBX,ESI,EDI

		RET

CV_TYPES_ALL_4	ENDP


MOVE_ESIEAX_TO_TYPEOUT	PROC	NEAR
		;
		;ALWAYS DWORD-SIZED STUFF
		;
		MOV	ECX,CVT_TYPES_OFFSET
		PUSH	EDI

		ADD	ECX,EAX

		MOV	CVT_TYPES_OFFSET,ECX
L1$:
		MOV	EDI,CVT_TYPE_PUT_PTR
		MOV	ECX,CVT_TYPE_PUT_PTR_LIMIT

		MOV	EDX,ECX
		SUB	ECX,EDI			;ECX IS BYTES LEFT IN BUFFER

		CMP	EAX,ECX
		JAE	L3$

		MOV	ECX,EAX
L3$:
		SUB	EAX,ECX

		SHR	ECX,2

		REP	MOVSD

		CMP	EDI,EDX
		JNZ	L8$

		MOV	CVT_TYPE_PUT_PTR,EDI
		PUSH	EAX

		CALL	FLUSH_CVT_TYPE_BUFFER

		POP	EAX

		OR	EAX,EAX
		JNZ	L1$

		POP	EDI

		RET

L8$:
		MOV	CVT_TYPE_PUT_PTR,EDI
		POP	EDI

		RET

MOVE_ESIEAX_TO_TYPEOUT	ENDP


STORE_EAX_TYPEOFF	PROC	NEAR
		;
		;
		;
		MOV	ECX,CVT_OFFSET_PUT_PTR

		MOV	[ECX],EAX
		ADD	ECX,4

		MOV	EAX,CVT_OFFSET_LIMIT
		MOV	CVT_OFFSET_PUT_PTR,ECX

		CMP	EAX,ECX
		JZ	FLUSH_TYPEOFF

		RET

STORE_EAX_TYPEOFF	ENDP


FLUSH_TYPEOFF	PROC	NEAR
		;
		;
		;
		MOV	EAX,OFF CV_TEMP_RECORD
		MOV	ECX,CVT_OFFSET_PUT_PTR

		SUB	ECX,EAX
		JZ	L4$

		MOV	EDX,CVT_HDR_FINAL
		MOV	CVT_OFFSET_PUT_PTR,EAX

		ADD	CVT_HDR_FINAL,ECX
		JMP	MOVE_EAX_TO_EDX_FINAL

L4$:
		RET

FLUSH_TYPEOFF	ENDP


FLUSH_CVT_TYPE_BUFFER	PROC	NEAR
		;
		;
		;
		MOV	EAX,CVT_TYPE_PUT_BLK
		MOV	ECX,CVT_TYPE_PUT_PTR

		SUB	ECX,EAX
		JZ	L4$

		MOV	EDX,BYTES_SO_FAR
		MOV	CVT_TYPE_PUT_PTR,EAX

		ADD	EDX,ECX

		MOV	BYTES_SO_FAR,EDX
		JMP	MOVE_EAX_TO_FINAL_HIGH_WATER

L4$:
		RET

FLUSH_CVT_TYPE_BUFFER	ENDP


DO_FWDREF	PROC
		;
		;ESI IS GTYPE
		;
		ASSUME	ESI:PTR CV_GTYPE_STRUCT

		PUSHM	EDX,ECX,EAX
		XOR	ECX,ECX

		GETT	AL,CV_WARNINGS
		MOV	CL,[ESI]._CV_GTYPE_NAMEOFF

		TEST	AL,AL
		JZ	L9$

		ADD	ECX,ESI
		MOV	EAX,OFF SYMBOL_TEXT

		CALL	MOVE_NEWOMF_ASCIZ

		MOV	ECX,OFF SYMBOL_TEXT
		MOV	AL,CVP_STILL_FWDREF_ERR

		CALL	WARN_ASCIZ_RET
L9$:
		POPM	EAX,ECX,EDX

		RET

DO_FWDREF	ENDP


		.CONST

		ALIGN	4

L_TO_G		LABEL	DWORD

	DD	LF_UNDEFINED
	DD	LF_MODIFIER
	DD	LF_POINTER
	DD	LF_ARRAY
	DD	LF_CLASS
	DD	LF_STRUCTURE
	DD	LF_UNION
	DD	LF_ENUM
	DD	LF_PROCEDURE
	DD	LF_MFUNCTION
	DD	LF_VTSHAPE
	DD	LF_COBOL0
	DD	LF_COBOL1
	DD	LF_BARRAY
	DD	LF_LABEL
	DD	LF_NULL
	DD	LF_NOTTRAN
	DD	LF_DIMARRAY
	DD	LF_VFTPATH
	DD	LF_PRECOMP
	DD	LF_ENDPRECOMP
	DD	LF_OEM
	DD	LF_RESERVED
	DD	LF_SKIP
	DD	LF_ARGLIST
	DD	LF_DEFARG
	DD	LF_LIST
	DD	LF_FIELDLIST
	DD	LF_DERIVED
	DD	LF_BITFIELD
	DD	LF_METHODLIST
	DD	LF_DIMCONU
	DD	LF_DIMCONLU
	DD	LF_DIMVARU
	DD	LF_DIMVARLU
	DD	LF_REFSYM
	DD	LF_BCLASS
	DD	LF_VBCLASS
	DD	LF_IVBCLASS
	DD	LF_ENUMERATE
	DD	LF_FRIENDFCN
	DD	LF_INDEX
	DD	LF_MEMBER
	DD	LF_STMEMBER
	DD	LF_METHOD
	DD	LF_NESTTYPE
	DD	LF_VFUNCTAB
	DD	LF_FRIENDCLS
	DD	LF_ONEMETHOD
	DD	LF_VFUNCOFF


DOING_SSTGLOBALTYPES_MSG DB	SIZEOF DOING_SSTGLOBALTYPES_MSG-1,'Doing SSTGLOBALTYPES',0DH,0AH

endif

		END

