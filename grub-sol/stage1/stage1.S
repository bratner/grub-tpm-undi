/* -*-Asm-*- */
/*
 *  GRUB  --  GRand Unified Bootloader
 *  Copyright (C) 1999,2000,2001,2002,2004   Free Software Foundation, Inc.
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#include <stage1.h>
#include <tgrub.h>
	
/*
 *  defines for the code go here
 */

	/* Absolute addresses
	   This makes the assembler generate the address without support
	   from the linker. (ELF can't relocate 16-bit addresses!) */
#define ABS(x) (x-_start+0x7c00)

	/* Print message string */
#define MSG(x)	movw $ABS(x), %si; call message

	/* XXX:	binutils-2.9.1.0.x doesn't produce a short opcode for this. */
#define	MOV_MEM_TO_AL(x)	.byte 0xa0;  .word x
	
	.file	"stage1.S"

	.text

	/* Tell GAS to generate 16-bit instructions so that this code works
	   in real mode. */
	.code16

.globl _start; _start:
	/*
	 * _start is loaded at 0x7c00 and is jumped to with CS:IP 0:0x7c00
	 */

	/*
	 * Beginning of the sector is compatible with the FAT/HPFS BIOS
	 * parameter block.
	 */

	jmp	after_BPB
	nop	/* do I care about this ??? */

	/*
	 * This space is for the BIOS parameter block!!!!  Don't change
	 * the first jump, nor start the code anywhere but right after
	 * this area.
	 */

	. = _start + 4

	/* scratch space */
mode:
	.byte	0
disk_address_packet:	
sectors:
	.long	0
heads:
	.long	0
cylinders:
	.word	0
sector_start:
	.byte	0
head_start:
	.byte	0
cylinder_start:
	.word	0
	/* more space... */

	. = _start + STAGE1_BPBEND

	/*
	 * End of BIOS parameter block.
	 */

stage1_version:	
	.byte	COMPAT_VERSION_MAJOR, COMPAT_VERSION_MINOR
boot_drive:	
	.byte	GRUB_INVALID_DRIVE	/* the disk to load stage2 from */
force_lba:
	.byte	0
stage2_address:
	.word	0x8000
stage2_sector:
	.long	1
stage2_segment:
	.word	0x800

after_BPB:

/* general setup */
	cli		/* we're not safe here! */

	/*
	 * This is a workaround for buggy BIOSes which don't pass boot
	 * drive correctly. If GRUB is installed into a HDD, check if
	 * DL is masked correctly. If not, assume that the BIOS passed
	 * a bogus value and set DL to 0x80, since this is the only
	 * possible boot drive. If GRUB is installed into a floppy,
	 * this does nothing (only jump).
	 */

	movb	$0x80, %dl
1:

	/*
	 * ljmp to the next instruction because some bogus BIOSes
	 * jump to 07C0:0000 instead of 0000:7C00.
	 */
	ljmp	$0, $ABS(real_start)

real_start:	

	/* set up %ds and %ss as offset from 0 */
	xorw	%ax, %ax
	movw	%ax, %ds
	movw	%ax, %ss

	/* set up the REAL stack */
	movw	$STAGE1_STACKSEG, %sp

	sti		/* we're safe again */

	/*
	 *  Check if we have a forced disk reference here
	 */
	MOV_MEM_TO_AL(ABS(boot_drive))	/* movb	ABS(boot_drive), %al */
	cmpb	$GRUB_INVALID_DRIVE, %al
	je	1f
	movb	%al, %dl
1:
	/* save drive reference first thing! */
	pushw	%dx

	/* print a notification message on the screen */
	MSG(notification_string)

	/* do not probe LBA if the drive is a floppy */

			
	/* check if LBA is supported */
	movb	$0x41, %ah
	movw	$0x55aa, %bx
	int	$0x13

	/* 
	 *  %dl may have been clobbered by INT 13, AH=41H.
	 *  This happens, for example, with AST BIOS 1.04.
	 */
	popw	%dx
	pushw	%dx


	/* check if AH=0x42 is supported if FORCE_LBA is zero */
	MOV_MEM_TO_AL(ABS(force_lba))	/* movb	ABS(force_lba), %al */
	testb	%al, %al
	jnz	lba_mode

	
lba_mode:
	/* save the total number of sectors */
	movl	0x10(%si), %ecx

	/* set %si to the disk address packet */
	movw	$ABS(disk_address_packet), %si

	/* set the mode to non-zero */
	movb	$1, -1(%si)
	
	movl	ABS(stage2_sector), %ebx

	/* the size and the reserved byte */
	movw	$0x0010, (%si)

	/* the blocks */
	movw	$1, 2(%si)
	
	/* the absolute address (low 32 bits) */
	movl	%ebx, 8(%si)

	/* the segment of buffer address */
	movw	$STAGE1_BUFFERSEG, 6(%si)

	xorl	%eax, %eax
	movw	%ax, 4(%si)
	movl	%eax, 12(%si)
	
/*
 * BIOS call "INT 0x13 Function 0x42" to read sectors from disk into memory
 *	Call with	%ah = 0x42
 *			%dl = drive number
 *			%ds:%si = segment:offset of disk address packet
 *	Return:
 *			%al = 0x0 on success; err code on failure
 */

	movb	$0x42, %ah
	int	$0x13

	/* LBA read is not supported, so fallback to CHS.  */
	

	movw	$STAGE1_BUFFERSEG, %bx
	jmp	copy_buffer
		

	
copy_buffer:
	movw	ABS(stage2_segment), %es

	/*
	 * We need to save %cx and %si because the startup code in
	 * stage2 uses them without initializing them.
	 */
	pusha
	pushw	%ds
	
	movw	$0x100, %cx
	movw	%bx, %ds
	xorw	%si, %si
	xorw	%di, %di
	
	cld
	
	rep
	movsw

	popw	%ds
	popa


 	/* Begin TCG extension */
 	/* Hashes the first sector of stage2 and writes the result into PCR8.
 	   For details see README file. */
 
 	/* Store registers which have to be modified */
 	pushw %es
 	pushw %ds
 	pushw %si
 	pushw %di
 	pushl %edx
 
 	/* Create own segment for TCG */
 	movw $0x8000, %ax
 	movw %ax, %es
 	movw %ax, %ds
 
 	/* Preparing and executing TCG_HashAll function call */
 	movw $0x0010, 0x00		/* length input parameter block */
	movl $0x00070000, 0x04		/* start address of stage2 (part1) to be hashed */
 	movw $0x0000, 0x02		/* left empty */
 	movl $0x00000200, 0x08		/* length of data to be hashed */
 	movl $0x00000004, 0x0C		/* algorithm = SHA1 */
 
 	movw $0xBB05, %ax		/* function = TCG_HashAll */
 	movl $0x41504354, %ebx		/* TCG value */
 	xorl %ecx, %ecx			/* must be zero */
 	xorl %edx, %edx			/* must be zero */
 	movw $0x00, %di			/* pointer to input block */
 	movw $0x28, %si			/* pointer to digest block */
 	int $0x1A			/* TCG interrupt call */
 
 	/* Preparing and executing TCG_PassThroughToTPM function call */
 	movw $0x002A, 0x12		/* length input parameter block */
 	movw $0x0022, 0x16		/* size of output parameter block */
 	movw $0xC100, 0x1A		/* TPM_TAG_RQU_COMMAND */
 	movl $0x22000000, 0x1C		/* total number of input bytes */
 	movl $0x14000000, 0x20		/* command ordinal */
 	movl $0x08000000, 0x24		/* PCR to be updated */
 	
 	movw $0xBB02, %ax		/* function = TCG_PassThroughToTPM */
 	movl $0x41504354, %ebx		/* TCG value */
 	movw $0x12, %di			/* pointer to input block */
 	movw $0x60, %si			/* pointer to output block */
 	int $0x1A			/* TCG interrupt call */
 	
 	/* Restore registers saved at the beginning */
 	popl %edx
 	popw %di
 	popw %si
 	popw %ds
 	popw %es
 		
 	/* End TCG extension */

	/* boot stage2 */
	jmp	*(stage2_address)

/* END OF MAIN LOOP */

/*
 * BIOS Geometry translation error (past the end of the disk geometry!).
 */

general_error:
	MSG(general_error_string)

/* go here when you need to stop the machine hard after an error condition */
stop:	jmp	stop

notification_string:	.string "tGRUB "

general_error_string:	.string " Error"

/*
 * message: write the string pointed to by %si
 *
 *   WARNING: trashes %si, %ax, and %bx
 */

	/*
	 * Use BIOS "int 10H Function 0Eh" to write character in teletype mode
	 *	%ah = 0xe	%al = character
	 *	%bh = page	%bl = foreground color (graphics modes)
	 */
1:
	movw	$0x0001, %bx
	movb	$0xe, %ah
	int	$0x10		/* display a byte */
message:
	lodsb
	cmpb	$0, %al
	jne	1b	/* if not end of string, jmp to display */
	ret

	/*
	 *  Windows NT breaks compatibility by embedding a magic
	 *  number here.
	 */

	. = _start + STAGE1_WINDOWS_NT_MAGIC
nt_magic:	
	.long 0
	.word 0

	/*
	 *  This is where an MBR would go if on a hard disk.  The code
	 *  here isn't even referenced unless we're on a floppy.  Kinda
	 *  sneaky, huh?
	 */

part_start:	
	. = _start + STAGE1_PARTSTART

probe_values:
	.byte	36, 18, 15, 9, 0



	. = _start + STAGE1_PARTEND

/* the last 2 bytes in the sector 0 contain the signature */
	.word	STAGE1_SIGNATURE
