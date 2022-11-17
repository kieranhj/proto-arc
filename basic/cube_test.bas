MODE 9
precision=65536
:
DIM code 65536
OSCLI "LOAD <Test$Dir>.CodeLib "+STR$~(code)
dot_product=code+0
matrix_multiply_vector=code+4
matrix_multiply=code+8
sine=code+12
cosine=code+16
make_rotate_x=code+20
make_rotate_y=code+24
make_rotate_z=code+28
make_identity=code+32
divide=code+36
:
cx=0:cy=0:cz=-160
ox=0:oy=0:oz=64
vdu_scale=4:vp_scale=160*vdu_scale
vp_centre_x=160*vdu_scale:vp_centre_y=128*vdu_scale
:
vec_size=12
num_verts=8
num_faces=6
DIM obj_verts num_verts*vec_size
DIM obj_faces num_faces*4
DIM rot_matrix 9*4
DIM rot_verts num_verts*vec_size
:
PROCmake_cube(num_verts,obj_verts)
REPEAT UNTIL GET
:
angle=0
:
REPEAT
*FX19
CLS
:
A%=FNfloat_to_fp(angle):C%=rot_matrix:CALL make_rotate_y
PROCprintf_matrix(rot_matrix)
PROCrotate_verts(num_verts, obj_verts, rot_verts, rot_matrix)
PROCplot_verts(num_verts, rot_verts)
:
: REM REPEAT UNTIL GET
angle=(angle+1) MOD 256
:
UNTIL FALSE
END
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
DEF PROCprintf_matrix(mat)
PRINT "[";FNfp_to_float(mat!0);",";FNfp_to_float(mat!4);",";FNfp_to_float(mat!8);"]"
PRINT "[";FNfp_to_float(mat!12);",";FNfp_to_float(mat!16);",";FNfp_to_float(mat!20);"]"
PRINT "[";FNfp_to_float(mat!24);",";FNfp_to_float(mat!28);",";FNfp_to_float(mat!32);"]"
ENDPROC
:
DEF PROCmake_cube(num_verts, vert_buf)
FOR I%=0 TO num_verts-1
vp=vert_buf+I%*vec_size
READ x, y, z
PROCmake_vec(vp, x, y, z)
PROCprintf_vec(STR$(I%),vp):PRINT
NEXT
ENDPROC
:
: REM Vertices
DATA -64.0,  64.0, -64.0
DATA  64.0,  64.0, -64.0
DATA  64.0, -64.0, -64.0
DATA -64.0, -64.0, -64.0
DATA -64.0,  64.0,  64.0
DATA  64.0,  64.0,  64.0
DATA  64.0, -64.0,  64.0
DATA -64.0, -64.0,  64.0
:
: REM Faces
DATA 0, 1, 2, 3
DATA 1, 5, 6, 2
DATA 5, 4, 7, 6
DATA 4, 0, 3, 7
DATA 0, 4, 5, 1
DATA 2, 3, 7, 6
:
: REM Normals
DATA  0.0,  0.0, -1.0
DATA  1.0,  0.0,  0.0
DATA  0.0,  0.0,  1.0
DATA -1.0,  0.0,  0.0
DATA  0.0,  1.0,  0.0
DATA  0.0  -1.0,  0.0
:
DEF PROCrotate_verts(N%, in_verts, out_verts, matrix)
FOR I%=0 TO N%-1
A%=matrix:B%=in_verts+I%*vec_size:C%=out_verts+I%*vec_size
:REM PROCprintf_vec(STR$(I%),B%)
CALL matrix_multiply_vector
:REM PROCprintf_vec("rot",C%):PRINT
NEXT
ENDPROC
:
DEF PROCplot_verts(N%, verts)
FOR I%=0 TO N%-1
vp=verts+I%*vec_size
:REM PROCprintf_vec(STR$(I%),vp)
x=FNfp_to_float(vp!0)+ox:y=FNfp_to_float(vp!4)+oy:z=FNfp_to_float(vp!8)+oz
A%=FNfloat_to_fp(x-cx):B%=FNfloat_to_fp(z-cz):dx=FNfp_to_float(USR(divide))
A%=FNfloat_to_fp(y-cy):B%=FNfloat_to_fp(z-cz):dy=FNfp_to_float(USR(divide))
: REM Project to screen
:REM sx = vp_centre_x + vp_scale * (x-cx) / (z-cz)
:REM sy = vp_centre_y + vp_scale * (y-cy) / (z-cz)
sx = vp_centre_x + vp_scale * dx
sy = vp_centre_y + vp_scale * dy
PLOT 69, sx, sy
NEXT
ENDPROC
