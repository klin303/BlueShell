	.section	__TEXT,__text,regular,pure_instructions
	.build_version macos, 12, 0
	.globl	_main                           ## -- Begin function main
	.p2align	4, 0x90
_main:                                  ## @main
	.cfi_startproc
## %bb.0:                               ## %entry
	pushq	%rbx
	.cfi_def_cfa_offset 16
	.cfi_offset %rbx, -16
	movl	$24, %edi
	callq	_malloc
	movq	%rax, %rbx
	leaq	L___unnamed_1(%rip), %rax
	movq	%rax, (%rbx)
	movl	$8, %edi
	callq	_malloc
	movq	$0, (%rax)
	movq	(%rbx), %rdi
	movq	%rax, %rsi
	xorl	%eax, %eax
	callq	_execvp_helper
	xorl	%eax, %eax
	popq	%rbx
	retq
	.cfi_endproc
                                        ## -- End function
	.section	__TEXT,__cstring,cstring_literals
L___unnamed_1:                          ## @0
	.asciz	"ls"

.subsections_via_symbols
