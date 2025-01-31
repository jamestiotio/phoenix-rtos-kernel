/*
 * Phoenix-RTOS
 *
 * Operating system kernel
 *
 * Interrupt stubs
 *
 * Copyright 2018, 2020, 2023 Phoenix Systems
 * Author: Pawel Pisarczyk, Julia Kosowska, Lukasz Leczkowski
 *
 * This file is part of Phoenix-RTOS.
 *
 * %LICENSE%
 */

#define __ASSEMBLY__


#define SR_SIE 0x00000002
#define SR_FS  0x00006000
#define SR_SUM 0x00040000
#define SR_MXR 0x00080000


#include <arch/cpu.h>

.text

.macro SAVE
	/* If coming from userspace, save thread pointer in sscratch and load kernel sp.
	 * If coming from kernel, sscratch is 0, so we don't swap.
	 */
	csrrw tp, sscratch, tp
	bnez tp, 1f

	/* Current stack is kernel stack */
	sd sp, -8(sp)

	addi sp, sp, -296
	j 2f

1:
	/* Save context, tp now holds kernel stack pointer.
	 * Original tp is saved in sscratch
	 */

	/* Save task's stack pointer */
	sd sp, -8(tp)

	/* Swap to current stack */
	addi sp, tp, -296

2:
	/* restore tp & sscratch */
	csrrw tp, sscratch, tp

	/* Save context */
	sd x1, (sp)          /* ra */
	sd x3, 8(sp)         /* gp */
	sd x5, 16(sp)        /* t0 */
	sd x6, 24(sp)        /* t1 */
	sd x7, 32(sp)        /* t2 */
	sd x8, 40(sp)        /* s0 */
	sd x9, 48(sp)        /* s1 */
	sd x10, 56(sp)       /* a0 */
	sd x11, 64(sp)       /* a1 */
	sd x12, 72(sp)       /* a2 */
	sd x13, 80(sp)       /* a3 */
	sd x14, 88(sp)       /* a4 */
	sd x15, 96(sp)       /* a5 */
	sd x16, 104(sp)      /* a6 */
	sd x17, 112(sp)      /* a7 */
	sd x18, 120(sp)      /* s2 */
	sd x19, 128(sp)      /* s3 */
	sd x20, 136(sp)      /* s4 */
	sd x21, 144(sp)      /* s5 */
	sd x22, 152(sp)      /* s6 */
	sd x23, 160(sp)      /* s7 */
	sd x24, 168(sp)      /* s8 */
	sd x25, 176(sp)      /* s9 */
	sd x26, 184(sp)      /* s10 */
	sd x27, 192(sp)      /* s11 */
	sd x28, 200(sp)      /* t3 */
	sd x29, 208(sp)      /* t4 */
	sd x30, 216(sp)      /* t5 */
	sd x31, 224(sp)      /* t6 */

	sd sp, 232(sp)       /* ksp */

	/* Disable FPU */
	li t0, SR_FS
	csrc sstatus, t0
	/* Allow supervisor access to user space and reading from execute pages (for the time being) */
	li t0, SR_SUM | SR_MXR
	csrs sstatus, t0

	csrrc s1, sstatus, SR_SIE
	csrr s2, sepc
	csrr s3, sbadaddr
	csrr s4, scause
	csrr s5, sscratch

	sd s1, 240(sp)   /* sstatus */
	sd s2, 248(sp)   /* sepc */
	sd s3, 256(sp)   /* sbadaddr */
	sd s4, 264(sp)   /* scause */
	sd s5, 272(sp)   /* sscratch */

	sd tp, 280(sp)   /* tp */

	/* Kernel mode entered */
	csrw sscratch, zero
.endm


.macro RESTORE
	/* Switch kernel stack */
	ld sp, 232(sp)
	ld tp, 272(sp)

	/* Kernel mode left - this loads ksp to sscratch if returning to userspace, else 0 */
	csrw sscratch, tp

	ld a0, 240(sp)
	andi a0, a0, ~SR_SIE
	csrw sstatus, a0

	ld a2, 248(sp)
	csrw sepc, a2

	ld x1, (sp)          /* ra */
	ld x3, 8(sp)         /* gp */
	ld x5, 16(sp)        /* t0 */
	ld x6, 24(sp)        /* t1 */
	ld x7, 32(sp)        /* t2 */
	ld x8, 40(sp)        /* s0 */
	ld x9, 48(sp)        /* s1 */
	ld x10, 56(sp)       /* a0 */
	ld x11, 64(sp)       /* a1 */
	ld x12, 72(sp)       /* a2 */
	ld x13, 80(sp)       /* a3 */
	ld x14, 88(sp)       /* a4 */
	ld x15, 96(sp)       /* a5 */
	ld x16, 104(sp)      /* a6 */
	ld x17, 112(sp)      /* a7 */
	ld x18, 120(sp)      /* s2 */
	ld x19, 128(sp)      /* s3 */
	ld x20, 136(sp)      /* s4 */
	ld x21, 144(sp)      /* s5 */
	ld x22, 152(sp)      /* s6 */
	ld x23, 160(sp)      /* s7 */
	ld x24, 168(sp)      /* s8 */
	ld x25, 176(sp)      /* s9 */
	ld x26, 184(sp)      /* s10 */
	ld x27, 192(sp)      /* s11 */
	ld x28, 200(sp)      /* t3 */
	ld x29, 208(sp)      /* t4 */
	ld x30, 216(sp)      /* t5 */
	ld x31, 224(sp)      /* t6 */

	ld tp, 280(sp)       /* tp */

	/* Restore task's stack pointer */
	ld sp, 288(sp)
.endm


.global interrupts_handleintexc
.type interrupts_handleintexc, @function
interrupts_handleintexc:
.align 8
	/* Disable interrupts */
	csrc sstatus, SR_SIE

	SAVE
	mv a0, sp

	li t1, 8
	beq s4, t1, 3f
	bge s4, zero, 2f

	li t1, 0x8000000000000009
	bne s4, t1, 33f
	li a0, 0xa
	j 34f

33:
	li t1, 0x8000000000000005
	bne s4, t1, 34f
	call handler
	mv a0, zero
34:
	mv a1, sp
	call interrupts_dispatchIRQ
	j 4f

2:
	mv a0, s4
	andi a0, a0, 0xf
	mv a1, sp
	call exceptions_dispatch
	j 5f
3:
	addi s2, s2, 4 /* move pc past ecall instruction */
	sd s2, 248(sp)
	mv a0, a7 /* syscall number */
	ld a1, 288(sp) /* ustack */

	csrs sstatus, SR_SIE
	call syscalls_dispatch
	sd a0, 56(sp)
	csrc sstatus, SR_SIE
	j 5f
4:
	beq a0, zero, 5f
	li a0, 0
	mv a1, sp
	call threads_schedule

5:
	RESTORE
	sret
.size interrupts_handleintexc, .-interrupts_handleintexc



.global hal_cpuReschedule
hal_cpuReschedule:
	/* Disable interrupts */
	csrc sstatus, SR_SIE

	/* Save return address */
	csrw sepc, ra

	SAVE

	beqz a0, 1f

	/* Modify saved status */
	ld t0, (a1)
	sd t0, 240(sp)

	/* Clear spinlock */
	li t0, 1
	addi a0, a0, 24
	amoswap.w.rl t0, t0, (a0)
1:
	ld t0, 240(sp)
	sd zero, 56(sp)

	ori t0, t0, 0x100
	andi t1, t0, 0x2
	sll t1, t1, 4
	andi t0, t0, ~2
	or t0, t0, t1

	/* Save modified flags in old context */
	sd t0, 240(sp)

	mv a1, sp
	mv a2, zero
	call threads_schedule

	RESTORE
	sret
.size hal_cpuReschedule, .-hal_cpuReschedule


.global hal_longjmp
hal_longjmp:
	mv sp, a0
	sd a0, 232(sp)
	RESTORE
	sret
.size hal_longjmp, .-hal_longjmp


.global hal_jmp  /* void hal_jmp(void *f, void *kstack, void *stack, int argc) */
hal_jmp:
	mv s0, a0
	mv s1, a1
	mv s2, a2
	mv s3, a3
	csrc sstatus, SR_SIE /* disable interrupts */

	bnez a2, 2f

	mv sp, s1
	addi s3, s3, -1
	blt s3, zero, 1f
	ld a0, (sp)
	addi sp, sp, 8
	addi s3, s3, -1
	blt s3, zero, 1f
	ld a1, (sp)
	addi sp, sp, 8
	addi s3, s3, -1
	blt s3, zero, 1f
	ld a2, (sp)
	addi sp, sp, 8
	addi s3, s3, -1
	blt s3, zero, 1f
	ld a3, (sp)
	addi sp, sp, 8
1:
	csrs sstatus, SR_SIE /* enable interrupts */
	jr s0

2:
	csrw sscratch, s1 /* kernel stack pointer */

	mv sp, s2 /* user stack pointer */

	addi s3, s3, -1
	blt s3, zero, 3f
	ld a0, (sp)
	addi sp, sp, 8
	addi s3, s3, -1
	blt s3, zero, 3f
	ld a1, (sp)
	addi sp, sp, 8
	addi s3, s3, -1
	blt s3, zero, 3f
	ld a2, (sp)
	addi sp, sp, 8
	addi s3, s3, -1
	blt s3, zero, 3f
	ld a3, (sp)
	addi sp, sp, 8
3:
	li t0, 0x120
	csrc sstatus, t0 /* sret will return to usermode */
	csrw sepc, s0 /* address to return to */

	sret
.size hal_jmp, .-hal_jmp
