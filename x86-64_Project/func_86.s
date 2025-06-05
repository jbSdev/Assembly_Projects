section .bss
        ; Header
        Img_width       resd	1 
        Img_height      resd	1 
        Img_bpl         resd	1 
        Img_padding     resd	1 
        Img_pixelcount  resd	1 
        Img_pxoffset    resd	1

	header		resq	1
        bitmap          resq	1
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

section .text
        global  find_markers

find_markers:
        push    rbx
        mov     [header], rdi        ; pointer to BMP
        mov     [X_table], rsi
        mov     [Y_table], rdx

        call    getHeader

        call    findMarkers

fin:
        mov     rax, [markerCount]
        pop     rbx
        ret

getHeader:
        mov     rsi, [header]

        ; Check filetype
        xor     eax, eax
        mov     ax, word [rsi]
        cmp     ax, 0x4D42
        jne     fileTypeError

        ; Width
        mov     eax, [rsi + 0x12]
        mov     [Img_width], eax

        ; Height
        mov     ebx, [rsi + 0x16]
        mov     [Img_height], ebx

        ; PixelCount
        imul    eax, ebx
        mov     [Img_pixelcount], eax

        ; Bits Per Line
        movzx   eax, word [Img_width]
        lea     eax, [rax + 2*rax + 3]
        shr     eax, 2
        shl     eax, 2
        mov     [Img_bpl], eax

        ; Padding
        movzx   ebx, word [Img_width]
        lea     ebx, [rbx + 2*rbx]
        sub     eax, ebx
        mov     [Img_padding], eax

        ; Pixel offset
        mov     eax, [rsi + 0x0A]
        test    eax, eax
        jz      fileTypeError
        mov     [Img_pxoffset], eax

        ; Bitmap pointer
        lea     rax, [rsi + rax]
        test    rax, rax
        jz      fileTypeError
        mov     [bitmap], rax

        xor     eax, eax
        ret

fileTypeError:
        mov     eax, 1010
        ret

;------------------------------------------------;

findMarkers:
        mov     rsi, [bitmap]
        movzx   rax, word [Img_height]
        dec     rax
        mul     dword [Img_bpl]
        add     rsi, rax

findLoop:	
	xor	rcx, rcx
        mov     rcx, [counter]
	cmp	ecx, [Img_pixelcount]
        jge     findEnd

        movzx	rcx, word [baseY]
        cmp     ecx, [Img_height]
        jge     findEnd

        cmp     dword [markerCount], 50
        je      findEnd

	mov	rdx, [rsi]
	and	rdx, 0x0000000000FFFFFF
	jnz	nextPixel

        ; pixel is possible base of a marker
        mov     rdi, rsi
        movzx 	rcx, word [baseX]
        mov     word [tempX], cx
        call    goRight
        mov     word [markerLength], cx

        mov     rdi, rsi
        movzx   rcx, word [baseY]
        mov     word [tempY], cx
	movzx	rdx, word [baseX]
	mov	word [tempX], dx
        call    goDown

        cmp     cx, word [markerLength]
        jne     nextPixel

        cmp     word [markerLength], 2
        jl      nextPixel

	mov	rdi, [bitmap]
	mov	rax, [Img_height]
	sub	rax, 2		; normal + go one down
	movzx	rdx, word [baseY]
	sub	rax, rdx
	mul	dword [Img_bpl]
	add	rdi, rax

	movzx	rax, word [baseX]
	inc	rax
	lea	rax, [rax + 2*rax]
	add	rdi, rax

        movzx   rax, word [baseX]
        inc     rax
        movzx   rbx, word [baseY]
        inc     rbx

        call    goDiag

        ;mov     cx, [markerWidth]
        ;cmp     cx, [markerLength]
        ;je      nextPixel

        ;call    checkEdges

        call    saveCoords

        jmp     nextPixel

findEnd:
        ret

nextPixel:
        inc     word [baseX]
        inc     dword [counter]
        add     rsi, 3

	xor	rcx, rcx
        mov	cx, word [baseX]
        cmp     cx, [Img_width]
        jne     findLoop

        mov     word [baseX], 0
        inc     word [baseY]

	mov	rsi, [bitmap]
	mov	rax, [Img_height]
	dec	rax
	movzx	rcx, word [baseY]
	sub	rax, rcx
	mul	dword [Img_bpl]
	add	rsi, rax

        jmp     findLoop

;------------------------------------------------;

goRight:
        cmp     cx, [Img_width]
        je      foundRight

        mov     rdx, [rdi]
        and     rdx, 0x0000000000FFFFFF
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

        mov     rdx, [rdi]
        and     rdx, 0x0000000000FFFFFF
        jnz     foundDown

        inc     cx

	mov	rdi, [bitmap]
	mov	rax, [Img_height]
	dec	rax
	sub	rax, rcx
	mul	dword [Img_bpl]
	add	rdi, rax
	movzx	rax, word [tempX]
	lea	rax, [rax + 2*rax]
	add	rdi, rax

        jmp     goDown

foundDown:
        sub     cx, [tempY]
        ret

;------------------------------------------------;
;       ax - temp X
;       bx - temp Y
goDiag:
;push	rax
;call	printSpace
;call	printDecimal
;call	printSpace
;mov	rax, rbx
;call	printDecimal
;call	printSpace
;mov	rax, rsi
;call	printDecimal
;call	printSpace
;mov	rax, rdi
;call	printDecimal
;call	printNewline
;pop	rax

        cmp     eax, [Img_width]
        je      endDiag
        cmp     ebx, [Img_height]
        je      endDiag

        mov	rcx, rax
        sub     cx, word [baseX]
        mov     [markerWidth], cx

        mov     rdx, [rdi]
        and     rdx, 0x0000000000FFFFFF
        jnz     foundDiag

        xor     rcx, rcx

        push    rdi
        movzx   rcx, ax
        mov     word [tempX], ax
        call    goRight
        mov     [tempLength], cx
        pop     rdi

        push    rdi
        movzx   rcx, bx
	mov	word [tempX], ax
        mov     word [tempY], bx
        call    goDown
        pop     rdi

        ;cmp     cx, word [tempLength]
        ;jne     endDiag

        ;movzx   ecx, word [markerWidth]
        ;add     cx, word [tempLength]
        ;cmp     cx, word [markerLength]
        ;jne     endDiag

        inc     rax
        inc     rbx
        ;add     rdi, 3
        ;sub     rdi, [Img_bpl]

	;push	rax
	;mov	rdi, [bitmap]
	;mov	rax, [Img_height]
	;dec	rax
	;sub	rax, rbx
	;mul	dword [Img_bpl]
	;add	rdi, rax
	;pop	rax
	;lea	rdx, [rax + 2*rax]
	;add	rdi, rax

        jmp     goDiag

foundDiag:
        ret

incWidth:
        inc     word [markerWidth]
        ret

endDiag:
	pop	rdx
        jmp     nextPixel

;------------------------------------------------;

checkEdges:
push	rax
movzx	rax, word [baseX]
call	printDecimal
call	printSpace
movzx	rax, word [baseY]
call	printDecimal
call	printNewline
pop	rax

        mov     rdi, rsi
        add     rdi, [Img_bpl]
        movzx   rax, word [baseX]
        movzx   rbx, word [baseY]
        call    checkUpper

	mov	rdi, rsi
	sub	rdi, 3
        movzx   rax, word [baseX]
        movzx   rbx, word [baseY]
        call    checkLeft

        movzx   ecx, word [markerLength]
        sub     cx, [markerWidth]
        mov     [hangingLength], cx

        push    rax
        mov     rdi, rsi
        movzx   rax, word [markerWidth]
        lea     rcx, [rax + 2*rax]
        add     rdi, rcx
        mul    	dword [Img_bpl]
        sub     rdi, rax
        pop     rax

        movzx   rax, word [baseX]
        add     rax, [markerWidth]
        mov     rcx, rax

        call    checkBottom

        ;push    rax
        ;mov     rdi, rsi
        ;movzx   rax, word [markerWidth]
        ;lea     rcx, [rax + 2*rax]
        ;add     rdi, rcx
        ;mul   	dword [Img_bpl]
        ;sub     rdi, rax
        ;pop     rax

        ;movzx   rbx, word [baseY]
        ;add     rbx, [markerWidth]
        ;movzx   rcx, bx

        ;call    checkRight

        ret

checkUpper:
        test    bx, bx
        jz      returnCheck

        movzx   rcx, ax
        sub     cx, [baseX]
        cmp     cx, [markerLength]
        je      returnCheck

        mov     rdx, [rdi]
        and     rdx, 0x0000000000FFFFFF
        jz      endCheck

        inc     rax
        add     rdi, 3
        jmp     checkUpper

checkLeft:
        test    ax, ax
        jz      returnCheck

        movzx  	rcx, bx
        sub     cx, [baseY]
        cmp     cx, [markerLength]
        je      returnCheck

        mov     rdx, [rdi]
        and     rdx, 0x0000000000FFFFFF
        jz      endCheck

        inc     bx

	mov	rdi, [bitmap]
	push	rax
	mov	rax, [Img_height]
	dec	rax
	sub	rax, rbx
	mul	dword [Img_bpl]
	add	rdi, rax
	pop	rax
	lea	rcx, [rax + 2*rax]
	add	rdi, rcx

        jmp     checkLeft

checkBottom:
        cmp	ebx, [Img_height]
	je	returnCheck

        mov	rdx, rax
        sub     dx, cx
        cmp     dx, [hangingLength]
        je      returnCheck

        mov     rdx, [rdi]
        and     rdx, 0x0000000000FFFFFF
        jz      endCheck

        inc     ax
        add     rdi, 3
        jmp     checkBottom

checkRight:

	cmp	ebx, [Img_height]
	jge	returnCheck

        movzx   edx, bx
        sub     dx, cx
        cmp     dx, [hangingLength]
        je      returnCheck

        mov     rdx, [rdi]
        and     rdx, 0x0000000000FFFFFF
        jz      endCheck

        inc     bx

	push	rax
	mov	rax, [Img_height]
	dec	rax
	sub	rax, rbx
	mul	dword [Img_bpl]
	add	rdi, rax
	pop	rax
	lea	rcx, [rax + 2*rax]
	add	rdi, rax

        jmp     checkRight

returnCheck:
        ret

endCheck:
	pop	rdx
	pop	rdx
        jmp     nextPixel

;------------------------------------------------;
printCoords:
        push    rax
        movzx   eax, word [baseX]
        call    printDecimal
        call    printSpace
        movzx   eax, word [baseY]
        call    printDecimal
        call    printSpace
        mov     eax, [counter]
        call    printDecimal
        call    printNewline
        pop     rax
        ret

printDecimal:
        push    rax
        push    rbx
        push    rcx
        push    rdx
	push	rdi
        push    rsi

        xor     rcx, rcx
        mov     ebx, 10

        mov     rsi, buf + 11
        mov     byte [rsi], 0

convert:
        xor     edx, edx
        div     ebx
        add     dl, '0'
        dec     rsi
        mov     [rsi], dl
        inc     rcx
        test    eax, eax
        jnz     convert

        ; print
        mov     eax, 1          ; sys_write
        mov     edi, 1          ; fd=stdout
        mov     rsi, rsi        ; buf
        mov     edx, ecx        ; len
        syscall

        pop     rsi
	pop	rdi
        pop     rdx
        pop     rcx
        pop     rbx
        pop     rax
        ret

printNewline:
        push    rax
        push    rdi
        push    rsi
        push    rdx

        mov     rax, 1
        mov     rdi, 1
        mov     rsi, newline
        mov     rdx, 1
        syscall

        pop     rdx
        pop     rsi
        pop     rdi
        pop     rax
        ret

printSpace:
        push    rax
        push    rdi
	push	rsi
	push	rdx

        mov     rax, 1
        mov     rdi, 1
        mov     rsi, space
        mov     rdx, 1
        syscall

        pop     rdx
        pop     rsi
        pop     rdi
        pop     rax
        ret

saveCoords:
	xor	rax, rax
        movzx   eax, word [baseY]
        movzx   ebx, word [Img_height]
        cmp     eax, ebx
        je      skipSave

        mov     eax, [markerCount]
        mov     rbx, [X_table]
        lea     rbx, [rbx + rax*4]
        movzx   ecx, word [baseX]
        mov     [rbx], ecx

        mov     eax, [markerCount]
        mov     rbx, [Y_table]
        lea     rbx, [rbx + rax*4]
        movzx   ecx, word [baseY]
        mov     [rbx], ecx

        inc     dword [markerCount]

skipSave:
        ret

