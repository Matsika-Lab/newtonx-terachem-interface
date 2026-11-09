# hh-TDA BH&HLYP/6-31G*. FOMO window = all occupied orbitals of the (N+2)-electron
# reference: closed 0, active (N+2)/2 = 9 for ethylene (N = 16).
basis           6-31g*
method          bhandhlyp
fon             yes
fon_method      constant
closed          0
active          9
hhtda           yes
hhtdasinglets   3
cisnumstates    3
cisalgorithm    davidson
cisguessvecs    10
cismaxiter      1000
cisconvtol      1.0e-6
charge          0
spinmult        1
gpus            1
coordinates     geom.xyz
