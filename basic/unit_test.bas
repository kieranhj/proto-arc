MODE 0
precision=65536
err_delta=1/256
:
DIM code 65536
OSCLI "LOAD <Test$Dir>.CodeLib "+STR$~(code)
dot_product=code+0
dot_product_unit=code+4
matrix_multiply_vector=code+8
unit_matrix_multiply_vector=code+12
sine=code+16
cosine=code+20
:
PROCtest_sine
REPEAT UNTIL GET
PROCtest_dot_product
END
:
DEF PROCtest_dot_product
CLS:PRINT"Running dot product tests."
num_dp_tests=18:data_dp_tests=60
:
DIM vec1 12, vec2 12
RESTORE data_dp_tests
failed=0
FOR I%=1 TO num_dp_tests
READ a,b,c,d,e,f
PROCmake_vec(vec1, a, b, c):PROCprintf_vec("vec1",vec1)
PROCmake_vec(vec2, d, e, f):PROCprintf_vec("vec2",vec2)
result=FNfp_to_float(FNdot_product(vec1, vec2))
verify=FNtest_dot_product(vec1, vec2)
error=ABS(verify-result)
PRINT ;"dot product=";result;" verify=";verify;" ";
IF error<err_delta PRINT "PASS" ELSE PRINT "FAIL error=";error:failed=failed+1
NEXT
PRINT (num_dp_tests-failed);"/";num_dp_tests;" tests PASSED."
ENDPROC
:
DEF FNfloat_to_fp(v)
=INT(v*precision)
DEF FNfp_to_float(fp)
=fp/precision
:
DEF PROCmake_vec(vec, x, y, z)
vec!0=FNfloat_to_fp(x):vec!4=FNfloat_to_fp(y):vec!8=FNfloat_to_fp(z)
ENDPROC
DEF PROCprintx_vec(name$,vec)
PRINT name$;"=[";~vec!0;",";~vec!4;",";~vec!8;"] ";
ENDPROC
DEF PROCprintf_vec(name$,vec)
PRINT name$;"=[";FNfp_to_float(vec!0);",";FNfp_to_float(vec!4);",";FNfp_to_float(vec!8);"] ";
ENDPROC
:
DEF FNdot_product(B%, C%)
=USR(dot_product)
DEF FNtest_dot_product(B%, C%)
a=FNfp_to_float(B%!0):b=FNfp_to_float(B%!4):c=FNfp_to_float(B%!8)
d=FNfp_to_float(C%!0):e=FNfp_to_float(C%!4):f=FNfp_to_float(C%!8)
=a*d+b*e+c*f
:
: REM Unit vectors.
DATA 3.0, 4.0, 5.0,  1.0, 0.0, 0.0
DATA 3.0, 4.0, 5.0,  0.0, 1.0, 0.0
DATA 3.0, 4.0, 5.0,  0.0, 0.0, 1.0
: REM Zero vectors.
DATA 3.0, 4.0, 5.0,  0.0, 0.0, 0.0
DATA 0.0, 0.0, 0.0,  100.0, 200.0, 300.0
: REM Orthogonal vectors.
DATA 10.0, 0.0, 0.0,  0.0, 20.0, 0.0
DATA 0.0, 20.0, 0.0,  0.0, 0.0, 30.0
DATA 0.0, 0.0, 30.0,  10.0, 0.0, 0.0
: REM Negative vectors.
DATA 10.0, 0.0, 0.0,  -1.0, 0.0, 0.0
DATA 100.0, 200.0, 300.0,  -1.0, -1.0, -1.0
DATA 100.0, 200.0, 300.0,  -1.0, -1.0, 1.0
DATA -100.0, -200.0, -300.0,  -1.0, -1.0, -1.0
: REM Precision tests.
DATA 255.9, 0.0, 0.0,  1.0, 0.0, 0.0
DATA 0.0, 255.9, 0.0,  0.0, -1.0, 0.0
DATA 0.0, 0.0, -256,    0.0, 0.0, 1.0
DATA -256.0, 0.0, 0.0,  -1.0, 0.0, 0.0
DATA 50.0, 100.0, 200.0, 0.1, 0.2, 0.3
DATA -200.0, 100.0, -500.0,  0.99, -0.99, 0.99
:
DEF PROCtest_sine
failed=0
FOR degs=0 TO 360 STEP 10
rad=degs/360:verify_cos=COS(RAD(degs)):verify_sin=SIN(RAD(degs))
A%=FNfloat_to_fp(rad)
s=FNfp_to_float(USR(sine)):c=FNfp_to_float(USR(cosine))
PRINT "deg=";degs;" rad=";rad;" rad_fp=";A%;" s=";s;" c=";c;" sin=";verify_sin;" cos=";verify_cos;" ";
error=ABS(s-verify_sin)
IF error<err_delta PRINT "PASS" ELSE PRINT "FAIL error=";error:failed=failed+1
NEXT
PRINT failed;" tests FAILED."
ENDPROC
