#==========================================================
# TO DO:
# Turn this into a package, choose what to export and what not to export.
#==========================================================

# Final list of commands, indented not to be exported.

#PolyFactors
	#ScrubConstraints
	#RecursiveFlatten
	#CanonicalPoly
#PrepPolys
	#LazyDeroot
#BrownHeuristic
#GetCADOrdering
#LazardProjection
#RecursiveLazard
#GetProjPolysFromRC
#GetProjPolys
	#PLCAD
	#RCCAD
#MakeCAD
	#AndToList
	#PrepPLCAD
	#PLToFormat
	#RCToFormat
	#PrepCADCells
	#CountEqualities
	#GroupCellsByDim
	#Get2DPoints
	#RCMidpoint
	#RCSamplePoints
	#PLSamplePoints
	#GetCADSamplePoints
	#ForceInequal
	#GraphCells
#GraphFromCAD
#GraphCAD

#--- Shortlist

#PolyFactors
	# Returns irreducible basis for a set of polynomials.
#PrepPolys
	# Takes as input either a QuantifierElimination-amenable Tarski formula, a list, a set, or a single polynomial (constraint), and returns a list of polynomials without constraints.
#BrownHeuristic
	# 
#GetCADOrdering
#LazardProjection
#RecursiveLazard
#GetProjPolysFromRC
#GetProjPolys
#MakeCAD
#GraphFromCAD
#GraphCAD

# ---------------------------------------------------------
# General polynomial extraction functions.
# ---------------------------------------------------------

# For now, aim is simply to rip out the set of (unconstrained) polynomials (F) from the input.

#Returns an irreducible basis.
PolyFactors := proc(p)
	local pp, sf, fac, result, faclist;
	result := [];
	pp := p;
	if type(p, {list, set}) then
		pp := remove(type, {op(p)}, constant);
		pp := mul(pp);
	end if;
	sf := factor(PolynomialTools:-SquareFreePart(pp));
	faclist := [sf];
	if type(sf, `*`) then
		faclist := [op(sf)];
	end if;
	for fac in faclist do
		result := [op(result), fac];
	end do;
	return result;
end proc;

ScrubConstraints := proc(polyn)
	local p, scrubbed;
	scrubbed := polyn;
	if type(scrubbed, {list, set}) then
		scrubbed := map(p -> ScrubConstraints(p),scrubbed);
		if type(scrubbed, set) then
			scrubbed := convert(scrubbed, list);
		end if;
	end if;
	if type(scrubbed, 'relation') and member(op(0, scrubbed), {`=`, `<`, `<=`, `<>`}) then
		if lhs(scrubbed) - rhs(scrubbed) = 0 then
			return lhs(scrubbed);
		end if;
		return lhs(scrubbed) - rhs(scrubbed);
	end if;
	return scrubbed;
end proc;

RecursiveFlatten := proc(input)
	local res, e;
	res := [];
	if type(input, {list, set}) then
		for e in input do
			if type(e, list) or type(e, set) then
				res := [op(res), op(RecursiveFlatten(e))];
			else
				res := [op(res), e];
			end if;
		end do;
	else
		return [input];
	end if;
	return ListTools:-MakeUnique(res);
end proc;

CanonicalPoly := proc(p)
    local pp;
    pp := primpart(expand(p));
    if lcoeff(pp) < 0 then
        pp := -pp;
    end if;
    return pp;
end proc:

PrepPolys := proc(input,input2:=NULL)
	local polys, temp, p;
	if input2 <> NULL then
		WARNING("Please wrap inputs in a set or list to use multiple inputs.");
	end if;
	# if it's a Tarski formula, piggyback off QuantifierElimination to handle it.
	try
		temp := convert(QuantifierElimination:-QuantifierTools:-GetAllPolynomials(input), list);
		polys := ListTools:-MakeUnique(temp);
	catch:
		polys := NULL;
	end try;
	if polys = NULL then
		polys := ScrubConstraints(RecursiveFlatten(input));
		polys := ListTools:-MakeUnique(map(CanonicalPoly, polys));
	end if;
	return polys;
end proc;

#Had issues where nested roots (with range) could be read by pointplot but not anything else. Maybe pointplot does something like this.
LazyDeroot := proc(root)
	local rootrange;
	if type(root,{list,set}) then
		return map(LazyDeroot, root);
	elif op(0, root) = RootOf then
		rootrange := op(-1, root);
        if type(rootrange, range) then
            return (op(1,rootrange) + op(2,rootrange))/2;
        else
        	return root;
        end if;
	else
        return root;
	end if;
end proc;

# ---------------------------------------------------------
# General CAD methods.
# ---------------------------------------------------------

BrownHeuristic := proc(polys::list, {printorder::boolean:=false})
	local varlist, termmap, f, terms, v, i, var_deg, var_tdeg, var_terms, onlyterms, var_stats, s;
	varlist := convert(indets(polys), list);
	termmap := [];
	for f in polys do
		if type(expand(f), `+`) then
			terms := [op(expand(f))];
		else
			terms := [expand(f)];
		end if;
		termmap := [op(termmap), terms];
	end do;
	var_stats := [];
	for i to nops(varlist) do
		v := op(i, varlist);
		var_deg  := max(map(f -> degree(f, v), polys));
		onlyterms := map(f -> select(t -> has(t, v), f), termmap);
		var_tdeg := max(map(t -> degree(add(t)), onlyterms));
		var_terms := add(map(t -> nops(t), onlyterms));
		var_stats := [op(var_stats), [v, var_deg, var_tdeg, var_terms, i]];
	end do;
	var_stats := sort(var_stats, (a, b) ->
		if a[2] < b[2] then true
		elif a[2] > b[2] then false
		elif a[3] < b[3] then true
		elif a[3] > b[3] then false
		elif a[4] < b[4] then true
		elif a[4] > b[4] then false
		else a[5] > b[5]
		end if
	);
	var_stats := ListTools:-Reverse(var_stats); # want "best" variable the first one to project.
	if printorder then
		print(var_stats);
	end if;
	return [seq(s[1], s in var_stats)];
end proc;


# Gets an order based on BrownHeuristic, but if specified variables, they can be put somewhere separate.
GetCADOrdering := proc(polys::list, keep::list := [], {outputorder::symbol := 'increasing', position::symbol := 'bottom'})
	local P, vars, keepvars, keepinlist;
	P := polys;
	if not (outputorder in {'decreasing','increasing'}) then
		error "Incorrect outputorder: options are 'increasing' or 'decreasing'";
	end if;
	if not (position in {'bottom','top'}) then
		error "Incorrect position: options are 'bottom' or 'top'";
	end if;
	vars := BrownHeuristic(P);
	if nops(keep)>0 then
		keepvars := ListTools:-MakeUnique(keep);
		keepinlist := select(member, keepvars, vars);
		if keepinlist = [] then
			error "None of the specified variables appear in the polynomials!";
		elif nops(keepinlist)<nops(keepvars) then
			keepvars := keepinlist;
			WARNING("Not all variables supplied appear in polynomials. ");
		end if;
		# moves supplied variables to bottom, e.g. given [x,y,z], will provide order x<y<z<[others].
		if position='bottom' then
			vars:=[op(keepvars),op(remove(member, vars, keepvars))];
		# moves supplied variables to top, e.g. given [x,y,z], will provide order [others]<x<y<z).
		else #position='top'
			vars:=[op(remove(member, vars, keepvars)), op(keepvars)];
		end if;
	end if;
	if outputorder = 'decreasing' then
		return ListTools:-Reverse(vars);
	else # 'increasing'
		return vars;
	end if;
end proc;

# Couldn't extract projection polynomials from QuantifierTools, so I had to do it myself.
LazardProjection := proc(polys::list, var::symbol:=NULL)
	local factorset, with_var, without_var, result, i, j, p, v;
	if var = NULL then
		v := BrownHeuristic(polys)[-1];
		printf("Projecting with respect to %a", v);
	else
		v := var;
	end if;
	factorset := map(p -> op(PolyFactors(p)),polys);
	factorset := [op({op(factorset)})];
	with_var := select(p -> has(p, v), factorset);
	without_var := remove(p -> has(p, v), factorset);
	result := [];
	for i from 1 to nops(with_var) do
		#leading coefficient
		result := [op(result), coeff(with_var[i], v, degree(with_var[i], v))];
		#trailing coefficient
		result := [op(result), coeff(with_var[i], v, 0)];
		#discriminant
		result := [op(result), discrim(with_var[i], v)];
		#resultants
		if i < nops(with_var) then
			for j from i+1 to nops(with_var) do
				result := [op(result), resultant(with_var[i],with_var[j],v)];
			end do;
		end if;
	end do;
	result := PolyFactors([op(result), op(without_var)]);
	return result;
end proc;

# Recursively performs Lazard projections, down to the variables specified.
RecursiveLazard := proc(polys::list, keep::list := [], {varorder::symbol := 'increasing', varposition::symbol := 'bottom', fulllist::boolean := true, stopatvars::boolean := false})
	local P, keepvars, projorder, stopval, results;
	P := polys;
	projorder := GetCADOrdering(P,keep,outputorder=varorder,position=varposition);
	# confirming we have a unique list of polys to keep, in the right order.
	keepvars := select(member, projorder, ListTools:-MakeUnique(keep));
	if nops(keepvars)=0 then
		keepvars := [op(1,projorder)];
			if nops(keep)<>0 then
				WARNING("No specified variables exist in polynomials. Choosing one (%1).",op(keepvars));
			end if;
	end if;
	if fulllist then
		results := [P];
	end if;
	if stopatvars then
		stopval := nops(keepvars);
	else
		stopval := 1;
	end if;
	while nops(projorder) > stopval do
		P := LazardProjection(P,op(-1,projorder));
		projorder := projorder[1..-2];
		if fulllist then
			results := [P, op(results)];
		end if;
	end do;
	if fulllist then
		return results;
	else
		return P;
	end if;
end proc;

# For RegularChains, you can get a "projection" by producing a CCT, and extracting the final cylindrical system (n-variate list of "otherwise"s). The kth element is the product of level k projection polynomials.
GetProjPolysFromRC := proc(polys::list, keep::list := [], {varorder::symbol := 'increasing', varposition::symbol := 'bottom', CD::name := NULL})
	local P, projorder, keepvars, R, CCD, projpolys;
	P := polys;
	# keeping RC ordering here!
	projorder := GetCADOrdering(P,keep,outputorder=varorder,position=varposition);
	keepvars := select(member, projorder, ListTools:-MakeUnique(keep));
	R := RegularChains:-PolynomialRing(ListTools:-Reverse(projorder));
	CCD := RegularChains:-ConstructibleSetTools:-CylindricalDecompose(P, R);
	if CD <> NULL then
		assign(CD = CCD);
	end if;
	# Final cylindrical system corresponds to "otherwise" i.e. list of products of other polynomials at that level.
	projpolys := (RegularChains:-Info(CCD, R))[-1][-1];
	# Separate out into factors
	projpolys := map(PolyFactors, projpolys);
	return projpolys;
end proc;

# So! I can now get a set of projection polynomials from an input.
# RecursiveLazard(polys,keep,order,position)
# GetProjPolysFromRC(polys,keep,order,position)

GetProjPolys := proc(polys::list, keep::list := [], {order::symbol := 'increasing', method::symbol := 'PL', position::symbol := 'bottom', level::anything := NULL})
	local projpolys;
	if method = 'PL' then
		projpolys := RecursiveLazard(polys, keep, varorder=order, varposition=position); 
	elif method = 'RC' then
		projpolys := GetProjPolysFromRC(polys, keep, varorder=order, varposition=position);
	else
		error "Incorrect method: options are 'PL' or 'RC'";
	end if;
	if level <> NULL then
		if type(level, integer) and 1 <= level and level <= nops(projpolys) then
			projpolys := op(level, projpolys);
		else
			WARNING("Specified level %1 is out of bounds (1..%2). Returning full collection.", level, nops(projpolys));
		end if;
	end if;
	return projpolys;
end proc;

# Hooray! I can now just directly get the 2D CAD polys in either style!
# GetProjPolys(polys,keep,order,method,position,level = 2)

# ---------------------------------------------------------
# Actual CAD construction
# ---------------------------------------------------------

# need base commands for doing the PL CAD or RC CAD on an appropriate input
# a command for linking to either depends on the format you want.
# then wrap this at top level maybe to do "tidy polys, get order, project to 2d, then make the CAD"

# so first part: assuming I have  a set of 2D polys, and a supplied order. Probably best to 

# Command for getting a CAD via PL or RC.

# Assume for now input is a list of polys


PLCAD := proc(polys::list, vars::list := [], {varorder::symbol := 'increasing', varposition::symbol := 'bottom'})
	local projorder;
	projorder := GetCADOrdering(polys,vars,outputorder=varorder,position=varposition);
	return QuantifierElimination:-CylindricalAlgebraicDecompose(polys, propagateecs = false, variablestrategy = projorder, useequations = none, usegroebner = false);
end proc;

# Need to come back and check this Reverse is in the right place.
RCCAD := proc(polys::list, vars::list := [], {varorder::symbol := 'increasing', varposition::symbol := 'bottom', outputtype::symbol := rootof})
	local projorder, R;
	projorder := ListTools:-Reverse(GetCADOrdering(polys,vars,outputorder=varorder,position=varposition));
	R := RegularChains:-PolynomialRing(projorder);
	return RegularChains:-SemiAlgebraicSetTools:-CylindricalAlgebraicDecompose(polys, R, optimization='false', output = outputtype);
end proc;

MakeCAD := proc(polys::list, vars::list := [], {method::name:=NULL}, {order::symbol := 'increasing', position::symbol := 'bottom', RCoutputtype::symbol := rootof})
	if method = 'PL' then
		return PLCAD(polys, vars, varorder=order, varposition=position);
	elif method = 'RC' then
		return RCCAD(polys, vars, varorder=order, varposition=position, outputtype=RCoutputtype);
	else
		error "Incorrect method: options are 'PL' or 'RC'";
	end if;
end proc;


# Now need a "Make CAD at level
# Want it to prep the polys, make an order, project to specified level, then make the CAD.
# also for opencad argument - will probably just have to get it during cell splitting.

# DEFINITELY WANT RCCAD output=rootof AND NOT INFO.

# ---------------------------------------------------------
# Formatting outputs
# ---------------------------------------------------------

# Need to get the cell list as output, but format is different for each one.

#Converts nested And to list.
AndToList := proc(expr)
	local e, outputlist;
	outputlist := [];
	if op(0, expr) = And then
		for e in [op(expr)] do
			outputlist := [op(outputlist), op(AndToList(e))];
		end do;
	else
		outputlist := [expr];
	end if;
	return outputlist;
end proc;

PrepPLCAD := proc(inputcad)
	local leaves, i;
	leaves := QuantifierElimination:-CADData:-GetLeafCells(inputcad);
	return [seq(GetFullDescription(leaves[i]), i = nops(leaves) .. 1, -1)];
end proc;

#PL cell list is a list of elements, each element a conjunction of constraints representing a cell, with nothing for "any x".
PLToFormat := proc(cell_list::list)
	local cellmap, cell;
	cellmap := map(cell -> AndToList(cell),cell_list);
	return cellmap;
	#return map(cell -> FillMissingVars(cell,[op(indets(cellmap, name))]),cellmap);
end proc;

#RC cell list is a list of sublists, each sublist a list of constraints, including "x=x" for "any x".
RCToFormat := proc(cell_list::list)
	local cell, c;
	return map(cell -> select(c -> not(type(c, `=`) and lhs(c)=rhs(c)), cell),cell_list);
end proc;

PrepCADCells := proc(inputcad,{method::name:=NULL})
	local methodname, prep;
	if type(inputcad, QuantifierElimination:-CADData) then
		methodname := 'PL';
	elif type(inputcad, list) then
		if andmap(e -> type(e, list), inputcad) then
			methodname := 'RC';
		elif not ormap(e -> type(e, list), inputcad) then
			methodname := 'PL';
		end if;
	end if;
	if method <> NULL and methodname <> NULL and methodname <> method then
		WARNING("Detected method %1 does not match specified method %2, using detected one. ", methodname, method);
	elif method = NULL and methodname <> NULL then
		printf("Detected method: %a. ", methodname);
	elif method <> NULL then
		methodname := method;
	end if;
	if methodname = 'PL' then
		if type(inputcad, QuantifierElimination:-CADData) then
			prep := PrepPLCAD(inputcad);
			return PLToFormat(prep);
		elif type(inputcad, list) then
			return PLToFormat(inputcad);
		end if;
	elif methodname = 'RC' then
		return RCToFormat(inputcad);
	else
		error "Incorrect method: options are 'PL' or 'RC'";
	end if;
end proc;

# you have to use output=rootof for the RC output.

# ---------------------------------------------------------
# Cell dimension separation
# ---------------------------------------------------------

# Input is a list of elements separated by commas. So RC cell output is fine, (if it's got an AND in it it won't have an equation), and PL is fine after using AndToList.

CountEqualities := proc(constlist::list)
	return nops(select(t -> type(t, `=`), constlist));
end proc;

# For every sublist (cell) in list (CAD), check the value of CountEqualities(sublist) (0<=k<=n) and put it in that bucket.

GroupCellsByDim := proc(cell_list::list)
	local countmap, s, n, bucket, i, j, k;

	countmap := map(s -> CountEqualities(s), cell_list);
	n := nops(indets(cell_list, name));

	bucket := table();
	for i from 0 to n do
		bucket[i] := [];
	end do;
	for j from 1 to nops(cell_list) do
		k:=countmap[j];
		bucket[k] := [op(bucket[k]),cell_list[j]];
	end do;
	#return list of cells in decreasing dimension.
	return [seq(bucket[i], i=0..n)];
end proc;

# Input: list of lists, each containing 2 equations.
Get2DPoints := proc(pointslist::list, vars::list:=[op(indets(pointslist,name))])
	local indetlist, cleanedlist, sides, sidesindets, sidesvals, i, s, listtemp;
	if ListTools:-MakeUnique(map(t -> nops(t), pointslist)) <> [2] then
		error "Expecting list of paired equations.";
	end if;
	listtemp := pointslist;
    sides := map(s -> map(t -> op(t), s), pointslist);
    sidesindets := map(s -> select(t -> type(t, name), s), sides);
    sidesvals := map(s -> remove(t -> type(t, name), s), sides);
	if nops(ListTools:-MakeUnique(vars))>=2 then
		indetlist := [op(1..2,vars)];
	else
		indetlist := [op(1..2,RecursiveFlatten(sidesindets))];
		if nops(indetlist) < 2 then
            error "Could not determine 2 distinct variables.";
        end if;
	end if;
	cleanedlist := [];
	for i from 1 to nops(sidesindets) do
    	if op(i,sidesindets) = indetlist then
        	cleanedlist := [op(cleanedlist), op(i,sidesvals)];
    	elif op(i,sidesindets) = ListTools:-Reverse(indetlist) then
    		cleanedlist := [op(cleanedlist), ListTools:-Reverse(op(i,sidesvals))];
		else
			error "Variable list error at point %1", op(i, pointslist);
		end if;
	end do;
	cleanedlist := LazyDeroot(cleanedlist);
    return cleanedlist;
end proc;

RCMidpoint := proc(val)
    if type(val, list) and nops(val)=2 then
        return (val[1] + val[2]) / 2;
    else
        return val;
    end if;
end proc;

RCSamplePoints := proc(polys::list, vars::list := [], {varorder::symbol := 'increasing', varposition::symbol := 'bottom'})
	local R, RCCADOut, cellmap;
	R:=RegularChains:-PolynomialRing(ListTools:-Reverse(vars));
	RCCADOut := MakeCAD(polys, vars, method=RC, order=varorder, position=varposition, RCoutputtype=cadcell);
	cellmap := map(s -> RegularChains:-SamplePoints(s, R), RCCADOut);
	cellmap := map(s -> op(RegularChains:-Info(s, R))[1], cellmap);
    return map(pair -> map(m -> lhs(m) = RCMidpoint(rhs(m)),pair), cellmap);
end proc;

PLSamplePoints := proc(polys::list, vars::list := [], {varorder::symbol := 'increasing', varposition::symbol := 'bottom'})
	local PLCADOut, cellmap;
	PLCADOut := MakeCAD(polys, vars, method=PL, order=varorder, position=varposition);
	cellmap := map(s -> GetSamplePoint(s), GetLeafCells(PLCADOut));
	return cellmap;
end proc;

GetCADSamplePoints := proc(polys::list, vars::list := [], {method::name:=NULL}, {order::symbol := 'increasing', position::symbol := 'bottom'})
	if method = 'RC' then
		return Get2DPoints(RCSamplePoints(polys,vars,varorder=order,varposition=position),vars);
	elif method = 'PL' then
		return Get2DPoints(PLSamplePoints(polys,vars,varorder=order,varposition=position),vars);
	else
		error "Incorrect method: options are 'PL' or 'RC'";
	end if;
end proc;

# Sometimes 1-cells can be of type [y=f(x)] (i.e. x anything)
# this forces it to [y=f(x), infinity<x<infinity] so inequal behaves.
ForceInequal := proc(inputonecells::list, vars::list)
	local onecells, getindet, remlist, v, cell, tempcell;
	onecells := [];
	for cell in inputonecells do
		tempcell := cell;
		if nops(cell) = 1 and type(op(tempcell), equation) then
			# enough to handle cases like [x-y]: higher var is on the lhs anyway.
			if member(lhs(op(tempcell)), indets(tempcell, name)) then
				getindet := lhs(op(tempcell));
			elif member(rhs(op(tempcell)), indets(tempcell, name)) then
				getindet := rhs(op(tempcell));
			end if;
			#expecting only 2 vars anyway, but for the future.
			remlist := remove(v -> v = getindet, vars);
			for v in remlist do
				tempcell := [op(tempcell), -infinity < v, v < infinity];
			end do;
		end if;
		onecells := [op(onecells), tempcell];
	end do;
	return onecells;
end proc;

# ---------------------------------------------------------
# actual graphing!
# ---------------------------------------------------------

# now is where I would do opencad test: Would want to keep only the first sublist.

#Will make a lot of assumptions for now: it's 2d, the lower var is the x-axis, upper is y-axis.

#Just assuming getting two vars in right order here.
GraphCells := proc(cellslist::list, vars::list, {x_range::range := -1..1, y_range::range := -1..1, onedplotopt::boolean := false})
	local tempvars, my_colours, axisvars, cellstemp, B1, B2, B3, B4, B5, i, PointList, Proj1DList, xlist, ylist, rangemin_x, rangemax_x, rangemin_y, rangemax_y, twocellstemp, onecellstemp, cellstemptwo, ordfromcad;
	if nops(vars)<2 then
		tempvars := [op(indets(cellslist, name))];
		printf("No vars supplied, choosing %a. ",tempvars);
	else
		tempvars := vars;
	end if;
    my_colours := ["MistyRose", "Salmon", "CornflowerBlue", "LightGoldenrod", "LightGreen", "Plum", "SandyBrown", "SkyBlue", "MediumPurple", "MediumAquamarine"];
	#was IndianRed
	axisvars:=tempvars;
	cellstemp := cellslist;
	if cellstemp = [] then
		cellstemp := [[],[],[]];
	end if;
	if cellstemp[3]=[] then
		B3 := NULL;
		rangemin_x := op(1, x_range);
		rangemax_x := op(2, x_range);
		rangemin_y := op(1, y_range);
		rangemax_y := op(2, y_range);
	else
		PointList := Get2DPoints(cellstemp[3], axisvars);
		# get adaptive scaling
		xlist := map(p -> p[1], PointList);
		ylist := map(p -> p[2], PointList);
		rangemin_x := (11/10)*min(xlist)-(1/10)*max(xlist);
		rangemax_x := (11/10)*max(xlist)-(1/10)*min(xlist);
		rangemin_y := (11/10)*min(ylist)-(1/10)*max(ylist);
		rangemax_y := (11/10)*max(ylist)-(1/10)*min(ylist);
		#print(rangemin_x,rangemax_x,rangemin_y,rangemax_y);
		# always display every significant point at minimum.
		rangemin_x := min(rangemin_x,op(1, x_range));
		rangemax_x := max(rangemax_x,op(2, x_range));
		rangemin_y := min(rangemin_y,op(1, y_range));
		rangemax_y := max(rangemax_y,op(2, y_range));
		
		# 0D points (red diamonds)
		B3 := plots:-pointplot(PointList,
		color="Red", symbolsize=20, symbol=soliddiamond);
	end if;
	
	# 2D full-dimensional cells (in colour)
	if cellstemp[1] = [] and (cellstemp[2] <> [] or cellstemp[3] <> []) then
		B1 := NULL;
	elif cellstemp[1] = [] then
		B1 := [plots:-inequal([rangemin_x < axisvars[1], axisvars[1] < rangemax_x, rangemin_y < axisvars[2], axisvars[2] < rangemax_y],
			axisvars[1] = rangemin_x..rangemax_x,
			axisvars[2] = rangemin_y..rangemax_y,
			color = my_colours[1 + 1])];
	else
		twocellstemp:=cellstemp[1];
		twocellstemp:=ForceInequal(twocellstemp,tempvars);
		B1 := [seq(plots:-inequal(twocellstemp[i],
			axisvars[1] = rangemin_x..rangemax_x,
			axisvars[2] = rangemin_y..rangemax_y,
			color = my_colours[(i mod nops(my_colours)) + 1]),
		i=1..nops(twocellstemp))];
	end if;
	# 1D boundary cells (black lines)
	if cellstemp[2] = [] then
		B2 := NULL;
	else
		onecellstemp:=cellstemp[2];
		onecellstemp:=ForceInequal(onecellstemp,tempvars);
		B2 := [seq(plots:-inequal(onecellstemp[i],
			axisvars[1] = rangemin_x..rangemax_x,
			axisvars[2] = rangemin_y..rangemax_y,
			color = "Black"),
		i=1..nops(onecellstemp))];
	end if;

	if onedplotopt then
		# 1D projection
		if cellstemp[3]=[] then
			B4 := NULL;
		else
			cellstemptwo := select(p -> nops(p) = 2, map(l -> op(l), cellstemp));
			ordfromcad := map(s -> op(s), RecursiveFlatten(cellstemptwo));
			ordfromcad := ListTools:-MakeUnique(select(s -> type(s, name), ordfromcad));

		
			if op(1,ordfromcad)=op(1,tempvars) and op(2,ordfromcad)=op(2,tempvars) then
				Proj1DList := ListTools:-MakeUnique(map(t -> [op(1, t),(11/10)*rangemin_y-(1/10)*rangemax_y], PointList));
				B4 := plots:-pointplot(Proj1DList,
				color="Red", symbolsize=20, symbol=diamond);
				B5 := plot((11/10)*rangemin_y-(1/10)*rangemax_y, axisvars[1] = rangemin_x..rangemax_x, color = "Black", thickness = 2);
				
				plots:-display(B1, B2, B3, B5, B4, size=[1/3,11/10]);
			elif op(1,ordfromcad)=op(2,tempvars) and op(2,ordfromcad)=op(1,tempvars) then
				Proj1DList := ListTools:-MakeUnique(map(t -> [(11/10)*rangemin_x-(1/10)*rangemax_x,op(2, t)], PointList));
				B4 := plots:-pointplot(Proj1DList,
				color="Red", symbolsize=20, symbol=diamond);
				B5 := 
				plot([((11/10)*rangemin_x-(1/10)*rangemax_x),t,t=rangemin_y..rangemax_y], color = "Black", thickness = 2);
				plots:-display(B1, B2, B3, B5, B4, size=[11/30,10/11]);
			else error "Can't match up variable for 1D projection (%l and %l)",ordfromcad, tempvars;
			end if;
		end if;

	else
		plots:-display(B1, B2, B3, size=[1/3,1]);
	end if;
end proc;

# Now I need to work backwards: get this from a CAD, then from a poly.
#GraphCells <-- GroupCellsByDim <-- PrepCADCels <-- MakeCAD

# makes a CAD graph from a CAD.
GraphFromCAD := proc(CAD, CADvars::list, {xrange::range := -1..1, yrange::range := -1..1, onedplot::boolean := false})
	local G, GGraph;
	G := GroupCellsByDim(PrepCADCells(CAD));
	GGraph := GraphCells(G, CADvars, x_range=xrange, y_range=yrange, onedplotopt=onedplot);
end proc;

# makes a CAD graph from polys.

GraphCAD := proc(polys::list, {varorder::list := [], displayorder::list := [], CADmethod::name:=NULL, xrange::range := -1..1, yrange::range := -1..1, onedplot::boolean := false, opencad::boolean := false, samplepoints::boolean := false})
	local temppolys, tempvarorder, tempdisplayorder, CAD, SP, G, xlist, ylist, rangemin_x, rangemax_x, rangemin_y, rangemax_y, B6, GGraph, B7, Proj1DSample;
	
	if CADmethod <> 'PL' and CADmethod <> 'RC' then
		error "Incorrect CADmethod: options are 'PL' or 'RC'";
	elif CADmethod = 'PL' or CADmethod = 'RC' then
			tempvarorder := varorder;
			tempdisplayorder := displayorder;
		if nops(indets(polys,name))>2 then
			temppolys := GetProjPolys(polys,varorder,method=CADmethod,level = 2);
			tempvarorder := GetCADOrdering(temppolys,tempvarorder);
			tempdisplayorder := GetCADOrdering(temppolys,displayorder);
			WARNING("Input polynomials have more than two variables",indets(polys,name));
			WARNING("Using 2D projection polynomials",temppolys);
		else
			temppolys := polys;
		end if;
		if nops(tempvarorder)<2 then
			tempvarorder := GetCADOrdering(temppolys,tempvarorder);
			printf("Insufficient varorder supplied, choosing %a. ",tempvarorder);
		end if;
		if nops(tempdisplayorder)<2 then
			tempdisplayorder := GetCADOrdering(temppolys,tempdisplayorder);
			printf("Insufficient displayorder supplied, choosing %a. ",tempdisplayorder);
		end if;
		CAD := MakeCAD(temppolys, tempvarorder, method=CADmethod);
		SP := GetCADSamplePoints(temppolys, tempvarorder, method=CADmethod);
		G := GroupCellsByDim(PrepCADCells(CAD));
	end if;
	if opencad then
		G := [op(1,G),[],[]];
	end if;
	if samplepoints then
		# doesn't work with opencad really, but oh well.
		# Adaptive scaling based on sample points
		xlist := map(p -> p[1], SP);
		ylist := map(p -> p[2], SP);
		rangemin_x := (11/10)*min(xlist)-(1/10)*max(xlist);
		rangemax_x := (11/10)*max(xlist)-(1/10)*min(xlist);
		rangemin_y := (11/10)*min(ylist)-(1/10)*max(ylist);
		rangemax_y := (11/10)*max(ylist)-(1/10)*min(ylist);
		# always display every significant point at minimum.
		rangemin_x := min(rangemin_x,op(1, xrange));
		rangemax_x := max(rangemax_x,op(2, xrange));
		rangemin_y := min(rangemin_y,op(1, yrange));
		rangemax_y := max(rangemax_y,op(2, yrange));
		# Sample points (black crosses)
		B6 := plots:-pointplot(SP,
		color="Black", symbolsize=20, symbol=diagonalcross,
        annotation=typeset("(", 'xcoordinate', ",", 'ycoordinate', ")"));
	else
		B6 := NULL;
		rangemin_x := op(1, xrange);
		rangemax_x := op(2, xrange);
		rangemin_y := op(1, yrange);
		rangemax_y := op(2, yrange);
	end if;
    # Call GraphCells with the computed ranges
	# print(G, tempdisplayorder, "x_range=",rangemin_x..rangemax_x, "y_range=",rangemin_y..rangemax_y, "onedplotopt=",onedplot);
	GGraph := GraphCells(G, tempdisplayorder, x_range=rangemin_x..rangemax_x, y_range=rangemin_y..rangemax_y, onedplotopt=onedplot):
	if onedplot then
		if SP = [] then
			B7 := NULL;
		else
			Proj1DSample := ListTools:-MakeUnique(map(t -> [op(1, t),(11/10)*rangemin_y-(1/10)*rangemax_y], SP));
			B7 := plots:-pointplot(Proj1DSample,
				color="Black", symbolsize=10, symbol=diagonalcross);
		end if;
	else
		B7 := NULL;
	end if;
	return plots:-display(GGraph,B6,B7);
end proc;

#-------------------------------------------

# NEXT:
	# Tidy it all, sort this package.
	# make it a proper package which exports only certain commands
	# write up a description of everything.

# Future work:
	# argument for "assign the CAD to a name", and "assign the 2d proj polys to a name"
	# argument for output time taken, and number of cells to create.
	# Get 1D plot.
	# next time - add bydimension colouring and "pick a colour" colouring which returns it in like 6 shades