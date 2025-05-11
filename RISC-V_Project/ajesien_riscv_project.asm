# BMP file descriptor structure
.eqv	Img_fname	0
.eqv	Img_hdrdata	4
.eqv	Img_imgdata	8
.eqv	Img_width	12
.eqv	Img_height	16
.eqv	Img_bpl		20	# bits per line
.eqv	Img_padding	24

.eqv	Img_desc_size	28
#.eqv	IMGMAXSIZE	230400	# 240 * 320 * 3
.eqv	IMGMAXSIZE	1840
.eqv	PixelCount	600
.eqv	Bmp_marker	0x4D42

.eqv	Header_size	54
.eqv	Header_width	18
.eqv	Header_height	22
.eqv	Header_marker	0

# Pixel data
.eqv	x		0
.eqv	y		4

# System calls

.eqv	Sys_PrintInt	1
.eqv	Sys_PrintString	4
.eqv	Sys_OpenFile	1024
.eqv	Sys_ReadFile	63
.eqv	Sys_CloseFile	57
.eqv	Sys_Exit0	10



.data
	.align 2
	ImgDesc:	.space Img_desc_size
	
	.align 2
	free:		.space 2
	ImgHeader:	.space Header_size
	
	.align 2
	ImgData:	.space IMGMAXSIZE
	
	PixelData:	.space 2
	
	mfail:		.asciz "\nReading file error: "
	errmsg:		.asciz	"\nError: "
	fname:		.asciz	"../Assembly_projects/RISC-V_Project/test.bmp"	# name of the file to open
											# it has to be a relative path from the rars executable file, not the .asm file
	
	heightText:	.asciz "\nHeight: "
	widthText:	.asciz "\nWidth: "
	linesText:	.asciz "\nBites per line: "
	paddingText:	.asciz "\nRow padding: "
	exitText:	.asciz "\nExiting program..."
	blank:		.asciz " "
	endl:		.asciz "\n"
	

.text
main:
	# initialize image descriptor structure
	la	a0, ImgDesc
	la	t0, fname
	sw	t0, Img_fname(a0)
	la	t0, ImgHeader
	sw	t0, Img_hdrdata(a0)
	la	t0, ImgData
	sw	t0, Img_imgdata(a0)
	
	
	# read from the file
	jal	readBmp
	bnez	a0, readFail
	
	# print image data
	la	a0, ImgDesc
	jal	printData
	
	# find black pixels
	la	a0, ImgDesc
	jal	findMarkers
	
	# exit
	la	a0, ImgDesc
	jal	exitProgram

readFail:	# Reading file error: ...
	mv	t0, a0
	li	a7, Sys_PrintString
	la	a0, mfail
	ecall
	
	li	a7, Sys_PrintInt
	mv	a0, t0
	ecall
	
	li	a7, Sys_Exit0
	ecall

#-----------------------------------------------------------------------#
# readBmp - reads the .bmp file into memory				#
# arguments:								#
#	a0 - pointer to a structure containing the file descriptor	#
# returns:								#
#	a0 - success = 0, error code in other case			#
#-----------------------------------------------------------------------#

readBmp:
	mv	t0, a0		# Save pointer to img descriptor
	
	# open the file
	li	a7, Sys_OpenFile
	lw	a0, Img_fname(t0)
	li	a1, 0		# flags
	ecall
	
	blt	a0, zero, readError
	mv	t1, a0		# save file handle
	
	# read the bmp header
	li	a7, Sys_ReadFile
	lw	a1, Img_hdrdata(t0)
	li	a2, Header_size
	ecall
	
	# the bmp header is under pointer in a1
	
	# check if the file is a BMP file
	li	t6, Bmp_marker
	lh	t5, Header_marker(a1)
	bne	t5, t6, filetypeError
	
	# extract data from the header
	lw	a0, Header_width(a1)
	sw	a0, Img_width(t0)
	add	t2, a0, a0
	add	t2, t2, a0	# Width * 3 = pixels in row
	
		# calculate line size
		add	a2, a0, a0
		add	a0, a2, a0	# number of pixels - width * 3
		addi	a0, a0, 3
		srai	a0, a0, 2
		slli	a0, a0, 2	# number of bits per line - ((pixels + 3) / 4) * 4
		sw	a0, Img_bpl(t0)
		
		sub	a0, a0, t2
		sw	a0, Img_padding(t0)
		
		lw	a0, Header_height(a1)
		sw	a0, Img_height(t0)
		
	
	# read image data
	li	a7, Sys_ReadFile
	mv	a0, t1
	lw	a1, Img_imgdata(t0)
	li	a2, IMGMAXSIZE
	ecall
	
	# close the file
	li	a7, Sys_CloseFile
	mv	a0, t1
	ecall
	
	mv	a0, zero
	ret
	
readError:
	li	a0, 1
	ret
	
filetypeError:
	li	a0, 2
	ret

#-----------------------------------------------------------------------#
printData:
	mv	t0, a0		# save file handle
	
	li	a7, Sys_PrintString
	la	a0, widthText
	ecall
	li	a7, Sys_PrintInt
	lhu	a0, Img_width(t0)
	ecall
	
	li	a7, Sys_PrintString
	la	a0, heightText
	ecall
	li	a7, Sys_PrintInt
	lhu	a0, Img_height(t0)
	ecall
	
	li	a7, Sys_PrintString
	la	a0, linesText
	ecall
	li	a7, Sys_PrintInt
	lhu	a0, Img_bpl(t0)
	ecall
	
	li	a7, Sys_PrintString
	la	a0, paddingText
	ecall
	li	a7, Sys_PrintInt
	lhu	a0, Img_padding(t0)
	ecall
	
	li	a7, Sys_PrintString
	la	a0, endl
	ecall
	
	ret

#-----------------------------------------------------------------------#
# Find markers								#
# Arguments:								#
# 	a0 - ptr to file descriptor struct				#
# Returns:								#
#	nothing								#
#	prints to console all found black pixel coords (0, 0) - left top#
# Internal values:							#
#	t4  - padding to pixel						#
#	s3  - marker arm length						#
#	s4  - image bits per line					#
#	s5  - image width						#
#	s6  - row padding						#
#	s7  - Pixel Count						#
#	s8  - x counter							#
#	s9  - y counter							#
#	s10 - total pixel counter					#
#-----------------------------------------------------------------------#
findMarkers:
	mv	s11, ra
	
	# load initial values
	xor	s8, s8, s8
	xor	s9, s9, s9
	xor	s10, s10, s10
	lhu	s4, Img_bpl(a0)
	lhu	s5, Img_width(a0)
	lhu	s6, Img_padding(a0)
	li	s7, PixelCount
	
	lw	t4, Img_imgdata(a0)
	lhu	t0, Img_height(a0)
	addi	t0, t0, -1
	mul	t0, t0, s4
	add	t4, t4, t0	# t4 points to (0, 0) - left top

	
findLoop:
	beq	s10, s7, findEnd	# EOF
	#jal	getPixelValue

#getPixelValue:
	# check color values
	lbu	t1, 0(t4)	# Blue
	bnez	t1, nextPixel
	lbu	t1, 1(t4)	# Green
	bnez	t1, nextPixel
	lbu	t1, 2(t4)	# Red
	bnez	t1, nextPixel
	
	# pixel is a possible origin of marker
	# check length of arm to right
	mv	t5, t4		# origin pixel
	mv	t6, s8		# x coordinate
	jal	goRight
	
	mv	t5, t4
	mv	t6, s9		# y coordinate
	lhu	t3, Img_height(a0)
	jal	goDown
	
	# s1 - length of right marker's arm
	# s2 - length of left marker's arm
	#addi	s1, s1, -1
	#beqz	s1, nextPixel	# if it is a single pixel
	#addi	s1, s1, 1
	
	beq	s1, s2, printCoords
	j	nextPixel
	
goRight:
	beq	t6, s5, foundLengthRight
	
	lbu	t1, 0(t5)	# Blue
	bnez	t1, foundLengthRight
	lbu	t1, 1(t5)	# Green
	bnez	t1, foundLengthRight
	lbu	t1, 2(t5)	# Red
	bnez	t1, foundLengthRight
	
	addi	t5, t5, 3
	addi	t6, t6, 1
	j	goRight
	
	
foundLengthRight:
	sub	s1, t6, s8	# marker arm length
	ret

goDown:
	beq	t6, t3, foundLengthDown
	lbu	t1, 0(t5)	# Blue
	bnez	t1, foundLengthDown
	lbu	t1, 1(t5)	# Green
	bnez	t1, foundLengthDown
	lbu	t1, 2(t5)	# Red
	bnez	t1, foundLengthDown
	
	add	t5, t5, s4
	addi	t6, t6, 1
	j	goDown
	
foundLengthDown:
	sub	s2, t6, s9
	ret

#-------------------------------#
# 	  Print Coords		#
# Arguments:			#
#	s8 - x			#
#	s9 - y			#
#-------------------------------#

printCoords:
	mv	t6, a0
	
	li	a7, Sys_PrintString
	la	a0, endl	# '\n'
	ecall
	
	li	a7, Sys_PrintInt
	mv	a0, s8		# x
	ecall
	
	li	a7, Sys_PrintString
	la	a0, blank	# ' '
	ecall
	
	li	a7, Sys_PrintInt
	mv	a0, s9		# y
	ecall
	
	li	a7, Sys_PrintString
	la	a0, blank	# ' '
	ecall
	
	li	a7, Sys_PrintInt
	mv	a0, s1		# length
	ecall
	
	mv	a0, t6
	
nextPixel:
	addi	s8, s8, 1
	addi	s10, s10, 1
	addi	t4, t4, 3	# next pixel
	bne 	s8, s5, findLoop
	
	xor	s8, s8, s8
	addi	s9, s9, 1
	sub	t4, t4, s4	# move to next row
	sub	t4, t4, s4	# t4 - 2*bpl
	add	t4, t4, s6	# + padding
	j	findLoop

###

findEnd:	
	mv	ra, s11
	ret
#-----------------------------------------------------------------------#

exitProgram:
	li	a7, Sys_PrintString
	la	a0, exitText
	ecall
	
	li	a7, Sys_Exit0
	ecall
