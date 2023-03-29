	.section	__TEXT,__text,regular,pure_instructions
	.build_version macos, 12, 0
	.globl	_main                           ## -- Begin function main
	.p2align	4, 0x90
_main:                                  ## @main
	.cfi_startproc
## %bb.0:                               ## %entry
	pushq	%rax
	.cfi_def_cfa_offset 16
	movl	$24, %edi
	callq	_malloc
	leaq	L___unnamed_1(%rip), %rdi
	movq	%rdi, (%rax)
	xorl	%esi, %esi
	xorl	%eax, %eax
	callq	_execvp_helper
	xorl	%eax, %eax
	popq	%rcx
	retq
	.cfi_endproc
                                        ## -- End function
	.section	__TEXT,__cstring,cstring_literals
L___unnamed_1:                          ## @0
	.asciz	"who"

.subsections_via_symbols
