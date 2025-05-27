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

        ; Passed pointers

        ; Variable data
        markerLength    resw	1
        tempLength      resw	1
        markerWidth     resw	1
        tempWidth       resw	1

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
        text            db      "line\n", 10

section .text
        global  find_markers

find_markers:
        push    ebp
        mov     ebp, esp

        push    ebx

        mov     eax, [ebp + 12]
        mov     [X_table], eax
        mov     eax, [ebp + 16]
        mov     [Y_table], eax
        mov     eax, [ebp + 20]
        mov     [L_table], eax
        mov     eax, [ebp + 24]
        mov     [W_table], eax


        mov     eax, [ebp + 8]

        call    getHeader

        call    findMarkers

fin:
        pop     ebx
        pop     ebp
        ret

getHeader:
        mov     esi, [ebp + 8]

        ; Check filetype
        xor     eax, eax
        mov     ax, [esi]
        cmp     ax, 0x4D42              ; .bmp file marker
        jne     fileTypeError

        ; Width
        xor     eax, eax
        mov     eax, [esi + 0x12]
        mov     [Img_width], eax

        ; Height
        xor     ebx, ebx
        mov     ebx, [esi+ 0x16]
        mov     [Img_height], ebx

        ; PixelCount
        mul     ebx                     ; width * height
        mov     [Img_pixelcount], eax

        ; Bits Per Line
        movzx   eax, word [Img_width]
        lea     eax, [eax + 2*eax + 3]
        shr     eax, 2
        shl     eax, 2
        mov     [Img_bpl], eax

        ; Padding
        movzx   ebx, word [Img_width]
        lea     ebx, [ebx + 2*ebx]      ; padding at the end of line
        sub     eax, ebx
        mov     [Img_padding], eax

        ; Pixel offset
        mov     eax, [esi + 0x0A]
        test    eax, eax
        jz      fileTypeError
        mov     [Img_pxoffset], eax

        ; Bitmap pointer
        lea     eax, [esi + eax]
        test    eax, eax
        jz      fileTypeError
        mov     [bitmap], eax

        xor     eax, eax
        ret

fileTypeError:
        mov     eax, -10
        ret

;------------------------------------------------;

findMarkers:
        mov     esi, [bitmap]
        movzx   eax, word [Img_height]
        dec     eax
        mul     dword [Img_bpl]
        add     esi, eax                ; points to (0,0) - top left corner

        mov     word [baseX], 0

findLoop:
        ;movzx   eax, word [baseX]
        ;call    printDecimal

        ;mov     eax, 4
        ;mov     ebx, 1
        ;mov     ecx, space
        ;mov     edx, 1
        ;int     0x80

        ;movzx   eax, word [baseY]
        ;call    printDecimal
        ;
        ;mov     eax, 4
        ;mov     ebx, 1
        ;mov     ecx, space
        ;mov     edx, 1
        ;int     0x80

        ;mov     eax, [counter]
        ;call    printBinary

        ;mov     eax, 4
        ;mov     ebx, 1
        ;mov     ecx, newline
        ;mov     edx, 1
        ;int     0x80

        xor     ecx, ecx
        mov     ecx, dword [counter]
        cmp     ecx, dword [Img_pixelcount]
        je      findEnd

        mov     word [markerLength], 0

        cmp     dword [markerCount], 50
        je      findEnd

        mov     edx, [esi]
        and     edx, 0x00FFFFFF         ; EDX = 0x00RRGGBB
        jnz     nextPixel

        ; pixel is possible base of a marker
        mov     edi, esi
        mov     cx, word [baseX]
        call    goRight
        mov     word [markerLength], cx

        mov     edi, esi
        mov     cx, [baseY]
        call    goDown
        
        ; arms not equal in length
        cmp     cx, word [markerLength]
        jne     nextPixel

        ; if it's a single pixel
        cmp     cx, 1
        jz      nextPixel

        ; check diagonal pixels
        lea     edi, [esi + 3]
        sub     edi, [Img_bpl]

        mov     ax, [baseX]
        inc     ax
        mov     bx, [baseY]
        inc     bx

        mov     word [markerWidth], 0
        mov     word [tempWidth], 0

        call    goDiag

        mov     cx, [markerWidth]
        cmp     cx, [markerLength]
        je      nextPixel
        
        call    saveCoords

        jmp     nextPixel

findEnd:
        mov     eax, dword [markerCount]
        ret

nextPixel:
        inc     word [baseX]
        inc     dword [counter]
        add     esi, 3

        mov     cx, word [baseX]
        cmp     cx, [Img_width]
        jne     findLoop

        mov     word [baseX], 0
        inc     word [baseY]

        add     esi, [Img_padding]
        sub     esi, [Img_bpl]
        sub     esi, [Img_bpl]

        jmp     findLoop

;------------------------------------------------;

goRight:
        cmp     cx, [Img_width]
        je      foundRight

        mov     edx, [edi]
        and     edx, 0x00FFFFFF
        jnz     foundRight

        add     edi, 3
        inc     cx
        jmp     goRight

foundRight:
        sub     cx, [baseX]
        ret

goDown:
        cmp     cx, [Img_height]
        je      foundDown

        mov     edx, [edi]
        and     edx, 0x00FFFFFF
        jnz     foundDown

        sub     edi, [Img_bpl]
        inc     cx
        jmp     goDown

foundDown:
        sub     cx, [baseY]
        ret

;------------------------------------------------;
;       ax - temp X
;       bx - temp Y
goDiag:
        cmp     ax, [Img_width]
        je      nextPixel
        cmp     bx, [Img_height]
        je      nextPixel

        mov     edx, [edi]
        and     edx, 0x00FFFFFF
        jnz     foundDiag

        ; pixel is black
        xor     ecx, ecx

        push    edi
        mov     cx, ax
        call    goRight
        mov     [tempLength], cx
        pop     edi

        xor     ecx, ecx

        push    edi
        mov     cx, bx
        call    goDown
        pop     edi
        
        cmp     cx, [tempLength]
        jne     nextPixel

        ;mov     cx, ax
        ;sub     cx, [baseX]
        ;mov     [tempWidth], cx

        ;inc     word [tempWidth]
        inc     word [markerWidth]

        ; cx has tempLength
        ;mov     cx, [tempLength]
        add     cx, [markerWidth]
        cmp     cx, [markerLength]
        jne     nextPixel

        ; move to the next diagonal pixel
        inc     ax
        inc     bx
        add     edi, 3
        sub     edi, [Img_bpl]
        jmp     goDiag

foundDiag:
        ret

printCoords:
        movzx   eax, word [baseX]
        call    printDecimal

        mov     eax, 4
        mov     ebx, 1
        mov     ecx, space
        mov     edx, 1
        int     0x80

        movzx   eax, word [baseY]
        call    printDecimal
        
        mov     eax, 4
        mov     ebx, 1
        mov     ecx, newline
        mov     edx, 1
        int     0x80

        ret


printBinary:
        push    eax
        push    ebx
        push    ecx
        push    edx
        push    esi

        xor     ecx, ecx
        mov     esi, buf + 11
        mov     byte [esi], 0
        mov     ebx, 2

        convertBin:
                xor     edx, edx
                div     ebx
                add     dl, '0'
                dec     esi
                mov     [esi], dl
                inc     ecx
                test    eax, eax
                jnz     convertBin

        mov     eax, 4
        mov     ebx, 1
        mov     edx, ecx
        mov     ecx, esi
        int     0x80

        pop     esi
        pop     edx
        pop     ecx
        pop     ebx
        pop     eax

        ret
        
; in ax - value to print
printDecimal:
        push    eax
        push    ebx
        push    ecx
        push    edx
        push    esi

        xor     ecx, ecx
        mov     ebx, 10

        mov     esi, buf + 11
        mov     byte [esi], 0

        convert:
                xor     edx, edx
                div     ebx
                add     dl, '0'
                dec     esi
                mov     [esi], dl
                inc     ecx
                test    eax, eax
                jnz     convert

        ; print
        mov     eax, 4
        mov     ebx, 1
        mov     edx, ecx
        mov     ecx, esi
        int     0x80

        pop     esi
        pop     edx
        pop     ecx
        pop     ebx
        pop     eax

        ret



; adds the coordinate to the arrays
saveCoords:

        mov     eax, [markerCount]
        mov     ebx, [X_table]
        lea     eax, [ebx + 4*eax]

        movzx   ebx, word [baseX]
        mov     [eax], ebx

        mov     eax, [markerCount]
        mov     ebx, [Y_table]
        lea     eax, [ebx + 4*eax]

        movzx   ebx, word [baseY]
        mov     [eax], ebx

        mov     eax, [markerCount]
        mov     ebx, [L_table]
        lea     eax, [ebx + 4*eax]

        movzx   ebx, word [markerLength]
        mov     [eax], ebx

        mov     eax, [markerCount]
        mov     ebx, [W_table]
        lea     eax, [ebx + 4*eax]

        movzx   ebx, word [markerWidth]
        mov     [eax], ebx

        inc     dword [markerCount]

        ret
