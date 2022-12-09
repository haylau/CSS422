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
		; R0 = ptr
		; R1 = size
		PUSH 	{R1-R12,LR}		; save registers
		MOV		R2, #0			; R2 = 0
_bzero_loop
		STRB	R2, [R0], #1	; set [R0] to zero
		SUBS	R1, R1, #1		; decrement pointer
		BGE		_bzero_loop		; if R1 >= 1, repeat loop
		
		POP 	{R1-R12,LR}		; restore registers
		BX		LR				; return




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
; R0 = dest
; R1 = src
; R2 = size
	PUSH 	{R1-R12,LR}		; save registers
		
_strncpy_loop
	LDRB	R3, [R1], #1	; grab byte from src and increment pointer
	CMP		R3, #0			; check if char is null
	BEQ 	_strncpy_end	; if null, stop copying
	STRB	R3, [R0], #1	; store byte to dst and increment pointer
	SUBS	R2, R2, #1		; decrement pointer
	BGE 	_strncpy_loop	; if R2 >= 1, repeat loop
_strncpy_end
	POP 	{R1-R12,LR}		; restore registers
	BX		LR				; return

		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; void* _malloc( int size )
; Parameters
;	size	- #bytes to allocate
; Return value
;   void*	a pointer to the allocated space
		EXPORT	_malloc
_malloc
; R0 = size
	PUSH 	{R1-R12,LR}		
	
	MOV		R1, R0
	BL		_kalloc

	POP 	{R1-R12,LR}	
	BX		LR

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; void _free( void* addr )
; Parameters
;	size	- the address of a space to deallocate
; Return value
;   none
		EXPORT	_free
_free
; R0 = addr
	PUSH 	{R1-R12,LR}		

	MOV		R1, R0
	BL		_kfree

	POP 	{R1-R12,LR}	
	BX		LR