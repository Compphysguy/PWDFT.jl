using Random
using Printf
using PWDFT

Random.seed!(1234)

include("my_scf.jl")
include("my_scf_potmix.jl")

const DIR_PWDFT = joinpath( dirname(pathof(PWDFT)), "..")
const DIR_PSP = joinpath(DIR_PWDFT, "pseudopotentials", "pade_gth")

function test_my_scf(β::Float64; mix_what=:density, log_file="scf_history.dat")

    # Atoms
    atoms = Atoms( xyz_string_frac=
        """
        2

        Ga  0.0   0.0   0.0
        As  0.25  0.25  0.25
        """, in_bohr=true, LatVecs = gen_lattice_fcc(10.6839444516) )

    # Initialize Hamiltonian
    pspfiles = [joinpath(DIR_PSP, "Ga-q3.gth"),
                joinpath(DIR_PSP, "As-q5.gth")]
    ecutwfc = 15.0
    Ham = Hamiltonian( atoms, pspfiles, ecutwfc, meshk=[3,3,3] )

    if mix_what == :density
        my_scf!(Ham, betamix=β, log_file=log_file)
    elseif mix_what == :potential
        my_scf_potmix!(Ham, betamix=β)
    else
        println("mix_what = ", mix_what)
        error("Unknown mix_what")
    end

    println()
    println("Kohn-Sham energy components\n")
    println(Ham.energies)
end

#test_my_scf(0.4, mix_what=:density)
#test_my_scf(0.4, mix_what=:potential)

for β in [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9]
    test_my_scf(β, log_file="GaAs_scf_history_betamix_"*string(β)*".dat")
end
