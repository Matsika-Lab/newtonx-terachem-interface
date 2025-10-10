# General program information
gpus                    1 0             # Specifies the number of GPUs and selects the GPU(s) to be used
timings                 yes             # Switch to turn on/off global timings

# Threshold information
precision               double          # Selects the floating point precision
threall                 1.0e-20         # The integral screening threshold
thregr                  1.0e-20
convthre                1.0e-6          # The SCF wavefunction convergence threshold

# Method, molecule, and basis information
basis                   cc-pvdz         # The basis set (required)
coordinates             geom.xyz     # Specifies the coordinates file (required)
method                  hf              # Selects the electronic structure method (required)
maxit                   500             # Maximum number of SCF iterations
scf                     diis            # SCF method
run                     gradient         # Selects the runtype (required)

# Molecular charge and spin multiplicity
charge                  0               # Selects the molecular charge (required)
spinmult                1               # Spin multiplicity

fon                     yes             # Use FOMO-SCF (thermal smearing)
casci                   yes             # Use CAS-CI
fon_method              gaussian        # Gaussian type of smearing
fon_temperature         0.2            # Electronic temperature i.e. kT for FON


# Direct CI specific options
directci                yes             # Force the use of direct CI (Davidson diagonalization)
cphfiter                        80      # No. of CPHF interations
dcimaxiter              300             # Number of Davidson iterations for the CAS calculation
dciprintinfo            yes             # print more information for the Davidson procedure
dcipreconditioner       orbenergy       # use orbital energy difference preconditioning

closed                  30              # Number of closed orbitals
active                  10              # Number of active orbitals
cassinglets             8               # Number of singlets to calculate
castriplets             0               # Number of triplets to calculate
casquintets             0               # Number of quintets to calculate
castarget               0               # target state for calculating gradient
castargetmult           1               # multiplicity of the targeted state
cascharges              yes             # Perform Mulliken population analysis
cas_ntos                yes             # Print out Singlet state single excitation character

end
