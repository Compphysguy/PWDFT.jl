using LinearAlgebra
using Printf
using PWDFT
using Random

const DIR_PWDFT = joinpath(dirname(pathof(PWDFT)),"..")
const DIR_PSP = joinpath(DIR_PWDFT, "pseudopotentials", "pade_gth")

include("smearing.jl")
include("create_Ham.jl")

function main()

    Random.seed!(1234)

    kT = 0.01
    Ham = create_Ham_atom_Al_smearing()
    #Ham = create_Ham_Al_fcc_smearing()

    KS_solve_SCF!( Ham, mix_method="anderson", use_smearing=true, kT=kT)

end

main()