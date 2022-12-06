		AREA	|.text|, CODE, READONLY, ALIGN=2
		THUMB

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; void _bzero( void *ptr, int size )
; Parameters
;	ptr 		- pointer to the memory location to zero-initialize
;	size		- a number of bytes to zero-initialize
; Return value
;   none
		EXPORT	_bzero
_bzero
		; r0 = ptr
		; r1 = size
		PUSH 	{r1-r12,lr}		; save registers
		MOV		R2, #0			; R2 = 0
_bzero_loop
		STRB	R2, [R0], #1	; set [r0] to zero
		SUBS	R1, R1, #1		; decrement pointer
		BGE		_bzero_loop		; if r1 >= 1, repeat loop
		
		POP 	{r1-r12,lr}		; restore registers
		BX		lr				; return




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; char* _strncpy( char* dest, char* src, int size )
; Parameters
;   dest 	- pointer to the buffer to copy to
;	src		- pointer to the zero-terminated string to copy from
;	size	- a total of n bytes
; Return value
;   dest
		EXPORT	_strncpy
_strncpy
		; r0 = dest
		; r1 = src
		; r2 = size
		PUSH 	{r1-r12,lr}		; save registers
		
_strncpy_loop
		LDRB	R3, [R1], #1	; grab byte from src and increment pointer
		CMP		R3, #0			; check if char is null
		BEQ 	_strncpy_end	; if null, stop copying
		STRB	R3, [R0], #1	; store byte to dst and increment pointer
		SUBS	R2, R2, #1		; decrement pointer
		BGE 	_strncpy_loop	; if r2 >= 1, repeat loop
_strncpy_end
		POP 	{r1-r12,lr}		; restore registers
		BX		lr				; return

		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; void* _malloc( int size )
; Parameters
;	size	- #bytes to allocate
; Return value
;   void*	a pointer to the allocated space
		EXPORT	_malloc
_malloc
		; r0 = size
		PUSH {r1-r12,lr}		
		; you need to add some code here for part 2 implmentation
		POP {r1-r12,lr}	
		BX		lr

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; void _free( void* addr )
; Parameters
;	size	- the address of a space to deallocate
; Return value
;   none
		EXPORT	_free
_free
		; r0 = addr
		PUSH {r1-r12,lr}		
		; you need to add some code here for part 2 implmentation
		POP {r1-r12,lr}	
		BX		lr