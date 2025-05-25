section .bss
        ; Header
        Img_width       resd	1 
        Img_height      resd	1 
        Img_bpl         resd	1 
        Img_padding     resd	1 
        Img_pixelcount  resd	1 
        Img_pxoffset    resd	1
        Img_size        resd	1

        bitmap          resd	1
        X_table         resd	1
        Y_table         resd	1

        ; Passed pointers

        ; Variable data
        baseX           resw	1
        baseY           resw	1
        tempX           resw	1
        tempY           resw	1
        markerLength    resw	1
        tempLength      resw	1
        markerWidth     resw	1
        tempWidth       resw	1

section .data
        counter         dd      0
        markerCount     db      0

        ; characters
        buf             db      12 dup(0)
        newline         db      0xA, 0
        space           db      0x20, 0

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

        mov     eax, [ebp + 8]

        call    getHeader

        call    findMarkers

fin:
        mov     eax, [markerCount]
        pop     ebx
        pop     ebp
        ret

getHeader:
        mov     esi, [ebp + 8]

        ; Check filetype
        mov     ax, [esi]
        cmp     ax, 0x4D42              ; .bmp file marker
        jne     fileTypeError

        ; Width
        mov     eax, [esi + 0x12]
        mov     [Img_width], eax

        ; Height
        mov     ebx, [esi+ 0x16]
        mov     [Img_height], ebx

        ; PixelCount
        mul     ebx                     ; width * height
        mov     [Img_pixelcount], eax

        ; Bytes Per Line
        mov     eax, [Img_width]
        lea     eax, [eax + 2*eax + 3]
        shr     eax, 2
        shl     eax, 2                  ; bits per line
        mov     [Img_bpl], eax

        ; Padding
        mov     ebx, [Img_width]
        lea     ebx, [ebx + 2*ebx]      ; padding at the end of line
        sub     eax, ebx
        mov     [Img_padding], eax

        ; Image size (in bytes)
        mov     eax, [Img_height]
        mul     word [Img_bpl]
        mov     [Img_size], eax

        ; Pixel offset
        mov     eax, [esi + 0x0A]
        mov     [Img_pxoffset], eax

        ; Bitmap pointer
        lea     eax, [esi + eax]
        mov     [bitmap], eax

        xor     eax, eax
        ret

fileTypeError:
        mov     eax, -10
        ret

;------------------------------------------------;

findMarkers:
        mov     esi, [bitmap]
        mov     eax, [Img_height]
        dec     eax
        mul     word [Img_width]
        lea     esi, [esi + eax]        ; points to (0,0) - top left corner

findLoop:
        mov     word [baseX], 0
        mov     cx, word [counter]
        cmp     cx, word [Img_pixelcount]
        je      findEnd

        mov     edx, [esi]
        and     edx, 0x00FFFFFF         ; EDX = 0x00RRGGBB
        jnz     nextPixel

        ; pixel is possible base of a marker
        mov     edi, esi
        mov     cx, word[baseX]
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
        ;mov     [tempX], ax

        mov     bx, [baseY]
        inc     bx
        ;mov     [tempY], ax

        mov     dword [markerWidth], 1

        call    goDiag

        mov     cx, [markerWidth]
        cmp     cx, [markerLength]
        je      nextPixel
        
        inc     byte [markerCount]

        call    printCoords

        jmp     nextPixel

findEnd:
        ret

nextPixel:
        inc     word [baseX]
        inc     word [counter]
        add     esi, 3
        mov     cx, [baseX]
        cmp     cx, [Img_width]
        jne     findLoop

        mov     word [baseX], 0
        inc     word [baseY]
        sub     esi, [Img_bpl]
        sub     esi, [Img_bpl]
        add     esi, [Img_padding]
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
;       cx - temp Y
goDiag:
        cmp     ax, [Img_width]
        je      nextPixel
        cmp     bx, [Img_height]
        je      nextPixel

        mov     edx, [edi]
        and     edx, 0x00FFFFFF
        jnz     foundDiag

        ; pixel is black
        push    edi
        mov     cx, ax
        call    goRight
        pop     edi
        mov     [tempLength], cx

        push    edi
        mov     cx, bx
        call    goDown
        pop     edi
        
        cmp     cx, [tempLength]
        jne     nextPixel

        mov     cx, ax
        sub     cx, [baseX]
        movzx   [tempWidth], cx

        mov     cx, [tempLength]
        add     cx, [tempWidth]
        cmp     cx, [markerLength]
        jne     nextPixel

        ; move to the next diagonal pixel
        inc     ax
        inc     bx
        add     edi, 3
        sub     edi, [Img_bpl]
        inc     word [markerWidth]
        jmp     goDiag

foundDiag:
        ret

printCoords:
        mov     eax, [baseX]
        call    printDecimal

        mov     eax, 4
        mov     ebx, 1
        mov     ecx, space
        mov     edx, 1
        int     0x80

        mov     eax, [baseY]
        call    printDecimal
        
        mov     eax, 4
        mov     ebx, 1
        mov     ecx, newline
        mov     edx, 1
        int     0x80

; in ax - value to print
; destroys eax, ecx, edx and esi
printDecimal:
        push    eax
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
        pop     eax

        ret

