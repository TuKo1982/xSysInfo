/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: 2026 Stefan Reinauer
 */

#ifndef BERR_TRAP_H
#define BERR_TRAP_H

#include <exec/types.h>

/*
 * Probe a byte at 'addr' under bus-error protection.  Safe to call
 * for addresses that may not be decoded by any hardware.
 *
 * Returns 0 on success (*out holds the read byte), -1 on bus error
 * or address error (*out unchanged).
 *
 * 68000 only.  Do not call on 68010 or later -- the exception stack
 * frame format differs and VBR may be non-zero.
 */
int berr_probe_byte(ULONG addr, UBYTE *out);

#endif /* BERR_TRAP_H */
