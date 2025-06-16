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
