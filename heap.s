		AREA	|.text|, CODE, READONLY, ALIGN=2
		THUMB

HEAP_TOP        EQU     0x20001000
HEAP_BOT        EQU     0x20004FE0
MAX_SIZE        EQU     0x00004000
MIN_SIZE        EQU     0x00000020

MCB_TOP         EQU     0x20006800
MCB_BOT         EQU     0x20003BFE
MCB_ENT_SZ      EQU     0x00000002
MCB_TOTAL       EQU     512    

INVALID         EQU     -1

;
; Each MCB Entry
; FEDCBA9876543210
; 00SSSSSSSSS0000U					S bits are used for Heap size, U=1 Used U=0 Not Used


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Memory Control Block Initialization
; void _kinit( )
; this routine must be called from Reset_Handler in startup_TM4C129.s
; before you invoke main( ) in driver_keil

    EXPORT  _kinit
_kinit
    PUSH    {R1-R12, LR}

	LDR		R0, =MCB_TOP
	LDR		R1, =MAX_SIZE
	STRH	R1, [R0]
	MOV		R2, #0

_kinit_loop	
	LDR		R1, =MCB_BOT
	CMP		R0, R1
	BGT		_kinit_end
	ADD		R0, R0, #2
	STRH	R2, [R0]
	B		_kinit_loop
_kinit_end		
    POP     {R1-R12, LR}
	BX		LR

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Kernel Memory Allocation
; void* _k_alloc( int size )
; size              - size of requested memory space 
; return            - address of SRAM space
    EXPORT  _kalloc
_kalloc
    PUSH    {R1-R12, LR}        
; r0 = size
; r1 = MCB_TOP
    LDR     R1, =MCB_TOP
; r2 = MCB_BOT 
    LDR     R2, =MCB_BOT
    BL      _ralloc
    POP     {R1-R12, LR}  
    BX      LR

; recursive helper for kalloc
_ralloc
; r0 = size
; r1 = left_mcb_address
; r2 = right_mcb_address
; r3 = mcb_ent_sz
    LDR     R3, =MCB_ENT_SZ
; r4 = entire_mcb_addr_space
    SUB     R4, R2, R1
    ADD     R4, R4, R3
; r5 = half_mcb_addr_space
    LSR     R5, R4, #1
; r6 = midpoint_mcb_addr
    ADD     R6, R1, R5
; r7 = heap_addr
    MOV     R7, #0
; r8 = act_entire_heap_size
    LSL     R8, R4, #4
; r9 = act_half_heap_size
    LSL     R9, R5, #4

; base case : size <= act_half_heap_size
    CMP     R0, R9
    BGT     _ralloc_tophalf

    PUSH    {R0-R3, LR}
    SUB     R2, R6, R3  ; right = midpoint - mcb_ent_size
    BL      _ralloc
    MOV     R7, R0      ; head_addr = ralloc(  )
    POP     {R0-R3, LR}

    CMP     R7, #0
    BEQ     _ralloc_ptrzero

    LDR     R10, [R6]
    LSRS    R10, R10, #1
    STRHCC  R9, [R6]

    MOV     R0, R7      ; return heap_addr
    BX      LR

_ralloc_ptrzero

    PUSH    {LR}
    MOV     R1, R6      ; left = midpoint
    BL      _ralloc          
    POP     {LR}
    BX      LR          ; return

_ralloc_tophalf

    LDR     R10, [R1]
    LSRS    R10, R10, #1
    ITT     CS
    MOVCS   R0, #0
    BXCS    LR

    LDRH    R10, [R1]
    CMP     R10, R9
    ITT     LT
    MOVLT   R0, #0
    BXLT    LR

    ORR     R10, R9, #1
    STRH    R10, [R1]

    LDR     R10, =MCB_TOP
    SUB     R10, R1, R10
    LDR     R11, =HEAP_TOP
    ADD     R10, R11, R10
    LSL     R0, R10, #4
    BX      LR

_kalloc_end
    POP     {R1-R12, LR}
    BX      LR    

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Kernel Memory De-allocation
; void *_kfree( void *ptr )	
; ptr               - pointer to the memory space to be deallocated
    EXPORT  _kfree
_kfree

    PUSH    {R1-R12, LR}
	
; r1 = ptr
	MOV		R1, R0

    LDR     R2, =HEAP_TOP
    LDR     R3, =HEAP_BOT

    CMP     R1, R2
    ITT     LT
    MOVLT   R0, #0
    BLT     _kfree_end   

    CMP     R1, R3
    ITT     GT
    MOVGT   R0, #0
    BGT     _kfree_end

    LDR     R4, =MCB_TOP
    ADD     R4, R4, R1
    SUB     R4, R4, R2
    LSR     R4, R4, #4

    PUSH    {R1}
    MOV     R1, R4
    BL      _kfree_end
    POP     {R1}
    CMP     R0, #0
    ITE   EQ
    MOVEQ   R0, #0
    MOVNE   R0, R1
    BNE    _kfree_end

; recursive helper for kfree
_rfree
    PUSH    {R1-R12, LR}

; r1 - mcb_addr
; r2 - *mcb_addr
    LDRH    R2, [R1]
; r3 - MCB_TOP
    LDR     R3, =MCB_TOP
; r4 - mcb_index    
    SUB     R4, R1, R3
; r5 - mcb_disp
    LSR     R2, R2, #4
    MOV     R5, R2
; r6 - size
    LSL     R2, R2, #4
    MOV     R6, R2
; r7 - MCB_BOT
    LDR     R7, =MCB_BOT

    STRH    R1, [R2]    ; store free'd bytes

    UDIV     R0, R4, R5
    RORS    R0, R0, #1
    BCS     _rfree_odd

    ADD     R0, R1, R5
    CMP     R0, R7
    ITT     GE
    MOVGE   R0, #0
    BGE     _kfree_end

    ADD     R0, R1, R5
; r8 = mcb_buddy
    LDRH    R8, [R0]
    RORS    R0, R8, #1
    ITT     CS
    MOVCS   R1, R0
    BCS     _kfree_end

    LSR     R8, R8, #5
    LSL     R8, R8, R5
    CMP     R8, R6
    ITT     NE
    MOVNE   R0, R1
    BNE     _kfree_end
    ADD     R0, R1, R5
    MOV     R9, #0
    STRH    R9, [R0]

    LSL     R6, R6, #1
    STRH    R6, [R1]

    BL      _rfree
    B       _kfree_end          

_rfree_odd
    SUB     R0, R1, R5
    CMP     R0, R3
    ITT     LT
    MOVLT   R0, #0
    BLT     _kfree_end

    SUB     R0, R1, R5
; r8 - mcb_buddy
    LDRH    R8, [R0]
    LSR     R8, R8, #5
    LSL     R8, R8, #5
    CMP     R8, R6
    ITT     NE
    MOVNE   R0, R1
    BNE     _kfree_end

    MOV     R9, #0
    STRH    R9, [R1]
    LSL     R6, R6, #1
    SUB     R0, R1, R5
    STRH    R6, [R0]

    SUB     R1, R1, R5
    BL      _rfree
    B       _kfree_end
_kfree_end
    POP     {R1-R12, LR}
    BX      LR    
	
	END