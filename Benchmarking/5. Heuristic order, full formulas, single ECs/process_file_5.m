#with(SMTLIB):
#with(StringTools):
with(Logic):
#with(CodeTools):
QE := QuantifierElimination:
interface(prettyprint = 0):
iter := 10;
tlim := 240;

text := SMTLIB:-ParseFile(filename):
L1 := convert(QE:-QuantifierTools:-GetAllPolynomials(text), list):
read "../TimingsCommands.mpl";
L2 := QE:-QuantifierTools:-ConvertToPrenexForm(text):
L2 := Normalize(L2, form = DNF):
L_QE := ConvertToPL(L2);
L_RC := ConvertToRC(L2);
vars := convert(indets(L1, name), list):

# moved internally (QE tonks is internal, so this makes it fairer, but still record it here for export.)
rc_ordering := RegularChains:-SuggestVariableOrder(L1,decomposition = cad):
print("RC");
rc_starttime := time[real]():
try
	tmp := timelimit(tlim,RegularChains:-SemiAlgebraicSetTools:-CylindricalAlgebraicDecompose(L_RC,RegularChains:-PolynomialRing(RegularChains:-SuggestVariableOrder(L1,decomposition = cad)),output = 'allcell',optimization = 'EC')):
	RC_result := timelimit(tlim*iter,CodeTools:-Usage(RegularChains:-SemiAlgebraicSetTools:-CylindricalAlgebraicDecompose(L_RC,RegularChains:-PolynomialRing(RegularChains:-SuggestVariableOrder(L1,decomposition = cad)),output = 'allcell',optimization = 'EC'),output = 'all',quiet = false,iterations = iter)):
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

qe_ordering := tonks:
print("QE");
qe_starttime := time[real]():
try
	tmp := timelimit(tlim,QE:-CylindricalAlgebraicDecompose(L_QE,variablestrategy = tonks,propagateecs = false,useequations = 'single',usegroebner = false)):
	QE_result := timelimit(tlim*iter,CodeTools:-Usage(QE:-CylindricalAlgebraicDecompose(L_QE,variablestrategy = tonks,propagateecs = false,useequations = 'single',usegroebner = false),output = 'all',quiet = false,iterations = iter)):
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
QE:-CADData:-PrintProjection(QE_result[output]):
#quit();