; SPDX-License-Identifier: BSD-2-Clause
; SPDX-FileCopyrightText: 2026 Stefan Reinauer
;
; Bus-error-protected memory probe for pre-Gary Amigas.
;
; Classic A1000 address decoding is done by discrete GALs with no
; programmable timeout register (unlike Fat Gary on A3000/A4000, which
; can be flipped from BERR to DSACK mode).  To check for optional
; hardware like the Spirit Insider 1000's MK48T02 TimeKeeper without
; crashing on a stock machine, we temporarily hook the bus-error and
; address-error exception vectors with a handler that skips the
; faulting read and returns an error flag.
;
; Callable from C only on plain 68000 (VBR = 0, simple group-0 stack
; frame).  Callers must check cpu_type before invoking.

        INCDIR  "include:"
        INCLUDE "lvo/exec_lib.i"

        SECTION Code,CODE
        MACHINE 68000

        XDEF    _berr_probe_byte

BusErrorVector      EQU     $8
AddressErrorVector  EQU     $C

;------------------------------------------------------------------
; int berr_probe_byte(ULONG addr, UBYTE *out)
;   Reads one byte from 'addr' under bus-error protection.
;   Returns 0 on success (value stored in *out) or -1 on bus/address
;   error (*out left untouched).
;   68000 only.  C calling convention: args on stack.
;------------------------------------------------------------------
_berr_probe_byte:
        movem.l d2/a2/a5/a6,-(sp)
        move.l  4+16(sp),d2         ; addr
        move.l  8+16(sp),a2         ; out pointer
        lea     probe_super(pc),a5
        move.l  $4.w,a6
        jsr     _LVOSupervisor(a6)
        movem.l (sp)+,d2/a2/a5/a6
        rts

;------------------------------------------------------------------
; Supervisor-mode body.  Entered with:
;   d2 = probe address
;   a2 = destination byte pointer
; Returns status in d0 (0 ok, -1 fault).
;------------------------------------------------------------------
probe_super:
        movem.l a3-a4,-(sp)

        ; Save old vectors (68000: vector table at absolute 0).
        move.l  BusErrorVector.w,-(sp)
        move.l  AddressErrorVector.w,-(sp)

        ; Install trap handler.
        lea     berr_handler(pc),a4
        move.l  a4,BusErrorVector.w
        move.l  a4,AddressErrorVector.w

        moveq   #0,d0               ; assume success
        move.l  d2,a4               ; a4 = probe address
        move.b  (a4),d1             ; <- may fault
        move.b  d1,(a2)             ; store result
        bra.s   probe_done

;------------------------------------------------------------------
; 68000 group-0 (bus/address error) exception handler.
;
; Stack frame pushed by CPU (14 bytes) on entry:
;   SSP+0  word   function code / R-W / I-N
;   SSP+2  long   access address
;   SSP+6  word   instruction register
;   SSP+8  word   status register
;   SSP+10 long   program counter
;
; We patch the stacked PC to point at probe_done, then drop the extra
; 8 bytes so the frame looks like a normal group-1 frame and RTE can
; resume execution past the faulting instruction.
;------------------------------------------------------------------
berr_handler:
        moveq   #-1,d0              ; fault flag
        lea     probe_done(pc),a1
        move.l  a1,10(sp)           ; patch stacked PC (PC-relative form)
        addq.l  #8,sp               ; discard FC/AA/IR words
        rte

probe_done:
        ; Restore old vectors.
        move.l  (sp)+,AddressErrorVector.w
        move.l  (sp)+,BusErrorVector.w

        movem.l (sp)+,a3-a4
        rte                         ; return from Supervisor()

        END
