/*
 * Phoenix-RTOS
 *
 * Operating system kernel
 *
 * Exception and interrupt handling
 *
 * Copyright 2016, 2012 Phoenix Systems
 * Copyright 2001, 2005, 2006 Pawel Pisarczyk
 * Author: Pawel Pisarczyk
 *
 * This file is part of Phoenix-RTOS.
 *
 * %LICENSE%
 */

#ifndef _HAL_IA32_INTERRUPTS_H_
#define _HAL_IA32_INTERRUPTS_H_

#include "cpu.h"

#define SYSTICK_IRQ 0
#define SYSCALL_IRQ 0x80
#define TLB_IRQ     0x81

typedef struct _intr_handler_t {
	struct _intr_handler_t *next;
	struct _intr_handler_t *prev;
	unsigned int n;
	int (*f)(unsigned int, cpu_context_t *, void *);
	void *data;
} intr_handler_t;


#endif
