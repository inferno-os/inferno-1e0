implement Regex;

include "regex.m";

# syntax

# RE	ALT		regular expression
#	NUL
# ALT	CAT		alternation
# 	CAT | ALT
#
# CAT	DUP		catenation
# 	DUP CAT
#
# DUP	PRIM		possibly duplicated primary
# 	PCLO
# 	CLO
# 	OPT
#
# PCLO	PRIM +		1 or more
# CLO	PRIM *		0 or more
# OPT	PRIM ?		0 or 1
#
# PRIM	( RE )
#	()
# 	DOT		any character
# 	CHAR		a single character
#	ESC		escape sequence
# 	[ SET ]		character set
# 	NUL		null string
# 	HAT		beginning of string
# 	DOL		end of string
#

NIL : con -1;		# a refRex constant
NONE: con -2;		# ditto, for an un-set value
BAD: con 1<<16;		# a non-character 
HUGE: con (1<<31) - 1;

# the data structures of re.m would like to be ref-linked, but are
# circular (see fn walk), thus instead of pointers we use indexes
# into an array (arena) of nodes of the syntax tree of a regular expression.
# from a storage-allocation standpoint, this replaces many small
# allocations of one size with one big one of variable size.

ReStr: adt {
	s : string;
	i : int;	# cursor postion
	n : int;	# number of chars left; -1 on error
	peek : fn(s: self ref ReStr): int;
	next : fn(s: self ref ReStr): int;
};

ReStr.peek(s: self ref ReStr): int
{
	if(s.n <= 0)
		return BAD;
	return s.s[s.i];
}

ReStr.next(s: self ref ReStr): int
{
	if(s.n <= 0)
		return BAD;
	s.n--;
	return s.s[s.i++];
}

newRe(kind: int, left, right: refRex, set: ref Set, ar: ref Arena): refRex
{
	ar.rex[ar.ptr] = Rex(kind, left, right, set);
	return ar.ptr++;
}

# parse a regex by recursive descent to get a syntax tree

re(s: ref ReStr, ar: ref Arena): refRex
{
	left := cat(s, ar);
	if(left==NIL || s.peek()!='|')
		return left;
	s.next();
	right := re(s, ar);
	if(right == NIL)
		return NIL;
	return newRe(ALT, left, right, nil, ar);
}

cat(s: ref ReStr, ar: ref Arena): refRex
{
	left := dup(s, ar);
	if(left == NIL)
		return left;
	right := cat(s, ar);
	if(right == NIL)
		return left;
	return newRe(CAT, left, right, nil, ar);
}

dup(s: ref ReStr, ar: ref Arena): refRex
{
	case s.peek() {
	BAD or ')' or ']' or '|' or '?' or '*' or '+' =>
		return NIL;
	}
	prim: refRex;
	case kind:=s.next() {
	'(' =>	if(s.peek() == ')') {
			s.next();
			prim = newRe(NUL, NONE, NONE, nil, ar);
		} else {
			prim = re(s, ar);
			if(prim==NIL || s.next()!=')')
				s.n = -1;
		}
	'[' =>	prim = newRe(SET, NONE, NONE, newSet(s), ar);
	* =>	case kind {
		'.' =>	kind = DOT;
		'^' =>	kind = HAT;
		'$' =>	kind = DOL;
		}
		prim = newRe(esc(s, kind), NONE, NONE, nil, ar);
	}
	case s.peek() {
	'*' =>	kind = CLO;
	'+' =>	kind = PCLO;
	'?' =>	kind = OPT;
	* =>	return prim;
	}
	s.next();
	return newRe(kind, prim, NONE, nil, ar);
}

esc(s: ref ReStr, char: int): int
{
	if(char == '\\') {
		char = s.next();
		case char {
		BAD =>	s.n = -1;
		'n' =>	char = '\n';
		}
	}
	return char;
}

# walk the tree adjusting pointers to refer to 
# next state of the finite state machine

walk(r: refRex, succ: refRex, ar: ref Arena)
{
	if(r==NONE)
		return;
	(kind, left, right, nil) := ar.rex[r];
	case kind {
	ALT =>	walk(left, succ, ar);
		walk(right, succ, ar);
		return;
	CAT =>	walk(left, right, ar);
		walk(right, succ, ar);
		ar.rex[r] = ar.rex[left];	# optimization
		return;
	CLO or PCLO =>
		end := newRe(OPT, r, succ, nil, ar); # here's the circularity
		walk(left, end, ar);
	OPT =>	walk(left, succ, ar);
	}
	ar.rex[r].right = succ;
}

compile(e: string): Re
{
	if(e == nil)
		return nil;	
	s := ref ReStr(e, 0, len e);
	ar := ref Arena(array[2*s.n] of Rex, 0, 0);	# worst case is a*b*c*...
	start := ar.start = re(s, ar);
	if(start==NIL || s.n!=0)
		return nil;
	walk(start, NIL, ar);
	return ar;
}

# todo1, todo2: queues for epsilon and advancing transitions
Trace: adt {
	cre: refRex;		# cursor in Re
	beg: int;		# where this trace began;
};
Queue: adt {
	ptr: int;
	q: array of Trace;
};

execute(re: Re, s: string): (int, int)
{
	if(re==nil || s==nil)
		return (-1,-1);
	(beg, end) := (-1, -1);
	todo1 := ref Queue(0, array[re.ptr] of Trace);
	todo2 := ref Queue(0, array[re.ptr] of Trace);
	for(i:=0; i<=len s; i++) {
		small2 := HUGE;		# earliest possible match if advance
		if(beg == -1)		# no leftmost match yet
			todo1.q[todo1.ptr++] = Trace(re.start, i);
		for(k:=0; k<todo1.ptr; k++) {
			(tcre, tbeg) := todo1.q[k];
			(kind, left, right, set) := re.rex[tcre];
			next1 := next2 := NONE;
			case kind {
			NUL =>	next1 = right;
			DOT =>	if(i<len s && s[i]!='\n')
					next2 = right;
			HAT =>  if(i == 0)
					next1 = right;
			DOL =>	if(i == len s)
					next1 = right;
			SET => if(i<len s && member(s[i], set))
					next2 = right;
			CAT or PCLO =>	next1 = left;
			ALT or CLO or OPT =>
				next1 = right;
				k = insert(left, tbeg, todo1, k);
			* =>	if(i<len s && kind==s[i])
					next2 = right;
			}
			if(next1 != NONE)
				if(next1 != NIL)
					k =insert(next1, tbeg, todo1, k);
				else if(better(tbeg, i, beg, end))
					(beg, end) = (tbeg, i);
			if(next2 != NONE)
				if(next2 != NIL) {
					if(tbeg < small2)
						small2 = tbeg;
					insert(next2, tbeg, todo2, 0);
				 } else if(better(beg, i+1, beg, end))
					(beg, end) = (tbeg, i+1);
			
		}
		if(beg!=-1 && beg<small2)	# nothing better possible
			break;
		temp := todo1;
		todo1 = todo2;
		todo2 = temp;
		todo2.ptr = 0;
	}
	return (beg, end);
}

better(newbeg, newend, oldbeg, oldend: int): int
{
	return oldbeg==-1 || newbeg<oldbeg ||
	       newbeg==oldbeg && newend>oldend;
}

insert(next: refRex, tbeg: int, todo: ref Queue, k: int): int
{
	for(j:=0; j<todo.ptr; j++)
		if(todo.q[j].cre == next)
			if(todo.q[j].beg <= tbeg)
			 	return k;
			else
				break;
	if(j < k)
		k--;
	if(j < todo.ptr)
		todo.ptr--;
	for( ; j<todo.ptr; j++)
		todo.q[j] = todo.q[j+1];
	todo.q[todo.ptr++] = Trace(next, tbeg);
	return k;
}

ASCII : con 128;
WORD : con 32;

member(char: int, set: ref Set): int
{
	if(char < 128)
		return ((set.ascii[char/WORD]>>char%WORD)&1)^set.neg;
	for(l:=set.unicode; l!=nil; l=tl l) {
		(beg, end) := hd l;
		if(char>=beg && char<=end)
			return !set.neg;
	}
	return set.neg;
}

newSet(s: ref ReStr): ref Set
{
	set := ref Set(0, array[ASCII/WORD] of {* => 0}, nil);
	if(s.peek() == '^') {
		set.neg = 1;
		s.next();
	}
	while(s.n > 0) {
		char1 := s.next();
		if(char1 == ']')
			return set;
		char1 = esc(s, char1);
		char2 := char1;
		if(s.peek() == '-') {
			s.next();
			char2 = s.next();
			if(char2 == ']')
				break;
			char2 = esc(s, char2);
			if(char2 < char1)
				break;
		}
		for( ; char1<=char2; char1++)
			if(char1 < ASCII)
				set.ascii[char1/WORD] |= 1<<char1%WORD;
			else {
				set.unicode = (char1,char2)::set.unicode;
				break;
			}
	}
	s.n = -1;
	return nil;
}
