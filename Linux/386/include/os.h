/*
 * Linux 386
 */

/*
 * This structure must agree with FPsave and FPrestore asm routines
 */
typedef struct FPU FPU;
struct FPU
{
        uchar	env[28];
};

#include <dirent.h>
#define	DIRTYPE	struct dirent

extern	Proc*	uptab[];

#define up (getup())

static inline Proc*
getup(void)
{
	Proc *p;

	__asm__(	"xorl	%%eax, %%eax\n\t"
			"str	%%ax\n\t"
			"shrl	$4,%%eax\n\t"
			"movl	uptab(,%%eax,4), %%eax"
			: "=a" (p)
	);

	return p;
}

static inline ulong
gettss(void)
{
	ulong	x;

	__asm__(	"xorl	%%eax, %%eax\n\t"
			"str	%%ax\n\t"
			"shrl	$4,%%eax\n\t"
			: "=a" (x)
	);

	return x;
}
