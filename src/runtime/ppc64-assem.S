#ifdef __ELF__
// Mark the object as not requiring an executable stack.
.section .note.GNU-stack,"",%progbits
#endif

#define LANGUAGE_ASSEMBLY

#include "sbcl.h"
#include "lispregs.h"
#include "globals.h"

#include "genesis/simple-fun.h"
#include "genesis/fdefn.h"
#include "genesis/closure.h"
#include "genesis/funcallable-instance.h"
#include "genesis/static-symbols.h"
#ifdef LISP_FEATURE_SB_THREAD
#include "genesis/thread.h"
#endif

#ifdef LISP_FEATURE_DARWIN
#define CSYMBOL(x) _ ## x
#else
#define CSYMBOL(x) x
#endif

#if defined LISP_FEATURE_DARWIN
#define FUNCDEF(x)	.text @ \
			.align 3 @ \
_##x:

#define GFUNCDEF(x)	.globl _ ## x @ \
	FUNCDEF(x)
#else
#define FUNCDEF(x)	.text ; \
			.align 3 ; \
			.type x,@function ; \
x:

#define GFUNCDEF(x)	.globl x ; \
	FUNCDEF(x)
#endif

#if defined LISP_FEATURE_DARWIN
#define SET_SIZE(x)
#else
#define SET_SIZE(x) .size x,.-x
#endif

/* Load a register from a global, using the register as an intermediary */
/* The register will be a fixnum for one instruction, so this is gc-safe */

#if defined LISP_FEATURE_DARWIN
#define load(reg,global) \
	lis reg,ha16(global) @ \
	lwz reg,lo16(global)(reg) ; Comment
#define store(reg,temp,global) \
	lis temp,ha16(global) @\
	stw reg,lo16(global)(temp) ; Comment
#else
#define load(reg,global) \
	lis reg,global@ha       ; \
	ld reg,global@l(reg)
#define store(reg,temp,global) \
	lis temp,global@ha  	; \
	std reg,global@l(temp)
#endif

#define	FIRST_SAVE_FPR	14	/* lowest-numbered non-volatile FPR */
#ifdef LISP_FEATURE_DARWIN
#define	FIRST_SAVE_GPR	13	/* lowest-numbered non-volatile GPR */
#define NGPR_SAVE_BYTES(n) ((32-(n))*8)
#define FRAME_ARG_BYTES(n)  (((((n)+6)*8)+15)&~15)
#else
#define	FIRST_SAVE_GPR	14	/* lowest-numbered non-volatile GPR */
#define NGPR_SAVE_BYTES(n) ((32-(~1&((n)+1)))*8)
#define FRAME_ARG_BYTES(n)  (((((n)+2)*8)+15)&~15)
#endif
#define	NFPR_SAVE_BYTES(n) ((32-(n))*8)

#ifdef LISP_FEATURE_DARWIN
#define FRAME_SIZE(first_g,first_f,out_arg_words,savecr) \
(NFPR_SAVE_BYTES(first_f)+ NGPR_SAVE_BYTES(first_g)+ FRAME_ARG_BYTES(out_arg_words))
#define SAVE_FPR(n) stfd f##n,-8*(32- n)(r11)
#define SAVE_GPR(n) std r##n,-8*(32- n)(r11)
#define FULL_FRAME_SIZE (FRAME_SIZE(FIRST_SAVE_GPR,FIRST_SAVE_FPR,8,1)+15&~15)
#define RESTORE_FPR(n) lfd f##n,-8*(32- n)(r11)
#define RESTORE_GPR(n) ld r##n,-8*(32- n)(r11)
#else
#define FRAME_SIZE(first_g,first_f,out_arg_words,savecr) \
(NFPR_SAVE_BYTES(first_f)+ NGPR_SAVE_BYTES(first_g)+ FRAME_ARG_BYTES(out_arg_words+savecr))
#define SAVE_FPR(n) stfd n,-8*(32-(n))(11)
#define SAVE_GPR(n) std n,-8*(32-(n))(11)
#define FULL_FRAME_SIZE FRAME_SIZE(FIRST_SAVE_GPR,FIRST_SAVE_FPR,0,1)

#define RESTORE_FPR(n) lfd n,-8*(32-(n))(11)
#define RESTORE_GPR(n) ld n,-8*(32-(n))(11)
#endif

#ifdef LISP_FEATURE_DARWIN
#define C_FULL_PROLOG \
	nop @\
	nop @ \
	mfcr REG(0) @ \
	std REG(0),4(REG(1)) @ \
	mflr REG(0) @ \
	std REG(0),8(REG(1)) @ \
	mr REG(11),REG(1) @ \
	stdu REG(1),-FULL_FRAME_SIZE(REG(1)) @ \
	SAVE_FPR(14) @ \
	SAVE_FPR(15) @ \
	SAVE_FPR(16) @ \
	SAVE_FPR(17) @ \
	SAVE_FPR(18) @ \
	SAVE_FPR(19) @ \
	SAVE_FPR(20) @ \
	SAVE_FPR(21) @ \
	SAVE_FPR(22) @ \
	SAVE_FPR(23) @ \
	SAVE_FPR(24) @ \
	SAVE_FPR(25) @ \
	SAVE_FPR(26) @ \
	SAVE_FPR(27) @ \
	SAVE_FPR(28) @ \
	SAVE_FPR(29) @ \
	SAVE_FPR(30) @ \
	SAVE_FPR(31) @ \
	la REG(11),-NFPR_SAVE_BYTES(FIRST_SAVE_FPR)(REG(11)) @ \
	SAVE_GPR(13) @ \
	SAVE_GPR(14) @ \
	SAVE_GPR(15) @ \
	SAVE_GPR(16) @ \
	SAVE_GPR(17) @ \
	SAVE_GPR(18) @ \
	SAVE_GPR(19) @ \
	SAVE_GPR(20) @ \
	SAVE_GPR(21) @ \
	SAVE_GPR(22) @ \
	SAVE_GPR(23) @ \
	SAVE_GPR(24) @ \
	SAVE_GPR(25) @ \
	SAVE_GPR(26) @ \
	SAVE_GPR(27) @ \
	SAVE_GPR(28) @ \
	SAVE_GPR(29) @ \
	SAVE_GPR(30) @ \
	SAVE_GPR(31)


#define C_FULL_EPILOG \
	la REG(11),FULL_FRAME_SIZE-NFPR_SAVE_BYTES(FIRST_SAVE_FPR)(REG(1)) @ \
	RESTORE_GPR(13) @ \
	RESTORE_GPR(14) @ \
	RESTORE_GPR(15) @ \
	RESTORE_GPR(16) @ \
	RESTORE_GPR(17) @ \
	RESTORE_GPR(18) @ \
	RESTORE_GPR(19) @ \
	RESTORE_GPR(20) @ \
	RESTORE_GPR(21) @ \
	RESTORE_GPR(22) @ \
	RESTORE_GPR(23) @ \
	RESTORE_GPR(24) @ \
	RESTORE_GPR(25) @ \
	RESTORE_GPR(26) @ \
	RESTORE_GPR(27) @ \
	RESTORE_GPR(28) @ \
	RESTORE_GPR(29) @ \
	RESTORE_GPR(30) @ \
	RESTORE_GPR(31) @ \
	la REG(11),NFPR_SAVE_BYTES(FIRST_SAVE_FPR)(REG(11)) @ \
	RESTORE_FPR(14) @ \
	RESTORE_FPR(15) @ \
	RESTORE_FPR(16) @ \
	RESTORE_FPR(17) @ \
	RESTORE_FPR(18) @ \
	RESTORE_FPR(19) @ \
	RESTORE_FPR(20) @ \
	RESTORE_FPR(21) @ \
	RESTORE_FPR(22) @ \
	RESTORE_FPR(23) @ \
	RESTORE_FPR(24) @ \
	RESTORE_FPR(25) @ \
	RESTORE_FPR(26) @ \
	RESTORE_FPR(27) @ \
	RESTORE_FPR(28) @ \
	RESTORE_FPR(29) @ \
	RESTORE_FPR(30) @ \
	RESTORE_FPR(31) @ \
	ld REG(1),0(REG(1)) @ \
	ld REG(0),8(REG(1)) @ \
	mtcr REG(0) @ \
	ld REG(0),16(REG(1)) @ \
	mtlr REG(0) @ \

#else

#define C_FULL_PROLOG \
	mflr 0 ; \
	std 0,4(1) ; \
	mr 11,1 ; \
	stdu 1,-FULL_FRAME_SIZE(1) ; \
	SAVE_FPR(14) ; \
	SAVE_FPR(15) ; \
	SAVE_FPR(16) ; \
	SAVE_FPR(17) ; \
	SAVE_FPR(18) ; \
	SAVE_FPR(19) ; \
	SAVE_FPR(20) ; \
	SAVE_FPR(21) ; \
	SAVE_FPR(22) ; \
	SAVE_FPR(23) ; \
	SAVE_FPR(24) ; \
	SAVE_FPR(25) ; \
	SAVE_FPR(26) ; \
	SAVE_FPR(27) ; \
	SAVE_FPR(28) ; \
	SAVE_FPR(29) ; \
	SAVE_FPR(30) ; \
	SAVE_FPR(31) ; \
	la 11,-NFPR_SAVE_BYTES(FIRST_SAVE_FPR)(11) ; \
	SAVE_GPR(14) ; \
	SAVE_GPR(15) ; \
	SAVE_GPR(16) ; \
	SAVE_GPR(17) ; \
	SAVE_GPR(18) ; \
	SAVE_GPR(19) ; \
	SAVE_GPR(20) ; \
	SAVE_GPR(21) ; \
	SAVE_GPR(22) ; \
	SAVE_GPR(23) ; \
	SAVE_GPR(24) ; \
	SAVE_GPR(25) ; \
	SAVE_GPR(26) ; \
	SAVE_GPR(27) ; \
	SAVE_GPR(28) ; \
	SAVE_GPR(29) ; \
	SAVE_GPR(30) ; \
	SAVE_GPR(31) ; \
	mfcr 0	; \
	std 0,8(1)

#define C_FULL_EPILOG \
	ld 5,8(1) ; \
	mtcrf 255,5 ; \
	la 11,FULL_FRAME_SIZE-NFPR_SAVE_BYTES(FIRST_SAVE_FPR)(1) ; \
	RESTORE_GPR(14) ; \
	RESTORE_GPR(15) ; \
	RESTORE_GPR(16) ; \
	RESTORE_GPR(17) ; \
	RESTORE_GPR(18) ; \
	RESTORE_GPR(19) ; \
	RESTORE_GPR(20) ; \
	RESTORE_GPR(21) ; \
	RESTORE_GPR(22) ; \
	RESTORE_GPR(23) ; \
	RESTORE_GPR(24) ; \
	RESTORE_GPR(25) ; \
	RESTORE_GPR(26) ; \
	RESTORE_GPR(27) ; \
	RESTORE_GPR(28) ; \
	RESTORE_GPR(29) ; \
	RESTORE_GPR(30) ; \
	RESTORE_GPR(31) ; \
	la 11,NFPR_SAVE_BYTES(FIRST_SAVE_FPR)(11) ; \
	RESTORE_FPR(14) ; \
	RESTORE_FPR(15) ; \
	RESTORE_FPR(16) ; \
	RESTORE_FPR(17) ; \
	RESTORE_FPR(18) ; \
	RESTORE_FPR(19) ; \
	RESTORE_FPR(20) ; \
	RESTORE_FPR(21) ; \
	RESTORE_FPR(22) ; \
	RESTORE_FPR(23) ; \
	RESTORE_FPR(24) ; \
	RESTORE_FPR(25) ; \
	RESTORE_FPR(26) ; \
	RESTORE_FPR(27) ; \
	RESTORE_FPR(28) ; \
	RESTORE_FPR(29) ; \
	RESTORE_FPR(30) ; \
	RESTORE_FPR(31) ; \
	ld 1,0(1) ; \
	ld 0,4(1) ; \
	mtlr 0 ; \

#endif

#ifdef LISP_FEATURE_SB_SAFEPOINT
/* the CSP page sits right before the thread */
# define THREAD_SAVED_CSP_OFFSET (-N_WORD_BYTES)
#endif

	.text

/*
 * Function to transfer control into lisp.  The lisp object to invoke is
 * passed as the first argument, which puts it in NL0
 */

	GFUNCDEF(call_into_lisp)
	C_FULL_PROLOG
	/* NL0 - function, NL1 - frame pointer, NL2 - nargs. */
#if defined(LISP_FEATURE_SB_THREAD)
	/* We need to obtain a pointer to our TLS block before we do
	 * anything else.  For this, we call pthread_getspecific().
	 * We've preserved all of the callee-saves registers, so we
	 * can use them to stash our arguments temporarily while we
	 * make the call. */
	mr reg_A0, reg_NL0
	mr reg_A1, reg_NL1
	mr reg_A2, reg_NL2

	/* Call out to obtain our TLS block. */
	load(reg_NL0,CSYMBOL(specials))
	/* This won't work on darwin: wrong fixup style.  And is it
	 * supposed to be lis/ori or lis/addi?  Or does it differ
	 * between darwin and everything else again? */
	lis reg_CFUNC,CSYMBOL(pthread_getspecific)@h
	ori reg_CFUNC,reg_CFUNC,CSYMBOL(pthread_getspecific)@l
	mtctr reg_CFUNC
	bctrl
	mr reg_THREAD, reg_NL0

	/* Restore our original parameters. */
	mr reg_NL2, reg_A2
	mr reg_NL1, reg_A1
	mr reg_NL0, reg_A0
#endif
	/* Initialize tagged registers */
	li reg_ZERO,0
	li reg_CODE,0
	li reg_CNAME,0
	li reg_LEXENV,0
	li reg_FDEFN,0
	li reg_OCFP,0
	li reg_LRA,0
	li reg_A0,0
	li reg_A1,0
	li reg_A2,0
	li reg_A3,0
	li reg_L0,0
	li reg_L1,0
#if !defined(LISP_FEATURE_SB_THREAD)
	li reg_L2,0
#endif
	li reg_LIP,0
#ifdef LISP_FEATURE_DARWIN	
	lis reg_NULL,hi16(NIL)
	ori reg_NULL,reg_NULL,lo16(NIL)
#else
	lis reg_NULL,NIL@h
	ori reg_NULL,reg_NULL,NIL@l
#endif
	/* Turn on pseudo-atomic */

	li reg_ALLOC,flag_PseudoAtomic
#if defined(LISP_FEATURE_SB_THREAD)
	std reg_ZERO,THREAD_FOREIGN_FUNCTION_CALL_ACTIVE_OFFSET(reg_THREAD)
	ld reg_BSP,THREAD_BINDING_STACK_POINTER_OFFSET(reg_THREAD)
	ld reg_CSP,THREAD_CONTROL_STACK_POINTER_OFFSET(reg_THREAD)
	ld reg_OCFP,THREAD_CONTROL_FRAME_POINTER_OFFSET(reg_THREAD)
#else
	store(reg_ZERO,reg_NL4,CSYMBOL(foreign_function_call_active))
	load(reg_BSP,CSYMBOL(current_binding_stack_pointer))
	load(reg_CSP,CSYMBOL(current_control_stack_pointer))
	load(reg_OCFP,CSYMBOL(current_control_frame_pointer))
#endif
	/* This is important for CHENEYGC: It's the allocation
	 * pointer.  It's also important for ROOM on GENCGC:
	 * It's a pointer to the end of dynamic space, used to
	 * determine where to stop in MAP-ALLOCATED-OBJECTS. */
	load(reg_NL4,CSYMBOL(dynamic_space_free_pointer))
	add reg_ALLOC,reg_ALLOC,reg_NL4

	/* No longer atomic, and check for interrupt */
	subi reg_ALLOC,reg_ALLOC,flag_PseudoAtomic
	andi. reg_NL3, reg_ALLOC, flag_PseudoAtomicInterrupted
	twnei reg_NL3, 0

	/* Pass in the arguments */

	mr reg_CFP,reg_NL1
	mr reg_LEXENV,reg_NL0
	ld reg_A0,0(reg_CFP)
	ld reg_A1,8(reg_CFP)
	ld reg_A2,16(reg_CFP)
	ld reg_A3,24(reg_CFP)

	/* Calculate LRA */
#ifdef LISP_FEATURE_DARWIN
	lis reg_LRA,ha16(lra)
	addi reg_LRA,reg_LRA,lo16(lra)
#else
	lis reg_LRA,lra@h
	ori reg_LRA,reg_LRA,lra@l
#endif
	addi reg_LRA,reg_LRA,OTHER_POINTER_LOWTAG

	/* Function is an indirect closure */
	addi reg_A0,reg_LEXENV,SIMPLE_FUN_SELF_OFFSET
	ld reg_CODE,0(reg_A0)
	addi reg_LIP,reg_CODE,SIMPLE_FUN_CODE_OFFSET
	mtctr reg_LIP
	sldi reg_NARGS, reg_NL2, N_FIXNUM_TAG_BITS
	bctr

	.align 3
lra:
	.long RETURN_PC_WIDETAG

	/* Blow off any extra values. */
	mr reg_CSP,reg_OCFP
	nop

	/* Return the one value. */

	mr REG(3),reg_A0

	/* Turn on  pseudo-atomic */
	la reg_ALLOC,flag_PseudoAtomic(reg_ALLOC)

#if defined(LISP_FEATURE_SB_THREAD)
	/* Store lisp state */
	std reg_BSP,THREAD_BINDING_STACK_POINTER_OFFSET(reg_THREAD)
	std reg_CSP,THREAD_CONTROL_STACK_POINTER_OFFSET(reg_THREAD)
	std reg_CFP,THREAD_CONTROL_FRAME_POINTER_OFFSET(reg_THREAD)

	/* No longer in Lisp. */
	std reg_ALLOC,THREAD_FOREIGN_FUNCTION_CALL_ACTIVE_OFFSET(reg_THREAD)
#else
	/* Store lisp state */
	clrrwi reg_NL1,reg_ALLOC,3
	store(reg_NL1,reg_NL2,CSYMBOL(dynamic_space_free_pointer))
	/* load(reg_NL2,current_thread) */
	store(reg_BSP,reg_NL2,CSYMBOL(current_binding_stack_pointer))
	store(reg_CSP,reg_NL2,CSYMBOL(current_control_stack_pointer))
	store(reg_CFP,reg_NL2,CSYMBOL(current_control_frame_pointer))

	/* No longer in Lisp. */
	store(reg_NL1,reg_NL2,CSYMBOL(foreign_function_call_active))
#endif

	/* Check for interrupt */
	subi reg_ALLOC, reg_ALLOC, flag_PseudoAtomic
	andi. reg_NL3, reg_ALLOC, flag_PseudoAtomicInterrupted
	twnei reg_NL3,0

	/* Back to C */
	C_FULL_EPILOG
	blr
	SET_SIZE(call_into_lisp)


	GFUNCDEF(call_into_c)
	/* In the 64-bit ABI, a function pointer is a pointer to a
	 * 3-word "function descriptor" the first word of which contains the
	 * entry address, and the second the value that the callee needs
	 * in the TOC register. The third word can be ignored for C. */
	ld reg_TOC, 8(reg_CFUNC)
	ld reg_CFUNC, 0(reg_CFUNC)
	/* We're kind of low on unboxed, non-dedicated registers here:
	most of the unboxed registers may have outgoing C args in them.
	CFUNC is going to have to go in the CTR in a moment, anyway
	so we'll free it up soon.  reg_NFP is preserved by lisp if it
	has a meaningful value in it, so we can use it.  reg_NARGS is
	free when it's not holding a copy of the "real" reg_NL3, which
	gets tied up by the pseudo-atomic mechanism */
	mtctr reg_CFUNC
	mflr reg_LIP
	/* Build a lisp stack frame */
	mr reg_OCFP,reg_CFP
	mr reg_CFP,reg_CSP
	la reg_CSP,32(reg_CSP)
	std reg_OCFP,0(reg_CFP)
	std reg_CODE,8(reg_CFP)
	/* The pseudo-atomic mechanism wants to use reg_NL3, but that
	may be an outgoing C argument.  Copy reg_NL3 to something that's
	unboxed and -not- one of the C argument registers */
	mr reg_NARGS,reg_NL3

	/* Turn on pseudo-atomic */
	la reg_ALLOC,flag_PseudoAtomic(reg_ALLOC)

	/* Convert the return address to an offset and save it on the stack. */
	sub reg_NFP,reg_LIP,reg_CODE
	la reg_NFP,OTHER_POINTER_LOWTAG(reg_NFP)
	std reg_NFP,8(reg_CFP)

#ifdef LISP_FEATURE_SB_THREAD
	/* Store Lisp state */
	std reg_BSP,THREAD_BINDING_STACK_POINTER_OFFSET(reg_THREAD)
	std reg_CSP,THREAD_CONTROL_STACK_POINTER_OFFSET(reg_THREAD)
	std reg_CFP,THREAD_CONTROL_FRAME_POINTER_OFFSET(reg_THREAD)

	/* No longer in Lisp. */
	std reg_CSP,THREAD_FOREIGN_FUNCTION_CALL_ACTIVE_OFFSET(reg_THREAD)
#else
	/* Store Lisp state */
	clrrwi reg_NFP,reg_ALLOC,3
	store(reg_NFP,reg_CFUNC,CSYMBOL(dynamic_space_free_pointer))
	/* load(reg_CFUNC,current_thread) */

	store(reg_BSP,reg_CFUNC,CSYMBOL(current_binding_stack_pointer))
	store(reg_CSP,reg_CFUNC,CSYMBOL(current_control_stack_pointer))
	store(reg_CFP,reg_CFUNC,CSYMBOL(current_control_frame_pointer))

	/* No longer in Lisp */
	store(reg_CSP,reg_CFUNC,CSYMBOL(foreign_function_call_active))
#endif
	/* Disable pseudo-atomic; check pending interrupt */
	subi reg_ALLOC, reg_ALLOC, flag_PseudoAtomic
	andi. reg_NL3, reg_ALLOC, flag_PseudoAtomicInterrupted
	twnei reg_NL3, 0

#ifdef LISP_FEATURE_SB_SAFEPOINT
	/* OK to run GC without stopping this thread from this point on. */
#  ifdef LISP_FEATURE_SB_THREAD
	stw reg_CSP,THREAD_SAVED_CSP_OFFSET(reg_THREAD)
#  else
	load(reg_CFUNC,CSYMBOL(all_threads))
	stw reg_CSP,THREAD_SAVED_CSP_OFFSET(reg_CFUNC)
#  endif
#endif

	mr reg_NL3,reg_NARGS

#ifdef LISP_FEATURE_DARWIN
	/* PowerOpen (i.e. OS X) requires the callee address in r12
           (a.k.a. CFUNC), so move it back there, too. */
	mfctr reg_CFUNC
#endif
        /* Into C we go. */
	bctrl

	/* Re-establish NIL */
#ifdef LISP_FEATURE_DARWIN
	lis reg_NULL,hi16(NIL)
	ori reg_NULL,reg_NULL,lo16(NIL)
#else
	lis reg_NULL,NIL@h
	ori reg_NULL,reg_NULL,NIL@l
#endif
	/* And reg_ZERO */
	li reg_ZERO,0

	/* If we GC'ed during the FF code (as the result of a callback ?)
	the tagged lisp registers may now contain garbage (since the
	registers were saved by C and not seen by the GC.)  Put something
	harmless in all such registers before allowing an interrupt */
        li reg_FDEFN,0
	li reg_CODE,0
	li reg_CNAME,0
	li reg_LEXENV,0
	/* reg_OCFP was pointing to a control stack frame & was preserved by C */
	li reg_LRA,0
	li reg_A0,0
	li reg_A1,0
	li reg_A2,0
	li reg_A3,0
	li reg_L0,0
	li reg_L1,0
#if !defined(LISP_FEATURE_SB_THREAD)
	/* reg_L2 is our TLS block pointer. */
	li reg_L2,0
#endif
	li reg_LIP,0

# ifdef LISP_FEATURE_SB_SAFEPOINT
	/* No longer OK to run GC except at safepoints. */
#  ifdef LISP_FEATURE_SB_THREAD
	stw reg_ZERO,THREAD_SAVED_CSP_OFFSET(reg_THREAD)
#  else
	load(reg_BSP,CSYMBOL(all_threads))
	stw reg_ZERO,THREAD_SAVED_CSP_OFFSET(reg_BSP)
#  endif
# endif

	/* Atomic ... */
	li reg_ALLOC,flag_PseudoAtomic

#if defined(LISP_FEATURE_SB_THREAD)
	/* No longer in foreign function call. */
	stw reg_ZERO,THREAD_FOREIGN_FUNCTION_CALL_ACTIVE_OFFSET(reg_THREAD)

	/* The binding stack pointer isn't preserved by C. */
	lwz reg_BSP,THREAD_BINDING_STACK_POINTER_OFFSET(reg_THREAD)
#else
	/* No long in foreign function call. */
	store(reg_ZERO,reg_NL2,CSYMBOL(foreign_function_call_active))

	/* The free pointer may have moved */
	/* (moved below) */

	/* The BSP wasn't preserved by C, so load it */
	load(reg_BSP,CSYMBOL(current_binding_stack_pointer))
#endif
	/* This is important for CHENEYGC: It's the allocation
	 * pointer.  It's also important for ROOM on GENCGC:
	 * It's a pointer to the end of dynamic space, used to
	 * determine where to stop in MAP-ALLOCATED-OBJECTS. */
	load(reg_NL4,CSYMBOL(dynamic_space_free_pointer))
	add reg_ALLOC,reg_ALLOC,reg_NL4

	/* Other lisp stack/frame pointers were preserved by C.
	I can't imagine why they'd have moved */

	/* Get the return address back. */
	lwz reg_LIP,8(reg_CFP)
	lwz reg_CODE,16(reg_CFP)
	add reg_LIP,reg_CODE,reg_LIP
	la reg_LIP,-OTHER_POINTER_LOWTAG(reg_LIP)

        /* Debugger expects LR to be valid when we come out of PA */
	mtlr reg_LIP

	/* No longer atomic */
	subi reg_ALLOC, reg_ALLOC, flag_PseudoAtomic
	andi. reg_NL3, reg_ALLOC, flag_PseudoAtomicInterrupted
	twnei reg_NL3, 0

	/* Reset the lisp stack. */
	mr reg_CSP,reg_CFP
	mr reg_CFP,reg_OCFP

	/* And back into Lisp. */
	blr

	SET_SIZE(call_into_c)

	/* The fun_end_breakpoint support here is considered by the
	authors of the other $ARCH-assem.S files to be magic, and it
	is.  It is a small fragment of code that is copied into a heap
	code-object when needed, and contains an LRA object, code to
	convert a single-value return to unknown-values format, and a
	trap_FunEndBreakpoint. */
	GFUNCDEF(fun_end_breakpoint_guts)
	.globl CSYMBOL(fun_end_breakpoint_trap)
	.globl CSYMBOL(fun_end_breakpoint_end)

	/* Due to pointer verification in MAKE-LISP-OBJ, this must
	include its header data (the offset from the start of the
	code-object to the LRA).  The code-object header is 4
	words, there are 1 word of constants, and the instruction
	space is doubleword-aligned, making an offset of six.
	This is header data for a widetag, so shift left eight bits
	and add. */
        /* FIXME: the above is full of magic numbers. */
	.long RETURN_PC_WIDETAG + 0x600

	/* We are receiving unknown multiple values, thus must deal
	with the single-value and multiple-value cases separately. */
	b fun_end_breakpoint_multiple_values
	nop

	/* Compute the correct value for reg_CODE based on the LRA.
	This is a "simple" matter of subtracting a constant from
	reg_LRA (where the LRA is stored by the return sequence) to
	obtain a tagged pointer to the enclosing code component.  Both
	values are tagged OTHER_POINTER_LOWTAG, so we just have to
	account for the six words (see calculation for
	RETURN_PC_WIDETAG, above) between the two addresses.
	Restoring reg_CODE doesn't appear to be strictly necessary
	here, but let's observe the niceties.*/
	addi reg_CODE, reg_LRA, -24

	/* Multiple values are stored relative to reg_OCFP, which we
	set to be the current top-of-stack. */
	mr reg_OCFP, reg_CSP

	/* Reserve a save location for the one value we have. */
	addi reg_CSP, reg_CSP, 4

	/* Record the number of values we have as a FIXNUM. */
	li reg_NARGS, 4

	/* Blank the remaining arg-passing registers. */
	mr reg_A1, reg_NULL
	mr reg_A2, reg_NULL
	mr reg_A3, reg_NULL

	/* And branch to our trap. */
	b CSYMBOL(fun_end_breakpoint_trap)

fun_end_breakpoint_multiple_values:
	/* Compute the correct value for reg_CODE.  See the
	explanation for the single-value case, above. */
	addi reg_CODE, reg_LRA, -24

	/* The actual magic trap. */
CSYMBOL(fun_end_breakpoint_trap):
	twllei	reg_ZERO, trap_FunEndBreakpoint

	/* Finally, the debugger needs to know where the end of the
	fun_end_breakpoint_guts are, so that it may calculate its size
	in order to populate out a suitably-sized code object. */
CSYMBOL(fun_end_breakpoint_end):
	SET_SIZE(fun_end_breakpoint_guts)


	GFUNCDEF(ppc_flush_cache_line)
	dcbf 0,REG(3)
	sync
	icbi 0,REG(3)
	sync
	isync
	blr
	SET_SIZE(ppc_flush_cache_line)

        GFUNCDEF(do_pending_interrupt)
	trap
	blr
/* King Nato's branch has a nop here. Do we need this? */
	SET_SIZE(do_pending_interrupt)