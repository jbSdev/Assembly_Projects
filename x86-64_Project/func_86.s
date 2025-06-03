section .bss
        ; Header
        Img_width       resd	1 
        Img_height      resd	1 
        Img_bpl         resd	1 
        Img_padding     resd	1 
        Img_pixelcount  resd	1 
        Img_pxoffset    resd	1

        bitmap          resd	1
        X_table         resd	1
        Y_table         resd	1
        L_table         resd    1
        W_table         resd    1

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
        push    rbx
        mov     [X_table], rsi
        mov     [Y_table], rdx
        mov     [L_table], rcx
        mov     [W_table], r8

        mov     rdi, rdi        ; pointer to BMP
        call    getHeader

        call    findMarkers

fin:
        mov     eax, [markerCount]
        pop     rbx
        ret

getHeader:
        mov     rsi, rdi

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
        movzx   eax, word [Img_height]
        dec     eax
        imul    eax, dword [Img_bpl]
        add     rsi, rax

        mov     word [baseX], 0

findLoop:
        mov     ecx, dword [counter]
        xor     ecx, dword [Img_pixelcount]
        jz      findEnd

        movzx   ecx, word [baseY]
        cmp     ecx, [Img_height]
        je      findEnd

        cmp     dword [markerCount], 50
        je      findEnd

        mov     edx, dword [rsi]
        and     edx, 0x00FFFFFF
        jnz     nextPixel

        ; pixel is possible base of a marker
        mov     rdi, rsi
        mov     cx, word [baseX]
        mov     word [tempX], cx
        call    goRight
        mov     word [markerLength], cx

        mov     rdi, rsi
        mov     cx, [baseY]
        mov     word [tempY], cx
        call    goDown

        cmp     cx, word [markerLength]
        jne     nextPixel

        cmp     word [markerLength], 2
        jl      nextPixel

        lea     rdi, [rsi + 3]
        sub     rdi, [Img_bpl]

        movzx   eax, word [baseX]
        inc     ax
        movzx   ebx, word [baseY]
        inc     bx

        call    goDiag

        mov     cx, [markerWidth]
        cmp     cx, [markerLength]
        je      nextPixel

        call    checkEdges

        call    saveCoords

        jmp     nextPixel

findEnd:
        ret

nextPixel:
        inc     word [baseX]
        inc     dword [counter]
        add     rsi, 3

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

        mov     edx, dword [rdi]
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

        mov     edx, dword [rdi]
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

        mov     edx, dword [rdi]
        and     edx, 0x00FFFFFF
        jnz     foundDiag

        xor     ecx, ecx

        push    rdi
        mov     cx, ax
        mov     word [tempX], ax
        call    goRight
        mov     [tempLength], cx
        pop     rdi

        push    rdi
        mov     cx, bx
        mov     word [tempY], bx
        call    goDown
        pop     rdi

        cmp     cx, word [tempLength]
        jne     endDiag

        movzx   ecx, word [markerWidth]
        add     cx, word [tempLength]
        cmp     cx, word [markerLength]
        jne     endDiag

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
        jmp     nextPixel

;------------------------------------------------;

checkEdges:
        mov     rdi, rsi
        add     rdi, [Img_bpl]
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

        push    rax
        mov     rdi, rsi
        movzx   eax, word [markerWidth]
        lea     ecx, [rax + 2*rax]
        add     rdi, rcx
        imul    rax, dword [Img_bpl]
        sub     rdi, rax
        pop     rax

        movzx   eax, word [baseX]
        add     ax, [markerWidth]
        movzx   ecx, ax

        call    checkBottom

        push    rax
        mov     rdi, rsi
        movzx   eax, word [markerWidth]
        lea     ecx, [rax + 2*rax]
        add     rdi, rcx
        imul    rax, dword [Img_bpl]
        sub     rdi, rax
        pop     rax

        movzx   ebx, word [baseY]
        add     bx, [markerWidth]
        movzx   ecx, bx

        call    checkRight

        ret

checkUpper:
        test    bx, bx
        jz      returnCheck

        xor     ecx, ecx
        mov     cx, ax
        sub     cx, [baseX]
        cmp     cx, [markerLength]
        je      returnCheck

        mov     edx, dword [rdi]
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

        mov     edx, dword [rdi]
        and     edx, 0x00FFFFFF
        jz      endCheck

        inc     bx
        sub     rdi, [Img_bpl]
        jmp     checkLeft

checkBottom:
        movzx   edx, ax
        sub     dx, cx
        cmp     dx, [hangingLength]
        je      returnCheck

        mov     edx, dword [rdi]
        and     edx, 0x00FFFFFF
        jz      endCheck

        inc     ax
        add     rdi, 3
        jmp     checkBottom

checkRight:
        movzx   edx, bx
        sub     dx, cx
        cmp     dx, [hangingLength]
        je      returnCheck

        mov     edx, dword [rdi]
        and     edx, 0x00FFFFFF
        jz      endCheck

        inc     bx
        sub     rdi, [Img_bpl]
        jmp     checkRight

returnCheck:
        ret

endCheck:
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
        pop     rdx
        pop     rcx
        pop     rbx
        pop     rax
        ret

printNewline:
        push    rax
        push    rbx
        push    rcx
        push    rdx

        mov     eax, 1
        mov     edi, 1
        mov     rsi, newline
        mov     edx, 1
        syscall

        pop     rdx
        pop     rcx
        pop     rbx
        pop     rax
        ret

printSpace:
        push    rax
        push    rbx
        push    rcx
        push    rdx

        mov     eax, 1
        mov     edi, 1
        mov     rsi, space
        mov     edx, 1
        syscall

        pop     rdx
        pop     rcx
        pop     rbx
        pop     rax
        ret

saveCoords:
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

        mov     eax, [markerCount]
        mov     rbx, [L_table]
        lea     rbx, [rbx + rax*4]
        movzx   ecx, word [markerLength]
        mov     [rbx], ecx

        mov     eax, [markerCount]
        mov     rbx, [W_table]
        lea     rbx, [rbx + rax*4]
        movzx   ecx, word [markerWidth]
        mov     [rbx], ecx

        inc     dword [markerCount]

skipSave:
        ret

