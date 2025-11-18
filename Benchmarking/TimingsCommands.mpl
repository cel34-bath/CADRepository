with(Logic):
ToRCInput := proc(F)
	local L, i, j;
	L := Logic:-Normalize(F, form = DNF);
	# Make into a list if not
	if type(L, set) then
		return ToRCInput(convert(L, list));
	elif not type(L, list) then
		return ToRCInput([L]);
	end if;
	# Process each element
		for i to nops(L) do
			if type(op(i,L),set) then
				L := subsop(i = ToRCInput(convert(op(i, L), list)), L);
			elif type(op(i, L), list) then
				if nops(op(i, L)) = 1 and type(op(1, op(i, L)), list) then
					L := subsop(i = op(1, op(i, L)), L); # if a list contains only another list, flatten
				end if;
				L := subsop(i = ToRCInput(op(i, L)), L);
			elif member(op(0, op(i,L)), {`&and`, `and`, `And`}) then
				L := subsop(i = ToRCInput([op(op(i,L))]),L); #replace that term with its elements in a list, call again to do recursively?
			elif member(op(0, op(i,L)), {`&or`, `or`, `Or`}) then
				L := ToRCInput([op(1 .. i - 1, L), seq([op(j, op(i,L))], j = 1 .. nops(op(i,L))), op(i + 1 .. nops(L), L)]); #replace that term with its elements in separate lists, call again to do recursively?	
			elif member(op(0, op(i,L)), {`&not`, `not`, `Not`}) then
				error "Unexpected &not in DNF: %1", op(i, L);
		end if; # otherwise do nothing
	end do;
	if nops(L) = 1 and type(op(1, L), list) then
		L := op(1, L); #` final check, if L is a list containing only a list, flatten.`
	end if;
	return L;
end proc:

DegreeSumHeuristic := proc(P::{list, algebraic}, {fulldetail::boolean := false})
	local vlist, v, L, f, i;
	vlist := indets(P, name);
	if type(P, list) and nops(P) <> 1 then
		L := [seq([vlist[i], i, add(degree(f, vlist[i]), f in P)], i = 1..nops(vlist))];
	elif type(P, list) and nops(P) = 1 then
		L := [seq([vlist[i], i, degree(op(P), vlist[i])], i = 1..nops(vlist))];
	else 
		L := [seq([vlist[i], i, degree(P, vlist[i])], i = 1..nops(vlist))];
	end if;
	# lowest degree sum is rightmost, ties broken alphabetically
	L := sort(L, (a, b) ->
		if a[3] > b[3] then true
		elif a[3] < b[3] then false
		elif a[2] < b[2] then true
		end if
	);
	if fulldetail then
		return L;
	else
		return map(v -> v[1],L);
	end if;	
end proc:

	#L := Logic:-Normalize(QuantifierElimination:-QuantifierTools:-ConvertToPrenexForm(F), form = DNF);

ConvertToPL := proc(F)
	local junction;
	if op(0, F) in {`&or`, Logic:-`&or`} then
		junction := map(ConvertToPL, [op(F)]);
		return apply(Or, op(junction));
	elif op(0, F) in {`&and`, Logic:-`&and`} then
		junction := map(ConvertToPL, [op(F)]);
		return apply(And, op(junction));
	else
		return F;
	end if;
end proc:

ConvertToRCInner := proc(F)
	local junction;
	if op(0, F) in {`&or`, Logic:-`&or`, `or`, `Or`} then
		junction := map(ConvertToRCInner, [op(F)]);
		return op(junction);
	elif op(0, F) in {`&and`, Logic:-`&and`, `and`, `And`} then
		junction := map(ConvertToRCInner, [op(F)]);
		return junction;
	else
		return F;
	end if;
end proc:

ConvertToRC := proc(F)
	local L;
	L := [ConvertToRCInner(F)];
	#if op(0,L)<>list then
	#	return [L];
	if nops(L) = 1 and type(op(1, L), list) then
		return op(L);
	else
		return L;
	end if;
end proc: