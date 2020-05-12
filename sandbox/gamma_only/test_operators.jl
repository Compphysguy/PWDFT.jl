using Printf
using LinearAlgebra
using Random
using FFTW

using PWDFT

const DIR_PWDFT = joinpath(dirname(pathof(PWDFT)),"..")
const DIR_PSP = joinpath(DIR_PWDFT, "pseudopotentials", "pade_gth")
const DIR_STRUCTURES = joinpath(DIR_PWDFT, "structures")

include("PWGridGamma.jl")
include("wrappers_fft_gamma.jl")
include("ortho_GS_gamma.jl")
include("PsPotNLGamma.jl")
include("HamiltonianGamma.jl")
include("BlochWavefuncGamma.jl")
include("calc_rhoe_gamma.jl")
include("Poisson_solve_gamma.jl")
include("op_K_gamma.jl")
include("op_V_loc_gamma.jl")
include("op_V_Ps_nloc_gamma.jl")
include("op_H_gamma.jl")

include("unfold_BlochWavefuncGamma.jl")

function test_01()

    Random.seed!(1234)

    #atoms = Atoms( xyz_file=joinpath(DIR_STRUCTURES, "H2.xyz"),
    #               LatVecs = gen_lattice_sc(16.0) )
    #pspfiles = [joinpath(DIR_PSP, "H-q1.gth")]
    
    atoms = Atoms( ext_xyz_file=joinpath(DIR_STRUCTURES, "NH3.xyz") )
    pspfiles = [joinpath(DIR_PSP, "N-q5.gth"),
                joinpath(DIR_PSP, "H-q1.gth")]

    # Initialize Hamiltonian
    ecutwfc = 15.0
    Ham = HamiltonianGamma( atoms, pspfiles, ecutwfc )

    Ham_ = Hamiltonian( atoms, pspfiles, ecutwfc )

    psis = randn_BlochWavefuncGamma(Ham)

    psiks = unfold_BlochWavefuncGamma( Ham.pw, Ham_.pw, psis )

    Rhoe = calc_rhoe(Ham, psis)

    Rhoe_ = calc_rhoe(Ham_, psiks)

    update!(Ham, Rhoe)
    update!(Ham_, Rhoe_)

    println("V Ps loc comparison")
    for ip in 1:5
        @printf("%3d %18.10f %18.10f\n", ip, Ham.potentials.Ps_loc[ip], Ham_.potentials.Ps_loc[ip])
    end

    println("V Hartree comparison")
    for ip in 1:5
        @printf("%3d %18.10f %18.10f\n", ip, Ham.potentials.Hartree[ip], Ham_.potentials.Hartree[ip])
    end

    println("V XC comparison")
    for ip in 1:5
        @printf("%3d %18.10f %18.10f\n", ip, Ham.potentials.XC[ip,1], Ham_.potentials.XC[ip,1])
    end

    println("V Total comparison")
    for ip in 1:5
        @printf("%3d %18.10f %18.10f\n", ip, Ham.potentials.Total[ip,1], Ham_.potentials.Total[ip,1])
    end

    exit()

    Kpsis = op_K(Ham, psis)
    println("sum Kpsis = ", sum(Kpsis.data[1]))

    V_loc_psis = op_V_loc(Ham, psis)
    println("sum V_loc_psis = ", sum(V_loc_psis.data[1]))

    V_Ps_nloc_psis = op_V_Ps_nloc(Ham, psis)
    println("sum V_Ps_nloc_psis = ", sum(V_Ps_nloc_psis.data[1]))

    Hpsis = op_H(Ham, psis)
    println("sum Hpsis = ", sum(Hpsis.data[1]))

    println("Pass here")

end

test_01()