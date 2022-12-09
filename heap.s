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

MCB_INIT_A      EQU     0x20001000
MCB_INIT_A_N    EQU     0x00004000
MCB_INIT_B      EQU     0x20006804
MCB_INIT_B_N    EQU     0x000003FC

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
    IMPORT  _bzero
    PUSH    {R1-R12, LR}

    LDR     R0, =MCB_INIT_A
    LDR     R1, =MCB_INIT_A_N
    BL      _bzero

    LDR     R0, =MAX_SIZE
    LDR     R1, =MCB_TOP
    LDRH    R0, [R1]

    LDR     R0, =MCB_INIT_B
    LDR     R1, =MCB_INIT_B_N
    BL      _bzero

    B       _return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Kernel Memory Allocation
; void* _k_alloc( int size )
; size              - size of requested memory space 
; return            - address of SRAM space
    EXPORT  _kalloc
_kalloc
    PUSH    {R1-R12, LR}      
; r0 = return
; r1 = size
    BL      _ralloc
    B       _return
; recursive helper for kalloc
_ralloc
; r2 = left_mcb_addr
    LDR     R2, =MCB_TOP
; r3 = right_mcb_addr
    LDR     R3, =MCB_BOT
; r4 = MCB_ENT_SZ
    LDR     R4, =MCB_ENT_SZ
; r5 = entire_mcb_addr_space
    SUB     R5, R3, R2          ; right_mcb_addr - left_mcb_addr
    ADD     R5, R5, R4          ; r4 += MCB_ENT_SZ
; r6 = half_mcb_addr_space
    LSR     R6, R5, #1          ; half_mcb_addr_space = entire_mcb_addr_space / 2
; r7 = midpoint_mcb_addr
    ADD     R7, R2, R6          ; midpoint_mcb_addr = left_mcb_addr + half_mcb_addr_space
; r8 = head_addr
    MOV     R8, #0              ; heap_addr = 0 
; r9 = act_entire_heap_size
    LSL     R9, R5, #4          ; act_entire_heap_size = entire_mcb_addr_space * 16
; r10 = act_half_heap_size
    LSL     R10, R6, #4         ; act_half_heap_size = half_mcb_addr_space * 16 
; r11 = mbc_top
    LDR     R11, =MCB_TOP
; if (size <= act_half_heap_size)
    CMP     R1, R10
    BLE     _ralloc_r

; base case 
; r0 = return from recursive call
    PUSH    {R3}
; r1 = size (no change)
; r2 = left_mcb_addr (no change)
; r3 = midpoint_mcb_addr - MCB_ENT_SZ
    SUB     R3, R7, R4
    BL      _ralloc
    POP     {R3}
    MOV     R8, R0

    CMP     R8, #0
; r1 = size (no change)
; r2 = midpoint_mcb_addr
    MOV     R2, R7
; r3 = right_mcb_addr (no change)
    BL      _ralloc
    B       _return             ; return heap_addr (r0)  

    LDR     R0, [R7]            
    LSRS    R0, R0, #1          ; set C if odd
    LDRHCC  R7, R10             ; load halfword at midpoint_mcb_addr

    MOV     R0, R8              ; return heap_addr
    B       _return                  
_ralloc_r
; recursive case
; if addr is even return 0;
    LDR     R0, [R2]
    LSRS    R0, R0, #1          ; set C if odd

    ITT     CC
    MOVCC   R0, #0
    BCC     _return

; addr is below heap range return 0;
    LDRH    R0, [R2]
    CMP     R0, R9
    ITT     LT
    MOVLT   R0, #0
    BLT     _return

; stores heap size with LSB set to 1 
    ORR     R0, R9, #1
    LDRH    R0, [R2]

; return next heap ptr
    SUB     R0, R2, R11
    LSL     R0, R0, #4
    ADD     R0, R0, R11
    B       _return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Kernel Memory De-allocation
; void *_kfree( void *ptr )	
; ptr               - pointer to the memory space to be deallocated
    EXPORT  _kfree
_kfree
    ; r0 = return
    ; r1 = ptr

    PUSH    {R1-R12, LR}

    LDR     R2, =HEAP_TOP
    LDR     R3, =HEAP_BOT

    CMP     R1, R2
    ITT     LT
    MOVLT   R0, #0
    BLT     _return   

    CMP     R1, R3
    ITT     GT
    MOVGT   R0, #0
    BGT     _return

    LDR     R4, =MCB_TOP
    ADD     R4, R4, R1
    SUB     R4, R4, R2
    LSR     R4, R4, #4

    PUSH    {R1}
    MOV     R1, R4
    BL      _rfree
    POP     {R1}
    CMP     R0, #0
    ITTEE   EQ
    MOVEQ   R0, #0
    BEQ    _return
    MOVNE   R0, R1
    BNE    _return

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

    DIV     R0, R4, R5
    RORS    R0, R0, #1
    BCS     _rfree_odd

    ADD     R0, R1, R5
    CMP     R0, R7
    ITT     GE
    MOVGE   R0, #0
    BGE     _return

    ADD     R0, R1, R5
; r8 = mcb_buddy
    LDRH    R8, [R0]
    RORS    R0, R8, #1
    ITT     CS
    MOVCS   R1, R0
    BCS     _return

    LSR     R8, R8, #5
    LSL     R8, R8, R5
    CMP     R8, R6
    ITT     NE
    MOVNE     R0, R1
    BNE     _return
    ADD     R0, R1, R5
    MOV     R9, #0
    STRH    R9, [R0]

    LSL     R6, R6, #1
    STRH    R6, [R1]

    BL      _rfree
    B       _return          

_rfree_odd
    SUB     R0, R1, R5
    CMP     R0, R3
    ITT     LT
    MOVLT   R0, #0
    BLT     _return

    SUB     R0, R1, R5
; r8 - mcb_buddy
    LDRH    R8, [R0]
    LSR     R8, R8, #5
    LSL     R8, R8, #5
    CMP     R8, R6
    ITT     NE
    MOVNE   R0, R1
    BNE     _return

    MOV     R9, #0
    STRH    R9, [R1]
    LSL     R6, R6, #1
    SUB     R0, R1, R5
    STRH    R6, [R0]

    SUB     R1, R1, R5
    BL      _rfree
    B       _return

; standard return protocol
_return       
    POP     {R1-R12, LR}
    BX      LR