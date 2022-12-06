3
		    AREA	|.text|, CODE, READONLY, ALIGN=2
		    THUMB

            IMPORT  _bzero

heap_top    EQU     0x20001000
heap_bot    EQU     0x20004FE0
max_size    EQU     0x00004000
min_size    EQU     0x00000020

mcb_top     EQU     0x20006800
mcb_bot     EQU     0x20003BFE
mcb_ent_sz  EQU     0x00000002
mcb_total   EQU     512     

kinit_a     EQU     0x20001000
kinit_a_n   EQU     0x4000
kinit_b     EQU     0x20006804
kinit_b_n   EQU     0x3FC 

; void _kinit()

_kinit

            PUSH    {R1-R12, LR}

            LDR     R0, =kinit_a
            LDR     R1, =kinit_a
            BL      _bzero
            LDR     R0, =kinit_b
            LDR     R1, =kinit_b_n
            BL      _bzero
            B       _return

; void* _kalloc(int size) 
; size              - size of requested memory space 
_kalloc
            ; r0 = return
            ; r1 = size
            PUSH    {R1-R12, LR}

            LDR     R2, =mcb_top
            LDR     R3, =mcb_bot

            BL      _ralloc
            B       _return

; void* _kfree(void* ptr)
; ptr               - pointer to the memory space to be deallocated
_kfree
            ; r0 = return
            ; r1 = ptr

            PUSH    {R1-R12, LR}

            LDR     R2, =heap_top
            LDR     R3, =heap_bot

            CMP     R1, R2
            ITT     LT
            MOVLT   R0, #0
            BLT     _return   

            CMP     R1, R3
            ITT     GT
            MOVGT   R0, #0
            BGT     _return

            LDR     R4, =mcb_top
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


; void* _ralloc(int size, int left_mcb_addr, int right_mcb_addr) {
; size              - the size of requested memory space
; left_mcb_addr     - the left MCB boundary
; right_mcb_addr    - the right MCB boundary
;
; return            - address of SRAM space
_ralloc
            ; r0 = return
            ; r1 = size
            ; r2 = left_mcb_addr
            ; r3 = right_mcb_addr
            PUSH    {R1-R12, LR}

            ; r4 = mcb_ent_sz
            ; r5 = entire_mcb_addr_space
            LDR     R4, =mcb_ent_sz
            SUB     R5, R3, R2          ; right_mcb_addr - left_mcb_addr
            ADD     R5, R5, R4          ; r4 += mcb_ent_sz

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
            LDR     R11, =mcb_top

            ; if (size <= act_half_heap_size)
            CMP     R1, R10
            BLE     _ralloc_r

            ; recursive case 
            ; r0 = _ralloc(size, left_mcb_addr, midpoint_mcb_addr - mcb_ent_sz);
            PUSH    {R3}
            ; r1 = size (no change)
            ; r2 = left_mcb_addr (no change)
            ; r3 = midpoint_mcb_addr - mcb_ent_sz
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
            B       _return               ; return heap_addr (r0)  

            LDR     R0, [R7]            
            LSRS    R0, R0, #1          ; set C if odd
            LDRHCC  R7, R10             ; load halfword at midpoint_mcb_addr

            MOV     R0, R8              ; return heap_addr
            B       _return                  
_ralloc_r
            ; base case
            ; if ((array[m2a(left_mcb_addr)] & 0x01) != 0) return 0;
            LDR     R0, [R2]
            LSRS    R0, R0, #1          ; set C if odd
        
            ITT     CC
            MOVCC   R0, #0
            BCC     _return

		    ; if (*(short*)&array[m2a(left_mcb_addr)] < act_entire_heap_size) return 0;
            LDRH    R0, [R2]
            CMP     R0, R9
            ITT     LT
            MOVLT   R0, #0
            BLT     _return

            ; *(short*)&array[m2a(left_mcb_addr)] = act_entire_heap_size | 0x01; 
            ORR     R0, R9, #1
            LDRH    R0, [R2]

            ; return (void*)(heap_top + (left_mcb_addr - mcb_top) * 16);
            SUB     R0, R2, R11
            LSL     R0, R0, #4
            ADD     R0, R0, R11
            B       _return

; int _rfree(int mcb_addr)
; mcb_addr              - mcb address to deallocate
_rfree
            PUSH    {R1-R12, LR}

            ; r1 - mcb_addr

            ; r2 - *mcb_addr
            LDRH    R2, [R1]
            ; r3 - mcb_top
            LDR     R3, =mcb_top
            ; r4 - mcb_index    
            SUB     R4, R1, R3
            ; r5 - mcb_disp
            LSR     R2, R2, #4
            MOV     R5, R2
            ; r6 - size
            LSL     R2, R2, #4
            MOV     R6, R2
            ; r7 - mcb_bot
            LDR     R7, =mcb_bot

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