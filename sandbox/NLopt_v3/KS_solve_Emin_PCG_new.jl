function setup_guess_wavefunc!( Ham, psiks, startingrhoe, skip_initial_diag )
    
    Npoints = prod(Ham.pw.Ns)
    Nspin = Ham.electrons.Nspin
    Rhoe = zeros(Float64,Npoints,Nspin)
    
    if startingrhoe == :gaussian
        @assert Nspin == 1
        Rhoe[:,1] = guess_rhoe( Ham )
    else
        calc_rhoe!( Ham, psiks, Rhoe )
    end
    #
    update!(Ham, Rhoe)
    #
    if !skip_initial_diag
        _ =
        diag_LOBPCG!( Ham, psiks, verbose=false, verbose_last=false, NiterMax=10 )
    end
    return
end

struct MinimizeParams
    N_α_adjust_max::Int64
    αt_start::Float64
    αt_min::Float64
    αt_reduceFactor::Float64
    αt_increaseFactor::Float64
    updateTestStepSize::Bool
end

function MinimizeParams()
    N_α_adjust_max = 3
    αt_start = 1.0 #1.0
    αt_min = 1e-5
    αt_reduceFactor = 0.1 #0.1
    αt_increaseFactor = 3.0
    updateTestStepSize = true
    return MinimizeParams( N_α_adjust_max, αt_start, αt_min, αt_reduceFactor,
        αt_increaseFactor, updateTestStepSize )
end




function KS_solve_Emin_PCG_new!( Ham, psiks;
    etot_conv_thr=1e-6, skip_initial_diag=false, startingrhoe=:gaussian, NiterMax=5
)

    Nkspin = length(psiks)

    g = zeros_BlochWavefunc(Ham)
    Kg = zeros_BlochWavefunc(Ham)
    gPrev = zeros_BlochWavefunc(Ham)
    d_old = zeros_BlochWavefunc(Ham) # needed for β Dai-Yuan

    Npoints = prod(Ham.pw.Ns)
    Nspin = Ham.electrons.Nspin
    Nstates = Ham.electrons.Nstates

    setup_guess_wavefunc!( Ham, psiks, startingrhoe, skip_initial_diag )

    # calculate E_NN
    Ham.energies.NN = calc_E_NN( Ham.atoms )
    # calculate PspCore energy
    Ham.energies.PspCore = calc_PspCore_ene( Ham.atoms, Ham.pspots )

    # No need to orthonormalize
    Etot = calc_energies_grad!( Ham, psiks, g, Kg )
    println("Initial Etot = ", Etot)
    println("Initial dot_BlochWavefunc(g,g) = ", dot_BlochWavefunc(g,g))

    d = deepcopy(Kg)

    # Constrain
    constrain_search_dir!( d, psiks )

    gPrevUsed = true

    minim_params = MinimizeParams()

    αt_start = minim_params.αt_start
    αt_min = minim_params.αt_min
    updateTestStepSize = minim_params.updateTestStepSize
    #αt = αt_start
    #α = αt
    αt = αt_start*ones(Nkspin)
    α = copy(αt)

    #β = 0.0
    β = zeros(Nkspin)
    gKnorm = zeros(Nkspin)
    gKnormPrev = zeros(Nkspin)
    force_grad_dir = true

    Etot_old = Etot
    Nconverges = 0
    
    cg_test = 0.0

    for iter in 1:NiterMax

        println("\nBegin iter = ", iter)

        for i in 1:Nkspin
            gKnorm[i] = 2.0*real(dot(g[i], Kg[i]))
        end
        
        if !force_grad_dir
            
            for i in 1:Nkspin
                #dotgd = dot_BlochWavefunc(g, d)
                dotgd = 2.0*real(dot(g[i],d[i]))
                if gPrevUsed
                    #dotgPrevKg = dot_BlochWavefunc(gPrev, Kg)
                    dotgPrevKg = 2.0*real(dot(gPrev[i],Kg[i]))
                else
                    dotgPrevKg = 0.0
                end
                β[i] = (gKnorm[i] - dotgPrevKg)/gKnormPrev[i] # Polak-Ribiere
                println("β raw = ", β[i])
                if β[i] < 0.0
                    println("Resetting β")
                    β[i] = 0.0
                end
            end
            #β = gKnorm/gKnormPrev # Fletcher-Reeves
            #β = (gKnorm - dotgPrevKg) / ( dotgd - dot_BlochWavefunc(d,gPrev) )
            #β = gKnorm/dot_BlochWavefunc(g .- gPrev, d_old)
            #β = 0.0

            #println("dotgPrevKg = ", dotgPrevKg)
            #println("gKnorm - dotgPrevKg = ", gKnorm - dotgPrevKg)
            #println("gKnormPrev = ", gKnormPrev)

            #denum = sqrt( dot_BlochWavefunc(g,g) * dot_BlochWavefunc(d,d) )
            #println("linmin test: ", dotgd/denum )
            #if gPrevUsed
            #    cg_test  = dotgPrevKg/sqrt(gKnorm*gKnormPrev)
            #    println("CG test: ", cg_test)
            #end
        end

        force_grad_dir = false

        # Check convergence here ....

        # No convergence yet, continuing ...
        
        if gPrevUsed
            gPrev = deepcopy(g)
        end
        gKnormPrev = copy(gKnorm)

        # Update search direction
        for i in 1:Nkspin
            d_old[i] = copy(d[i])
            d[i] = -Kg[i] + β[i]*d[i]
        end

        constrain_search_dir!( d, psiks )

        #if cg_test >= 0.8
        #    if αt_start > αt_min
        #        @printf("cg_test is large at αt = %e, resetting ...", αt)
        #        αt = αt_start #*0.9
        #        #αt_start = αt_start*0.9
        #        @printf(" αt is now set to: %f\n", αt)
        #    end
        #end

        # Line minimization
        for i = 1:Nkspin
            linmin_success, α[i], αt[i] = linmin_quad!( Ham, i, psiks, g, d, α[i], αt[i], Etot, minim_params )
            println("linmin_success = ", linmin_success)
            @printf("α = %18.10e, αt = %18.10e\n", α[i], αt[i])
        end
        linmin_success = true # FIXME
        ##for i in 1:Nkspin
        ##    println("dot g g: ", dot(g[i], g[i]))
        ##end
        #@printf("dot_BlochWavefunc(g,g) = %18.10e\n", dot_BlochWavefunc(g,g))

        #linmin_success, α = linmin_armijo!( Ham, psiks, g, d, Etot )

        # Using alternative line minimization
        #linmin_success, α = linmin_grad!( Ham, psiks, g, d )

        if linmin_success
            #
            do_step!( psiks, α, d )
            Etot = calc_energies_grad!( Ham, psiks, g, Kg )
            #
            if updateTestStepSize
                for i in 1:Nkspin
                    αt[i] = α[i]
                    if αt[i] < αt_min    # bad step size
                        @printf("Bad step size: αt is reset to αt_start: %f\n", αt_start)
                        αt[i] = αt_start # make sure next test step size is not too bad
                    end
                end
            end
        else
            # linmin failed:
            do_step!( psiks, -α, d )  # CHECK THIS ...
            Etot = calc_energies_grad!( Ham, psiks, g, Kg )            
            
            @printf("linmin is failed: Update psiks by αt_min = %e, Etot = %18.10f\n", αt_min, Etot)

            if β >= 1e-10   # should be compared with small number
                # Failed, but not along the gradient direction:
                @printf("Step failed: resetting search direction.\n")
                forceGradDirection = true # reset search direction
            else
                # Failed along the gradient direction
                @printf("Step failed along negative gradient direction.\n")
                @printf("Probably at roundoff error limit. (Should stop)\n")
                #return
            end
        end
        
        diffE = Etot_old - Etot
        @printf("Emin_PCG_new step %8d = %18.10f   %10.7e\n", iter, Etot, diffE)
        if diffE < 0.0
            println("*** WARNING: Etot is not decreasing")
        end

        if abs(diffE) < etot_conv_thr
            Nconverges = Nconverges + 1
        else
            Nconverges = 0
        end

        if (Nconverges >= 2) && (dot_BlochWavefunc(g,g) >= 1e-5)
            println("Probably early convergence, continuing ...")
            Nconverges = 0
        end
        
        if Nconverges >= 2
            @printf("\nEmin_PCG is converged in iter: %d\n", iter)
            break
        end

        Etot_old = Etot

    end


    println("Leaving KS_solve_Emin_PCG_new")

end

