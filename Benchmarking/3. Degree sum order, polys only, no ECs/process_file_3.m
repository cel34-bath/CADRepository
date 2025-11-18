#with(SMTLIB):
#with(StringTools):
#with(Logic):
#with(CodeTools):
QE := QuantifierElimination:
interface(prettyprint = 0):
iter := 10;
tlim := 240;

text := SMTLIB:-ParseFile(filename):
L := convert(QE:-QuantifierTools:-GetAllPolynomials(text), list):
read "../TimingsCommands.mpl";
vars := DegreeSumHeuristic(L):

rc_ordering := ListTools:-Reverse(vars):
print("RC");
rc_starttime := time[real]():
try
	tmp := timelimit(tlim,RegularChains:-SemiAlgebraicSetTools:-CylindricalAlgebraicDecompose(L,RegularChains:-PolynomialRing(rc_ordering),output = 'allcell',optimization = false)):
	RC_result := timelimit(tlim*iter,CodeTools:-Usage(RegularChains:-SemiAlgebraicSetTools:-CylindricalAlgebraicDecompose(L,RegularChains:-PolynomialRing(rc_ordering),output = 'allcell',optimization = false),output = 'all',quiet = false,iterations = iter)):
	rc_memory := RC_result[bytesused]:
	rc_cputime := RC_result[cputime]:
	rc_realtime := RC_result[realtime]:
	rc_cells := nops(RC_result[output]):
catch "time expired":
	RC_result := "TIME OUT":
	rc_memory := RC_result:
	rc_cputime := RC_result:
	rc_realtime := RC_result:
	rc_cells := RC_result:
catch:
    RC_result := cat("ERROR: ", lastexception[2]):
	rc_memory := RC_result:
	rc_cputime := RC_result:
	rc_realtime := RC_result:
	rc_cells := RC_result:
end try:
print("RC time taken");
time[real]() - rc_starttime;

qe_ordering := vars:
print("QE");
qe_starttime := time[real]():
try
	tmp := timelimit(tlim,QE:-CylindricalAlgebraicDecompose(L,variablestrategy = qe_ordering,propagateecs = false,useequations = none,usegroebner = false)):
    QE_result := timelimit(tlim*iter,CodeTools:-Usage(QE:-CylindricalAlgebraicDecompose(L,variablestrategy = qe_ordering,propagateecs = false,useequations = none,usegroebner = false),output = 'all',quiet = false,iterations = iter)):
	qe_memory := QE_result[bytesused]:
	qe_cputime := QE_result[cputime]:
	qe_realtime := QE_result[realtime]:
	qe_cells := QE:-CADData:-NumberOfLeafCells(QE_result[output]):
catch "time expired":
	QE_result := "TIME OUT":
	qe_memory := QE_result:
	qe_cputime := QE_result:
	qe_realtime := QE_result:
	qe_cells := QE_result:
catch:
	QE_result := cat("ERROR: ", lastexception[2]):
	qe_memory := QE_result:
	qe_cputime := QE_result:
	qe_realtime := QE_result:
	qe_cells := QE_result:
end try:
print("QE time taken");
time[real]() - qe_starttime;
#QE:-CADData:-PrintProjection(QE_result[output]):
#quit();