# BMP file descriptor structure
.eqv	Img_fname	0
.eqv	Img_hdrdata	4
.eqv	Img_imgdata	8
.eqv	Img_width	12
.eqv	Img_height	16
.eqv	Img_bpl		20	# bits per line
.eqv	Img_padding	24
.eqv	Img_pixelcount	28
.eqv	Img_pxoffset	32

.eqv	Img_desc_size	32
.eqv	IMGMAXSIZE	230400	# 240 * 320 * 3
.eqv	Bmp_ID		0x4D42

.eqv	Header_size	54
.eqv	Header_marker	0
.eqv	Header_pxoffset	10
.eqv	Header_width	18
.eqv	Header_height	22

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
	
	errorText:	.asciz "\nError: "
	readErrText:	.asciz "\nFailed reading the file."
	ftypeErrText:	.asciz "\nWrong filetype."
	fname:		.asciz	"source.bmp"		# name of the file to open
	#fname:		.asciz	"test.bmp"		# name of the file to open
	
	heightText:	.asciz "\nHeight: "
	widthText:	.asciz "\nWidth: "
	bplText:	.asciz "\nBites per line: "
	paddingText:	.asciz "\nRow padding: "
	pxcountText:	.asciz "\nPixel count: "
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
	#la	a0, ImgDesc
	#jal	printData
	
	# find markers
	la	a0, ImgDesc
	jal	s11, findMarkers
	
	# exit
	la	a0, ImgDesc
	jal	exitProgram

readFail:
	mv	t0, a0
	li	a7, Sys_PrintString
	la	a0, errorText
	ecall
	
	li	a7, Sys_PrintInt
	mv	a0, t0
	ecall
	
	li	a7, Sys_PrintString
	mv	a0, a2
	ecall
	
	li	a7, Sys_Exit0
	ecall

#-----------------------------------------------------------------------#
# readBmp - reads the .bmp file into memory				#
# arguments:								#
#	a0 - pointer to a structure containing the file descriptor	#
# returns:								#
#	a0 - success = 0, error code in other case			#
#		err = 1 - failed reading the file			#
#		err = 2 - error						#
#-----------------------------------------------------------------------#

readBmp:
	mv	t0, a0		# Save pointer to img descriptor
	
	# open the file
	li	a7, Sys_OpenFile
	lw	a0, Img_fname(t0)
	li	a1, 0		# flags
	ecall
	
	bltz	a0, readError
	mv	t1, a0		# save file handle
	
	# read the bmp header
	li	a7, Sys_ReadFile
	lw	a1, Img_hdrdata(t0)
	li	a2, Header_size
	ecall
	
	# the bmp header is under pointer in a1
	
	# check if the file is a BMP file
	li	t6, Bmp_ID
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
		
		# calculate image padding
		sub	a0, a0, t2
		sw	a0, Img_padding(t0)
		
	# save image height
	lw	a0, Header_height(a1)
	sw	a0, Img_height(t0)
	
	# save offset of the first image pixel
	lw	a0, Header_pxoffset(a1)
	sw	a0, Img_pxoffset(t0)
		
	# save amount of pixels
	lw	a0, Img_height(t0)
	lw	a1, Img_width(t0)
	mul  	a1, a0, a1		# number of pixels = width * height
	sw	a1, Img_pixelcount(t0)
	
	# skip bytes about image compression
	# if pxoffset = 54, skipping 0 bytes
	lw	t2, Img_pxoffset(t0)
	li	a7, Sys_ReadFile
	mv	a0, t1
	lw	a1, Img_imgdata(t0)
	addi	a2, t2, -54
	ecall
	
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
	li	a0, 2	# ENOENT - file not found
	la	a2, readErrText
	ret
	
filetypeError:
	# wrong filetype
	li	a0, 22	# EINVAL - invalid input (file)
	la	a2, ftypeErrText
	ret

#-----------------------------------------------------------------------#
# printData - prints info about the file				#
# arguments:								#
#	a0 - pointer to a structure containing the file descriptor	#
# returns:								#
#	nothing								#
#-----------------------------------------------------------------------#
printData:
	mv	t0, a0		# save file handle
	
	li	a7, Sys_PrintString
	la	a0, widthText	# width
	ecall
	li	a7, Sys_PrintInt
	lhu	a0, Img_width(t0)
	ecall
	
	li	a7, Sys_PrintString
	la	a0, heightText	# height
	ecall
	li	a7, Sys_PrintInt
	lhu	a0, Img_height(t0)
	ecall
	
	li	a7, Sys_PrintString
	la	a0, bplText	# bpl
	ecall
	li	a7, Sys_PrintInt
	lhu	a0, Img_bpl(t0)
	ecall
	
	li	a7, Sys_PrintString
	la	a0, paddingText	# padding
	ecall
	li	a7, Sys_PrintInt
	lhu	a0, Img_padding(t0)
	ecall
	
	li	a7, Sys_PrintString
	la	a0, pxcountText
	ecall
	li	a7, Sys_PrintInt
	lw	a0, Img_pixelcount(t0)
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
#	prints to console all found black pixel coords			#
#	(0, 0) - left top						#
# Internal values:							#
#	a6  - marker arm width						#
#	t1  - loading register						#
#	t2  - temp X coordinate						#
#	t3  - temp Y coordinate						#
#	t4  - padding to pixel						#
#	t5  - temp padding to pixel					#
#	s2  - marker arm length						#
#	s3  - image height						#
#	s4  - image bits per line					#
#	s5  - image width						#
#	s6  - row padding						#
#	s7  - Pixel Count						#
#	s8  - X coordinate						#
#	s9  - Y coordinate						#
#	s10 - total pixel counter					#
#-----------------------------------------------------------------------#
findMarkers:
	# load initial values
	lhu	s3, Img_height(a0)
	lhu	s4, Img_bpl(a0)
	lhu	s5, Img_width(a0)
	lhu	s6, Img_padding(a0)
	#li	s7, PixelCount
	lw	s7, Img_pixelcount(a0)
	xor	s8, s8, s8
	xor	s9, s9, s9
	xor	s10, s10, s10
	
	lw	t4, Img_imgdata(a0)
	addi	t0, s3, -1
	mul	t0, t0, s4
	add	t4, t4, t0	# t4 points to (0, 0) - left top

findLoop:
	xor	s2, s2, s2
	beq	s10, s7, findEnd	# EOF
	
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
	mv	t2, s8
	jal	goRight
	mv	s2, s1		# save arm length
	
	# check length of arm down
	mv	t5, t4
	mv	t6, s9		# y coordinate
	mv	t3, s9
	jal	goDown
	
	bne	s1, s2, nextPixel	# arms not equal in length
	
	addi	s2, s2, -1
	beqz	s2, nextPixel	# if found a single pixel
	addi	s2, s2, 1
	
	
	# check diagonal pixels - arm may have width
	mv	t5, t4
	addi	t5, t5, 3
	sub	t5, t5, s4	# t5 - offset of the first diagonal pixel from the base of marker
	mv	t2, s8
	addi	t2, t2, 1
	mv	t3, s9
	addi	t3, t3, 1
	li	a6, 1		# width
	
	jal	a5, goDiag
	
	beq	a6, s2, nextPixel	# big square (width = length)
	
	jal	a4, checkEdges

	j	printCoords

findEnd:	
	mv	ra, s11
	ret
	
#-----------------------------------------------------------------------#

#---------------------------------------#
# 	        goRight			#
# Arguments:				#
#	t5 - offset of base px		#
# Outputs:				#
#	s1 - marker arm length		#
#---------------------------------------#
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
	sub	s1, t6, t2	# right arm length
	ret

#---------------------------------------#
# 	         goDown			#
# Arguments:				#
#	t5 - offset of base px		#
# Outputs:				#
#	s1 - marker arm length		#
#---------------------------------------#
goDown:
	beq	t6, s3, foundLengthDown
	
	lbu	t1, 0(t5)	# Blue
	bnez	t1, foundLengthDown
	lbu	t1, 1(t5)	# Green
	bnez	t1, foundLengthDown
	lbu	t1, 2(t5)	# Red
	bnez	t1, foundLengthDown
	
	sub	t5, t5, s4
	addi	t6, t6, 1
	j	goDown
	
foundLengthDown:
	sub	s1, t6, t3	# marker down arm length
	ret

#---------------------------------------#
# 	     goDiag			#
# Arguments:				#
#	t5 - offset of first diag px	#
#	s5 - base pixel X coordinate	#
#	s3 - base pixel Y coordinate	#
# Outputs:				#
#	s0 - base arm length		#
#---------------------------------------#
goDiag:
	# if border is met, there is no possibility for that marker to be valid
	beq	t3, s3, nextPixel	# L/R Border
	beq	t2, s5, nextPixel	# U/D  Border
	
	lbu	t1, 0(t5)	# Blue
	bnez	t1, foundDiag
	lbu	t1, 1(t5)	# Green
	bnez	t1, foundDiag
	lbu	t1, 2(t5)	# Red
	bnez	t1, foundDiag
	
	# the pixel is black
	mv	t0, t5		# save temp origin offset
	mv	t6, t2		# x coordinate
	jal	goRight
	mv	s0, s1		# save found length
	
	mv	t5, t0		# revert origin offset
	mv	t6, t3		# y coordinate
	jal	goDown
	
	mv	t5, t0		# revert origin offset
	sub	t0, t2, s8	# width offset
	
	# s0 and s1 contain found lengths
	bne	s0, s1, nextPixel	# internal arms not equal
	
	add	s0, s0, t0		# internal arm should be shorter by current width offset than the base ones
	bne	s0, s2, nextPixel	# arms not equal to base ones
	sub	s0, s0, t0
	
	# move diagonally
	addi	t2, t2, 1	# x++
	addi	t3, t3, 1	# y++
	# border checked at start
	addi	t5, t5, 3
	sub	t5, t5, s4	# move offset diagonally
	addi	a6, a6, 1
	j	goDiag

foundDiag:
	mv	ra, a5
	ret

#-----------------------------------------------------------------------#

#---------------------------------------#
# 	     checkEdges			#
#	Checks pixels above the top	#
#	    arm of the marker		#
# Data:					#
#	t5 - offset of first diag px	#
#	t2 - current x			#
#	t3 - current y			#
#	s2 - base arm length		#
#---------------------------------------#
checkEdges:
	# check upper edge of top arm
	mv	t5, t4
	mv	t2, s8
	mv	t3, s9
	add	t5, t5, s4	# set pointer to px above the origin
	jal	checkUpper

	# check left edge of lower arm
	mv	t5, t4
	addi	t5, t5, -3
	mv	t2, s8		# set pointers to px on the left of origin
	jal	checkLeft
	
	mv	t5, t4
	add	t0, a6, a6
	add	t0, t0, a6	# t0 = a6 * 3 (width in bits -> offset to move right)
	add	t5, t5, t0
	mul	t0, a6, s4	# width * bpl (offset to move down)
	sub	t5, t5, t0
	
	mv	t2, s8
	add	t2, t2, a6
	mv	t6, t2
	
	mv	t3, s9
	add	t3, t3, a6	# set pointers to the px right in the corner outside of marker
	jal	checkBottom
	
	mv	t5, t4
	add	t0, a6, a6
	add	t0, t0, a6	# t0 = a6 * 3 (width in bits -> offset to move right)
	add	t5, t5, t0
	mul	t0, a6, s4
	sub	t5, t5, t0
	
	mv	t2, s8
	add	t2, t2, a6
	
	mv	t3, s9
	add	t3, t3, a6
	mv	t6, t3		# set pointers to the px right in the corner outside of marker
	jal	checkRight
	
	mv	ra, a4
	ret

#---------------------------------------#
# 	       checkUpper		#
# Arguments:				#
#	t5 - offset of px above origin	#
#	t2 - temp X coordinate		#
#	t3 - temp Y coordinate		#
# Checks if there are any stray black	#
# pixels right above the marker, if yes	#
# the marker is considered incorrect	#
#---------------------------------------#
checkUpper:
	beqz	t3, endUpper	# upper border of image
	
	sub	t0, t2, s8
	beq	t0, s2, endUpper# end of the marker
	xor	t0, t0, t0
	
	lbu	t1, 0(t5)	# Blue
	add	t0, t0, t1		# 0x000000BB
	slli	t0, t0, 8
	lbu	t1, 1(t5)	# Green
	add	t0, t0, t1		# 0x0000BBGG
	slli	t0, t0, 8
	lbu	t1, 2(t5)	# Red
	add	t0, t0, t1		# 0x00BBGGRR
	
	beqz	t0, nextPixel	# if pixel is black
	
	# go next
	addi	t2, t2, 1
	addi	t5, t5, 3
	j	checkUpper
	
endUpper:
	# no additional pixels above the marker
	ret
	
#---------------------------------------#
# 	       checkLeft		#
# Arguments:				#
#	t5 - offset of px above origin	#
#	t2 - temp X coordinate		#
#	t3 - temp Y coordinate		#
# Checks if there are any stray black	#
# pixels on the left of the marker,	#
# if yes the marker is considered	#
# incorrect				#
#---------------------------------------#	
checkLeft:
	beqz	t2, endLeft
	
	sub	t0, t3, s9
	beq	t0, s2, endLeft
	xor	t0, t0, t0
	
	lbu	t1, 0(t5)	# Blue
	add	t0, t0, t1		# 0x000000BB
	slli	t0, t0, 8
	lbu	t1, 1(t5)	# Green
	add	t0, t0, t1		# 0x0000BBGG
	slli	t0, t0, 8
	lbu	t1, 2(t5)	# Red
	add	t0, t0, t1		# 0x00BBGGRR
	
	#li	t1, 0x00FFFFFF
	beqz	t0, nextPixel	# if pixel is black
	
	# go next
	addi	t3, t3, 1
	sub	t5, t5, s4
	j	checkLeft

endLeft:
	# no additional pixels on the left size of the marker
	ret
	
#---------------------------------------#
# 	      checkBottom		#
# Arguments:				#
#	t5 - offset of px above origin	#
#	t2 - temp X coordinate		#
#	t3 - temp Y coordinate		#
#	t6 - X coordinate of corner px	#
# Checks if there are any stray black	#
# pixels below the upper arm of the	#
# the marker, if yes the marker is	#
# considered incorrect			#
#---------------------------------------#
checkBottom:
	sub	t1, s2, a6	# arm length - width (length of hanging part of arm)
	sub	t0, t2, t6
	beq	t0, t1, endBottom# end of the marker
	xor	t0, t0, t0
	
	lbu	t1, 0(t5)	# Blue
	add	t0, t0, t1		# 0x000000BB
	slli	t0, t0, 8
	lbu	t1, 1(t5)	# Green
	add	t0, t0, t1		# 0x0000BBGG
	slli	t0, t0, 8
	lbu	t1, 2(t5)	# Red
	add	t0, t0, t1		# 0x00BBGGRR
	
	#li	t1, 0x00FFFFFF
	beqz	t0, nextPixel	# if pixel is black
	
	# go next
	addi	t2, t2, 1
	addi	t5, t5, 3
	j	checkBottom
	
endBottom:
	# no additional pixels below the upper marker arm
	ret
	
#---------------------------------------#
# 	       checkRight		#
# Arguments:				#
#	t5 - offset of px above origin	#
#	t2 - temp X coordinate		#
#	t3 - temp Y coordinate		#
#	t6 - X coordinate of corner px	#
# Checks if there are any stray black	#
# pixels on the right side of the	#
# bottom arm of the marker, if yes	#
# the marker is considered incorrect	#
#---------------------------------------#
checkRight:
	sub	t1, s2, a6	# marker length - width (length of hanging part)
	sub	t0, t3, t6
	beq	t0, t1, endRight# end of marker
	xor	t0, t0, t0
	
	lbu	t1, 0(t5)	# Blue
	add	t0, t0, t1		# 0x000000BB
	slli	t0, t0, 8
	lbu	t1, 1(t5)	# Green
	add	t0, t0, t1		# 0x0000BBGG
	slli	t0, t0, 8
	lbu	t1, 2(t5)	# Red
	add	t0, t0, t1		# 0x00BBGGRR
	
	beqz	t0, nextPixel	# if pixel is black
	
	# go next
	addi	t3, t3, 1
	sub	t5, t5, s4
	j	checkRight

endRight:
	# no additional pixels on the right of bottom marker arm 
	ret

#-----------------------------------------------------------------------#

#-------------------------------#
# 	  Print Coords		#
# Arguments:			#
#	s8 - x			#
#	s9 - y			#
#	s2 - marker length	#
#	a6 - marker width	#
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
		
	mv	a0, t6
	
nextPixel:
	addi	s8, s8, 1
	addi	s10, s10, 1
	addi	t4, t4, 3	# next pixel
	bne 	s8, s5, findLoop# end of line
	
	xor	s8, s8, s8
	addi	s9, s9, 1
	sub	t4, t4, s4	# move to next row
	sub	t4, t4, s4	# t4 - 2*bpl
	add	t4, t4, s6	# + padding
	j	findLoop

	
#-----------------------------------------------------------------------#

exitProgram:
	li	a7, Sys_PrintString
	la	a0, exitText
	ecall
	
	li	a7, Sys_Exit0
	ecall
