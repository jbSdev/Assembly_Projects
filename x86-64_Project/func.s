section .bss
        ; Header
        Img_width       resd	1 
        Img_height      resd	1 
        Img_bpl         resd	1 
        Img_padding     resd	1 
        Img_pixelcount  resd	1 
        Img_pxoffset    resd	1

        bitmap          resq	1
	header		resq	1
        X_table         resq	1
        Y_table         resq	1

        ; Variable data
        markerLength    resw	1
        tempLength      resw	1
        markerWidth     resw	1
        tempWidth       resw	1
        hangingLength   resw    1

section .data
        counter         dd      0
        markerCount     dd      0

        baseX           dw 	0
        baseY           dw 	0
        tempX           dw 	0
        tempY           dw 	0

        ; characters
        buf             db      12 dup(0)
        newline         db      0xA, 0
        space           db      0x20, 0
        text            db      "line", 10
        found           db      "found -> "

section .text
        global  find_markers

find_markers:
        push    rbp
        mov     rbp, rsp
        push    rbx

	mov	[header],  rdi
        mov     [X_table], rsi
        mov     [Y_table], rdx


        call    getHeader

        call    findMarkers

fin:
	mov	rax, [markerCount]
        pop     rbx
        pop     rbp
        ret

getHeader:
	mov	rsi, [header]
        ; Check filetype
        xor     rax, rax
        mov     ax, [rsi]
        cmp     ax, 0x4D42              ; .bmp file marker
        jne     fileTypeError

        ; Width
        mov     eax, [rsi + 0x12]
        mov     [Img_width], eax

        ; Height
        mov     ebx, [rsi+ 0x16]
        mov     [Img_height], ebx

        ; PixelCount
        mul     rbx                     ; width * height
        mov     [Img_pixelcount], eax

        ; Bits Per Line
	xor	rax, rax
        mov  	ax, word [Img_width]
        lea     eax, [eax + 2*eax + 3]
        shr     eax, 2
        shl     eax, 2
        mov     [Img_bpl], eax

        ; Padding
        movzx  	ebx, word [Img_width]
        lea     ebx, [ebx + 2*ebx]      ; padding at the end of line
        sub     eax, ebx
        mov     [Img_padding], eax

        ; Pixel offset
	xor	eax, eax
        mov     eax, dword [rsi + 0x0A]
        test    eax, eax
        jz      fileTypeError
        mov     [Img_pxoffset], eax

        ; Bitmap pointer
        lea     rax, [rsi + rax]
        test    rax, rax
        jz      fileTypeError
        mov     [bitmap], rax

        ret

fileTypeError:
        mov     rax, 1010
        ret

;------------------------------------------------;

findMarkers:
        mov     rsi, [bitmap]
        movzx   eax, word [Img_height]
        dec     eax
        mul     dword [Img_bpl]
        add     rsi, rax                ; points to (0,0) - top left corner

        mov     word [baseX], 0

findLoop:
	movzx	rax, word [baseX]
	call	printDecimal
	call	printSpace
	movzx	rax, word [baseY]
	call	printDecimal
	call	printSpace
	mov	rax, [counter]
	call	printDecimal
	call	printNewline

	xor	ecx, ecx
        mov     rcx, [counter]
	mov	rdx, [Img_pixelcount]
        cmp     rcx, rdx
        jz      findEnd

        movzx   rcx, word [baseY]
	mov	rdx, [Img_height]
        cmp     rcx, rdx
	je      findEnd

        cmp     dword [markerCount], 50
        je      findEnd

        mov     edx, [rsi]
        and     edx, 0x00FFFFFF         ; EDX = 0x00RRGGBB
        jnz     nextPixel

        ; pixel is possible base of a marker
	;xor	rcx, rcx
        ;mov     rdi, rsi
        ;mov     cx, word [baseX]
        ;mov     word [tempX], cx
        ;call    goRight
        ;mov     word [markerLength], cx

        ;mov     rdi, rsi
        ;mov     cx, [baseY]
        ;mov     word [tempY], cx
        ;call    goDown
        ;
        ;; arms not equal in length
        ;cmp     cx, word [markerLength]
        ;jne     nextPixel

        ;; if it's a single pixel
        ;cmp     word [markerLength], 2
        ;jl      nextPixel

       ; ; check diagonal pixels
       ; lea     rdi, [rsi + 3]
       ; sub     rdi, qword [Img_bpl]

       ; movzx   eax, word [baseX]
       ; inc     ax
       ; movzx   ebx, word [baseY]
       ; inc     bx

       ; call    goDiag

       ; mov     cx, [markerWidth]
       ; cmp     cx, [markerLength]
       ; je      nextPixel               ; big square

       ; call    checkEdges
        
        call    saveCoords

        jmp     nextPixel

findEnd:
        ret

nextPixel:
	;mov	rax, [counter]
	;call	printDecimal

        inc     word [baseX]
        inc     dword [counter]
        add     rsi, 3

	xor	rcx, rcx
        mov     cx, word [baseX]
        cmp     cx, [Img_width]
        jne     findLoop

        mov     word [baseX], 0
        inc     word [baseY]

        add     rsi, [Img_padding]
        sub     rsi, [Img_bpl]
        sub     rsi, [Img_bpl]


        jmp     findLoop

;------------------------------------------------;

goRight:
        cmp     cx, [Img_width]
        je      foundRight

        mov     edx, [rdi]
        and     edx, 0x00FFFFFF
        jnz     foundRight

        add     rdi, 3
        inc     cx
        jmp     goRight

foundRight:
        sub     cx, [tempX]
        ret

goDown:
        cmp     cx, [Img_height]
        je      foundDown

        mov     edx, [rdi]
        and     edx, 0x00FFFFFF
        jnz     foundDown

        sub     rdi, [Img_bpl]
        inc     cx
        jmp     goDown

foundDown:
        sub     cx, [tempY]
        ret

;------------------------------------------------;
;       ax - temp X
;       bx - temp Y
goDiag:
        cmp     ax, [Img_width]
        je      endDiag
        cmp     bx, [Img_height]
        je      endDiag

        movzx   ecx, ax
        sub     cx, word [baseX]
        mov     [markerWidth], cx

        mov     edx, [rdi]
        and     edx, 0x00FFFFFF
        jnz     foundDiag

        ; pixel is black
        xor     rcx, rcx

	mov	r8, rdi
        mov     cx, ax
        mov     word [tempX], ax
        call    goRight
        mov     [tempLength], cx
	mov	rdi, r8

        mov     cx, bx
        mov     word [tempY], bx
        call    goDown
	mov	rdi, r8

        cmp     cx, word [tempLength]
        jne     endDiag                 ; internal arms not equal

        movzx   ecx, word [markerWidth]
        add     cx, word [tempLength]
        cmp     cx, word [markerLength]
        jne     endDiag

        ; move to the next diagonal pixel
        inc     ax
        inc     bx
        add     rdi, 3
        sub     rdi, [Img_bpl]

        jmp     goDiag

foundDiag:
        ret

incWidth:
        inc     word [markerWidth]
        ret

endDiag:
        pop     rdx
        jmp     nextPixel

;------------------------------------------------;

checkEdges:
        mov     rdi, rsi
        add     edi, [Img_bpl]
        movzx   eax, word [baseX]
        movzx   ebx, word [baseY]
        call    checkUpper

        lea     rdi, [rsi - 3]
        movzx   eax, word [baseX]
        movzx   ebx, word [baseY]
        call    checkLeft

        movzx   ecx, word [markerLength]
        sub     cx, [markerWidth]
        mov     [hangingLength], cx

        mov     rdi, rsi
        movzx   r9d, word [markerWidth]
        lea     ecx, [r9d + 2*r9d]
        add     rdi, rcx
        mul     dword [Img_bpl]
        sub     rdi, r9

        movzx   eax, word [baseX]
        add     ax, [markerWidth]
        movzx   ecx, ax

        call    checkBottom

        mov     rdi, rsi
        movzx   r9d, word [markerWidth]
        lea     ecx, [r9d + 2*r9d]
        add     edi, ecx
        mul     dword [Img_bpl]
        sub     edi, r9d

        movzx   ebx, word [baseY]
        add     bx, [markerWidth]
        movzx   ecx, bx

        call    checkRight

        ret

checkUpper:
        test    bx, bx
        jz      returnCheck             ; image upper edge

        xor     ecx, ecx
        mov     cx, ax
        sub     cx, [baseX]
        cmp     cx, [markerLength]
        je      returnCheck

        mov     edx, [rdi]
        and     edx, 0x00FFFFFF
        jz      endCheck

        inc     ax
        add     rdi, 3
        jmp     checkUpper

checkLeft:
        test    ax, ax
        jz      returnCheck

        movzx   ecx, bx
        sub     cx, [baseY]
        cmp     cx, [markerLength]
        je      returnCheck

        mov     edx, [rdi]
        and     edx, 0x00FFFFFF
        jz      endCheck

        inc     bx
        sub     rdi, [Img_bpl]
        jmp     checkLeft

;       cx - saved starting point X coordinate
checkBottom:
        movzx   edx, ax
        sub     dx, cx
        cmp     dx, [hangingLength]
        je      returnCheck

        mov     edx, [rdi]
        and     edx, 0x00FFFFFF
        jz      endCheck

        inc     ax
        add     rdi, 3
        jmp     checkBottom

;       cx - saved starting point Y coordinate
checkRight:
        movzx   edx, bx
        sub     dx, cx
        cmp     dx, [hangingLength]
        je      returnCheck

        mov     edx, [rdi]
        and     edx, 0x00FFFFFF
        jz      endCheck

        inc     bx
        sub     rdi, qword [Img_bpl]
        jmp     checkRight

returnCheck:
        ret

endCheck:
        pop     rdx     ; pop retAddr from checkSides
        pop     rdx     ; pop retAddr from checkEdges
        jmp     nextPixel
;------------------------------------------------;
; adds the coordinate to the arrays
saveCoords:
	xor	rax, rax
	xor	rbx, rbx
        movzx   rax, word [baseY]
        movzx   rbx, word [Img_height]
        cmp     rax, rbx
        je      skipSave

	xor	rax, rax
        mov	eax, [markerCount]
        mov     rbx, [X_table]
        lea     rax, [rbx + 4*rax]
	xor	rbx, rbx
        movzx   rbx, word [baseX]
        mov     [rax], rbx

	xor	rax, rax
        mov	eax, [markerCount]
        mov     rbx, [Y_table]
        lea   	rax, [rbx + 4*rax]
	xor	rbx, rbx
        movzx	rbx, word [baseY]
        mov     [rax], rbx

        inc     dword [markerCount]

skipSave:
        ret


printDecimal:
	push	rax
	push	rbx
	push	rcx
	push	rdx
	push	rsi

	xor	rcx, rcx
	mov	rbx, 10

	lea	rsi, [rel buf + 10]
	mov	byte [rsi], 0

	convert:
		xor	rdx, rdx
		div	rbx
		add	dl, '0'
		dec	rsi
		mov	[rsi], dl
		inc	rcx
		test	rax, rax
		jnz	convert
	
	mov	rax, 1
	mov	rdi, 1
	mov	rsi, rsi
	mov	rdx, rcx
	syscall	

	pop	rsi
	pop	rdx
	pop	rcx
	pop	rbx
	pop	rax

	ret

printSpace:
	push	rax
	push	rbx
	push	rcx
	push	rdx
	push	rsi

	mov	rax, 1
	mov	rdi, 1
	mov	rsi, space
	mov	rdx, 1
	syscall

	pop	rsi
	pop	rdx
	pop	rcx
	pop	rbx
	pop	rax

	ret

printNewline:
	push	rax
	push	rbx
	push	rcx
	push	rdx
	push	rsi

	mov	rax, 1
	mov	rdi, 1
	mov	rsi, newline
	mov	rdx, 1
	syscall

	pop	rsi
	pop	rdx
	pop	rcx
	pop	rbx
	pop	rax

	ret
