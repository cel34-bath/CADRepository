with(SMTLIB):
with(StringTools):
with(Logic):
with(CodeTools):
QE := QuantifierElimination:
interface(prettyprint = 0):
iter := 10;
tlim := 120;

text := SMTLIB:-ParseFile(filename);
L1 := convert(QE:-QuantifierTools:-GetAllPolynomials(text), list):
read "C:/Users/Corin Work/Documents/GitHub/CADStuff/MAPLE BENCHMARKING/Alicode/Batch Timings Runs/QEtoRC checks/QEtoRC.mpl";
L_QE := QE:-QuantifierTools:-ConvertToPrenexForm(text);
L_RC:=ToRCInput(L_QE);
vars := convert(indets(L1, name), list):

rc_ordering := RegularChains:-SuggestVariableOrder(L_RC,decomposition = cad):
try
	RC_result := timelimit(tlim*iter, Usage(RegularChains:-SemiAlgebraicSetTools:-CylindricalAlgebraicDecompose(L_RC,RegularChains:-PolynomialRing(rc_ordering),output = 'allcell',optimization = 'TTICAD'),output = 'all',quiet = false,iterations = iter)):
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
	rc_memory := RC_result[bytesused]:
	rc_cputime := RC_result[cputime]:
	rc_realtime := RC_result[realtime]:
	rc_cells := nops(RC_result[output]):
end try:
qe_ordering := tonks:
try
	QE_result := timelimit(tlim*iter, Usage(QE:-CylindricalAlgebraicDecompose(L_QE,variablestrategy = qe_ordering,propagateecs = true,useequations = 'multiple',usegroebner = true),output = 'all',quiet = false,iterations = iter)):
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
QE:-CADData:-PrintProjection(QE_result[output]):
#quit();