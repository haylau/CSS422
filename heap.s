        AREA	|.text|, CODE, READONLY, ALIGN=2
        THUMB

HEAP_TOP        EQU     0x20001000
HEAP_BOT        EQU     0x20004FE0
HEAP_BOUND      EQU     0x20005000

MAX_SIZE        EQU     0x00004000
MIN_SIZE        EQU     0x00000020

MCB_TOP         EQU     0x20006800
MCB_BOT         EQU     0x20006BFE
MCB_LBOUND      EQU     0x20006804
MCB_UBOUND      EQU     0x20006C00
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
    STR		R1, [R0]
    MOV		R2, #0

    LDR		R0, =HEAP_TOP
    LDR     R1, =HEAP_BOUND
_kinit_heap
    CMP		R0, R1
    ; jump to next loop
    ITTT    GT
    LDRGT   R0, =MCB_LBOUND
    LDRGT   R1, =MCB_UBOUND
    BGE		_kinit_mcb
    STRH	R2, [R0], #2
    B		_kinit_heap
_kinit_mcb	
    CMP		R0, R1
    BGE     _kinit_end
    STRB	R2, [R0], #1
    B		_kinit_mcb
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
    PUSH    {LR}        
; r0 = size
; r1 = MCB_TOP
    LDR     R1, =MCB_TOP
; r2 = MCB_BOT 
    LDR     R2, =MCB_BOT
    BL      _ralloc
    POP     {LR}  
    BX      LR

; recursive helper for kalloc
_ralloc
    PUSH	{LR}
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

; base case : size > act_half_heap_size
    CMP     R0, R9
    BGT     _ralloc_tophalf ; base case

    PUSH    {R1-R12}
    MOV		R10, R0		; preserve r0
    SUB     R2, R6, R3  ; right = midpoint - mcb_ent_size
    BL      _ralloc
    POP     {R1-R12}
    MOV     R7, R0      ; heap_addr = ralloc(  )
    MOV		R0, R10		; restore r0

    CMP     R7, #0
    BEQ     _ralloc_ptrzero

    LDR     R10, [R6]
    LSRS    R10, R10, #1
    STRHCC  R9, [R6]

    MOV     R0, R7      ; return heap_addr
    B       _kalloc_end

_ralloc_ptrzero

; if heap_addr == 0 --> return ralloc(size, midpoint, right)
    MOV     R1, R6      ; left = midpoint
    BL      _ralloc          
    B       _kalloc_end

_ralloc_tophalf

; if *left_mcb_addr is odd --> return 0
    LDR     R10, [R1]
    LSRS    R10, R10, #1
    ITT     CS
    MOVCS   R0, #0
    BCS     _kalloc_end

; if *left_mcb_addr < act_entire_heap_size --> return 0 
    LDRH    R10, [R1]
    CMP     R10, R8
    ITT     LT
    MOVLT   R0, #0
    BLT     _kalloc_end

; *left_mcb_addr = act_entire_heap_size | 1
    ORR     R10, R8, #1
    STRH    R10, [R1]
; return (heap_top + (left_mcb_addr - mcb_top) * 16)
    LDR     R10, =MCB_TOP
    SUB     R10, R1, R10
	LSL     R10, R10, #4
    LDR     R11, =HEAP_TOP
    ADD     R0, R11, R10
    B       _kalloc_end

_kalloc_end
    POP     {LR}
    BX      LR    

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Kernel Memory De-allocation
; void *_kfree( void *ptr )	
; ptr               - pointer to the memory space to be deallocated
    EXPORT  _kfree
_kfree
; r0 = addr | param0
    PUSH    {LR}
; r1 = addr
    MOV		R1, R0
; r2 = heap_ top
    LDR     R2, =HEAP_TOP
; r3 = heap_bot
    LDR     R3, =HEAP_BOT
; if (addr < heap_top) return nullptr
    CMP     R1, R2
    ITT     LT
    MOVLT   R0, #0
    BLT     _kfree_end   
; if (addr > heap_bot) return nullptr
    CMP     R1, R3
    ITT     GT
    MOVGT   R0, #0
    BGT     _kfree_end
; mcb_top + (addr - heap_top) / 16;
; offset heap addr to mcb arr
    LDR     R0, =MCB_TOP
    SUB     R4, R1, R2	; addr - heap_top
    LSR     R4, R4, #4	;(addr - heap_top) / 16
    ADD     R4, R4, R0	; mcb_top + (addr - heap_top) / 16
; subroutine call
    PUSH    {R1}        ; preserve addr
    MOV     R0, R4      ; param0 = ptr
    BL      _rfree      ; r0 = return    
    POP     {R1}        ; restore addr
    ; if _rfree( ) == nullptr
    CMP     R0, #0      
    ITE    EQ          
    MOVEQ   R0, #0        ; return nullptr
    MOVNE   R0, R1        ; else return addr
    B       _kfree_end

; recursive helper for kfree
_rfree
    PUSH    {LR}
; r0 = mcb_addr | param0

; r1 - mcb_addr
    MOV     R1, R0
; r2 - *mcb_addr --> mcb_contents
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

; store free'd bytes
    STRH    R2, [R1]    

; if mcb has used bit
    UDIV    R0, R4, R5
    LSRS    R0, R0, #1
    BCS     _rfree_used

; if mcb_buddy is outside mcb region
    ADD     R0, R1, R5
    CMP     R0, R7
    ITT     GE
    MOVGE   R0, #0
    BGE     _kfree_end

; r8 = mcb_buddy = *(mcb_addr + mcb_disp)
    ADD     R8, R1, R5
    LDRH    R8, [R8]
; if mcb_buddy does not have cleared 
    LSRS    R0, R8, #1
    ITT     CS
    MOVCS   R1, R0
    BCS     _kfree_end
; clear [LSB+5, LSB] region
    LSR     R8, R8, #5
    LSL     R8, R8, R5

; if !(mcb_buddy = my_size) return mcb_addr
    CMP     R8, R6
    ITT     NE
    MOVNE   R0, R1
    BNE     _kfree_end
; clear mcb_addr + mcb_disp
    ADD     R0, R1, R5
    MOV     R9, #0
    STRH    R9, [R0]
; my_size *= 2 / merge regions
    LSL     R6, R6, #1
; store doubled region
    STRH    R6, [R1]
    PUSH    {LR}
    BL      _rfree
    POP     {LR}
    B       _kfree_end          

_rfree_used
; if (mcb_addr - mcb_disp < mcb_top) 
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
    PUSH    {LR}
    BL      _rfree
    POP     {LR}
    B       _kfree_end

_kfree_end
    POP     {LR}
    BX      LR    
    
    END