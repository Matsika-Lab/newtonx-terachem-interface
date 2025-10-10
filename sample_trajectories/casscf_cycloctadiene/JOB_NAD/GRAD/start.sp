gpus                    1
gpumem                  3000
timings                 yes

# basis set
basis                   cc-pvdz
sphericalbasis		yes

# coordinates file
coordinates             geom.xyz


# molecule charge
charge                  0
spinmult                1

# SCF method (rhf/blyp/b3lyp/etc...)
method                  rhf

threall                 1e-14
convthre                1e-8
precision               double

#casscf
casscf                 yes
#ci_solver              direct
closed                 28
active                 3
castarget              0
castargetmult          1
cassinglets            3
casscfmaxiter          100

# type of the job (energy/gradient/md/minimize/ts/coupling)
run                     gradient
