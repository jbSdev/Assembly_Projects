# BMP file descriptor structure
.eqv	Img_fname	0
.eqv	Img_hdrdata	4
.eqv	Img_imgdata	8
.eqv	Img_width	12
.eqv	Img_height	16
.eqv	Img_ppl		20	# pixels per line

.eqv	Img_desc_size	24
.eqv	IMGMAXSIZE	230400	# 240 * 320 * 3
.eqv	Bmp_marker	0x4D42

.eqv	Header_size	54
.eqv	Header_width	18
.eqv	Header_height	22
.eqv	Header_marker	0

# Coordinate structure
.eqv	x_coord		0
.eqv	y_coord		4

# System calls

.eqv	Sys_PrintInt	1
.eqv	Sys_PrintString	4
.eqv	Sys_OpenFile	1024
.eqv	Sys_ReadFile	63
.eqv	Sys_CloseFile	57
.eqv	Sys_Exit0	10



.data
	
	ImgDesc:	.space Img_desc_size
	
	.align 2
	free:		.space 2
	ImgHeader:	.space Header_size
	
	.align 2
	ImgData:	.space IMGMAXSIZE
	
	mfail:		.asciz "\nReading file error: "
	errmsg:		.asciz	"\nError: "
	fname:		.asciz	"/home/jb/University/ECOAR/RISC-V_Project/markers.bmp"	# name of the file to open
	
	heightText:	.asciz "\nHeight: "
	widthText:	.asciz "\nWidth: "
	linesText:	.asciz "\nLines: "
	exitText:	.asciz "\nExiting program..."
	

.text
main:
	# create and fill image descriptor structure
	la	a0, ImgDesc
	la	t0, fname
	sw	t0, Img_fname(a0)
	la	t0, ImgHeader
	sw	t0, Img_hdrdata(a0)
	la	t0, ImgData
	sw	t0, Img_imgdata(a0)
	jal	readBmp
	bnez	a0, readFail
	
	# print image data
	mv	a0, t0
	jal	printData
	
	# find first non-white pixel
	mv	a0, t0
	jal	findFirst
	
	
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
	
		# calculate line size
		add	a2, a0, a0
		add	a0, a2, a0	# number of pixels - width * 3
		addi	a0, a0, 3
		srai	a0, a0, 2
		slli	a0, a0, 2	# number of lines - ((pixels + 3) / 4) * 4
		sw	a0, Img_ppl(t0)
		
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
	
	li	a7, 4
	la	a0, widthText
	ecall
	li	a7, Sys_PrintInt
	lhu	a0, Img_width(t0)
	ecall
	
	li	a7, 4
	la	a0, heightText
	ecall
	li	a7, Sys_PrintInt
	lhu	a0, Img_height(t0)
	ecall
	
	li	a7, 4
	la	a0, linesText
	ecall
	li	a7, Sys_PrintInt
	lhu	a0, Img_ppl(t0)
	ecall
	
	ret

#-----------------------------------------------------------------------#
findFirst:
	mv	t0, a0
	ret
	


#-----------------------------------------------------------------------#

exitProgram:
	li	a7, Sys_PrintString
	la	a0, exitText
	ecall
	
	li	a7, Sys_Exit0
	ecall