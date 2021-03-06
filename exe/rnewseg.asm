		TITLE	RNEWSEG - Copyright (c) SLR Systems 1994

		INCLUDE	MACROS
		INCLUDE	SEGMENTS
		INCLUDE	MODULES


		PUBLIC	EXE_OUT_NEW_SEGMENT,EXE_OUT_NEW_SEGMOD,DEFINE_STACK_DELTA

if	fg_segm
		PUBLIC	NEW_SEGMOD_RELOC,EONSM_DEBUG,NEW_SEGMOD_REAL,REAL_STACK_SEGMOD
endif


		.DATA

		EXTERNDEF	FIX2_SEG_TYPE:BYTE,FIX2_SEG_COMBINE:BYTE

		EXTERNDEF	OPTI_STOSD_SIZE:DWORD,OPTI_RELOC_CLEAR:DWORD,LAST_CV_MODULE_GINDEX:DWORD,CURNMOD_GINDEX:DWORD
		EXTERNDEF	CV_TYPES_TYPE:DWORD,CV_LOCALS_TYPE:DWORD,FIX2_NEW_SEGMOD_GINDEX:DWORD,HIGH_WATER:DWORD
		EXTERNDEF	FIX2_LDATA_SEGMENT_GINDEX:DWORD,RELOC_BITS:DWORD,BYTES_SO_FAR:DWORD,RELOC_HIGH_WATER:DWORD
		EXTERNDEF	FIX2_SEG_FRAME:DWORD,FIX2_SEG_LEN:DWORD,FIX2_EXEPACK_BASE:DWORD,FIX2_SM_LEN:DWORD
		EXTERNDEF	FIX2_SM_START:DWORD,FIX2_STACK_LARGEST:DWORD,FIX2_STACK_DELTA:DWORD,FIX2_STACK_DELTA_ADDER:DWORD
		EXTERNDEF	FIX2_SKIP_BYTES:DWORD,FIRST_MODULE_GINDEX:DWORD,CURNMOD_NUMBER:DWORD

		EXTERNDEF	MODULE_GARRAY:STD_PTR_S,SEGMOD_GARRAY:STD_PTR_S,CV_LTYPE_GARRAY:STD_PTR_S
		EXTERNDEF	CV_LTYPE_STUFF:ALLOCS_STRUCT

		EXTERNDEF	OUT_FLUSH_SEGMENT:DWORD,OUT_FLUSH_EXE:DWORD,CV_LINNUMS:DWORD,CV_PUBLICS:DWORD,CV_MODULE:DWORD
		EXTERNDEF	CV_DWORD_ALIGN:DWORD

if	fg_cvpack

		.CODE	PASS1_TEXT
		EXTERNDEF	RELEASE_CV_LTYPE_GARRAY:PROC
endif

		.CODE	PASS2_TEXT

		EXTERNDEF	WRITE_CV_INDEX:PROC,ERR_RET:PROC,_release_minidata:proc,RELEASE_ARRAY32:PROC
		EXTERNDEF	VERBOSE_MODULENAME:PROC


		EXTERNDEF	SEG_TOO_BIG_ERR:ABS


EXE_OUT_NEW_SEGMENT	PROC
		;
		;WE NEED TO DETERMINE THINGS LIKE IS THIS NOW A DEBUG
		;RECORD?  IS THIS A BUNCH OF 'COMMON' SEGMODS?
		;
		MOV	CL,FIX2_SEG_TYPE
		MOV	AL,FIX2_SEG_COMBINE

		AND	CL,MASK SEG_CV_TYPES1 + MASK SEG_CV_SYMBOLS1	;SKIP IF CODEVIEW
		JNZ	L1$

		CMP	AL,SC_COMMON
		JZ	L2$

		CMP	AL,SC_STACK
		JZ	L2$
L4$:
		;
		;REAL SIMPLE IF NOT COMMON
		;
		GETT	AL,CHAINING_RELOCS
		GETT	CL,PACKING_RELOCS

		OR	AL,CL
		JNZ	L0$

		MOV	EAX,FIX2_SEG_FRAME
		MOV	FIX2_EXEPACK_BASE,EAX
L0$:
		RET

L1$:
		;
		;HERE IF CODEVIEW
		;
		RET

L2$:
		;
		;FOR COMMON AND STACK SEGMENTS THIS HAPPENS NOW NOT AT SEGMOD
		;
		GETT	AL,CHAINING_RELOCS
		GETT	CL,PACKING_RELOCS

		OR	AL,CL
		JZ	L3$
L21$:
		;
		;IS END OF THIS SEGMENT MORE THAN 64K AWAY FROM PREVIOUS?
		;
		MOV	EAX,FIX2_SEG_FRAME
		MOV	ECX,FIX2_SEG_LEN

		ADD	EAX,ECX
		MOV	ECX,FIX2_EXEPACK_BASE	;ALREADY PARA ALIGNED

		SUB	EAX,ECX

		CMP	EAX,64K
		JBE	L3$
L25$:
		CALL	OUT_FLUSH_SEGMENT

		MOV	EAX,FIX2_SEG_FRAME
		MOV	FIX2_EXEPACK_BASE,EAX
L3$:
		;
		;SET OPTI_RELOC_CLEAR
		;
		MOV	CL,FIX2_SEG_COMBINE
		MOV	EAX,FIX2_SEG_LEN

		CMP	CL,SC_STACK
		JZ	L5$

		CALL	NEW_SEGMOD_RELOC

		JMP	L4$

L5$:
		;
		;FOR STACKS, WE MUST USE A LENGTH THAT IS THE MAXIMUM OF THE PIECES, AND SET FIX2_STACK_DELTA
		;
		CALL	DEFINE_STACK_DELTA

		JMP	L4$

EXE_OUT_NEW_SEGMENT	ENDP


DEFINE_STACK_DELTA	PROC
		;
		;
		;
		PUSHM	EDI,ESI

		MOV	ESI,FIX2_NEW_SEGMOD_GINDEX
		MOV	EDI,FIX2_LDATA_SEGMENT_GINDEX

		XOR	EDX,EDX
L52$:
		TEST	ESI,ESI
		JZ	L56$

		CONVERT	ESI,ESI,SEGMOD_GARRAY
		ASSUME	ESI:PTR SEGMOD_STRUCT

		MOV	EAX,[ESI]._SM_BASE_SEG_GINDEX
		MOV	ECX,[ESI]._SM_LEN

		CMP	EAX,EDI
		JNZ	L56$

		MOV	EAX,[ESI]._SM_START
		MOV	ESI,[ESI]._SM_NEXT_SEGMOD_GINDEX

		SUB	ECX,EAX

		CMP	ECX,EDX
		JBE	L52$

		MOV	EDX,ECX
		JMP	L52$


L56$:
		;
		;FIX2_STACK_DELTA = SEG_LEN - SIZE OF BIGGEST PIECE
		;
		MOV	FIX2_STACK_LARGEST,EDX
		MOV	EAX,EDX

		MOV	ECX,FIX2_SEG_LEN

		SUB	EAX,ECX
		JNC	L58$
L57$:
		;
		;STACK IS -BX:AX BYTES LARGER THAN THE BIGGEST PIECE
		;
		NEG	EAX

		MOV	FIX2_STACK_DELTA_ADDER,EAX
		XOR	EAX,EAX

		MOV	FIX2_SKIP_BYTES,EAX
		MOV	EAX,ECX

		POPM	ESI,EDI

		JMP	NEW_SEGMOD_RELOC

L58$:
		;
		;STACK IS BX:AX BYTES SMALLER THAN THE BIGGEST PIECE
		;
		MOV	FIX2_SKIP_BYTES,EAX
		XOR	EAX,EAX

		MOV	FIX2_STACK_DELTA_ADDER,EAX
		MOV	EAX,FIX2_STACK_LARGEST

		POPM	ESI,EDI

		JMP	NEW_SEGMOD_RELOC

DEFINE_STACK_DELTA	ENDP


EXE_OUT_NEW_SEGMOD	PROC
		;
		;I'M NOT SURE WHAT SIGNIFICANCE THIS HAS, EXCEPT DURING
		;CODEVIEW INFO FOR STARTING AN INDEX ENTRY...
		;
		MOV	AL,FIX2_SEG_COMBINE
		GETT	CL,CHAINING_RELOCS

		CMP	AL,SC_COMMON
		JZ	L29$

		CMP	AL,SC_STACK
		JZ	L25$

		OR	CL,PACKING_RELOCS
		JZ	L2$
L0$:
		;
		;IS END OF THIS SEGMENT MORE THAN 64K AWAY FROM PREVIOUS?
		;
		MOV	EAX,FIX2_SM_LEN
		MOV	ECX,FIX2_EXEPACK_BASE	;ALREADY PARA ALIGNED

		SUB	EAX,ECX

		CMP	EAX,64K
		JBE	L2$

		CALL	OUT_FLUSH_SEGMENT
L2$:
		CALL	NEW_SEGMOD_REAL
if	fg_cv
		GETT	AL,DOING_DEBUG

		OR	AL,AL
		JNZ	L4$
endif
L29$:
		RET

L25$:
REAL_STACK_SEGMOD	LABEL	PROC
		;
		;STACK SEGMOD, DEFINE STACK_DELTA
		;
		MOV	EAX,FIX2_STACK_LARGEST
		MOV	ECX,FIX2_SM_LEN

		SUB	EAX,ECX
		MOV	ECX,FIX2_SM_START


		ADD	EAX,ECX
		MOV	ECX,FIX2_STACK_DELTA_ADDER

		ADD	EAX,ECX

		MOV	FIX2_STACK_DELTA,EAX

		RET

if	fg_cv
L4$:
EONSM_DEBUG::
		;
		;OK, NEW SEGMOD, DOES  THIS MATCH CURRENT CV_MODULE?
		;
		MOV	EAX,CURNMOD_GINDEX
CMC_2:
		CMP	LAST_CV_MODULE_GINDEX,EAX
		JNZ	CMC_1

		JMP	CV_DWORD_ALIGN


CMC_1:
		PUSH	EAX
		CALL	CV_MODULE_CHANGE

		POP	EAX
		JMP	CMC_2
endif

EXE_OUT_NEW_SEGMOD	ENDP


NEW_SEGMOD_REAL	PROC
		;
		;SET OPTI_RELOC_CLEAR
		;
		MOV	EAX,FIX2_SM_LEN
		MOV	ECX,FIX2_SM_START

		SUB	EAX,ECX

NEW_SEGMOD_RELOC	LABEL	PROC		;FROM PROT TOO

		MOV	ECX,EAX
		ADD	EAX,31

		SHR	EAX,5			;# OF DWORDS TO CLEAR FOR RELOC
		CMP	ECX,PAGE_SIZE

		MOV	OPTI_RELOC_CLEAR,EAX
		MOV	EAX,PAGE_SIZE
		;
		;SET OPTI_STOSD_SIZE
		;
		JNC	L3$

		LEA	EAX,[ECX+3]
L3$:
		MOV	ECX,RELOC_BITS

		SHR	EAX,2
		TEST	ECX,ECX

		MOV	OPTI_STOSD_SIZE,EAX
		JZ	L9$

		PUSH	EDI
		MOV	EDI,ECX

		MOV	ECX,OPTI_RELOC_CLEAR
		XOR	EAX,EAX

		REP	STOSD

		POP	EDI
		MOV	RELOC_HIGH_WATER,EAX
L9$:
		RET

NEW_SEGMOD_REAL	ENDP


		PUBLIC	CV_MODULE_CHANGE

CV_MODULE_CHANGE	PROC
		;
		;FINISH ANY CURRENT MODULE, THEN START NEXT
		;
		MOV	EAX,LAST_CV_MODULE_GINDEX

		TEST	EAX,EAX
		JZ	L9$

		MOV	CURNMOD_GINDEX,EAX
if	fg_cvpack

		CMP	CV_LTYPE_GARRAY._STD_LIMIT,0
		JZ	L3$

		MOV	EAX,OFF CV_LTYPE_STUFF
		push	EAX
		call	_release_minidata
		add	ESP,4

		CALL	RELEASE_CV_LTYPE_GARRAY
L3$:
		RESS	CV_TYPES_VALID
endif

		MOV	EAX,OPTI_STOSD_SIZE
		MOV	ECX,1

		PUSH	EAX
		MOV	OPTI_STOSD_SIZE,ECX

		CALL	CV_PUBLICS		;OUTPUT PUBLICS FOR THIS MODULE

		CALL	CV_LINNUMS		;OUTPUT LINENUMBERS

		MOV	EAX,LAST_CV_MODULE_GINDEX
		POP	ECX

		CONVERT	EAX,EAX,MODULE_GARRAY
		ASSUME	EAX:PTR MODULE_STRUCT

		MOV	OPTI_STOSD_SIZE,ECX
		MOV	EAX,[EAX]._M_NEXT_MODULE_GINDEX

L5$:
		;
		;EAX IS NEXT MODULE
		;
		MOV	ECX,CURNMOD_NUMBER
		MOV	LAST_CV_MODULE_GINDEX,EAX

		INC	ECX
		MOV	CURNMOD_GINDEX,EAX

		MOV	CURNMOD_NUMBER,ECX
		TEST	EAX,EAX

		JZ	L8$

		CALL	CV_MODULE		;OUTPUT MODULE RECORD
if	debug
		CALL	VERBOSE_MODULENAME
endif

L8$:
		RET

L9$:
		MOV	EAX,FIRST_MODULE_GINDEX
		JMP	L5$

CV_MODULE_CHANGE	ENDP

		END

