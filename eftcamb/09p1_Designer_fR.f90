!----------------------------------------------------------------------------------------
!
! This file is part of EFTCAMB.
!
! Copyright (C) 2013-2016 by the EFTCAMB authors
!
! The EFTCAMB code is free software;
! You can use it, redistribute it, and/or modify it under the terms
! of the GNU General Public License as published by the Free Software Foundation;
! either version 3 of the License, or (at your option) any later version.
! The full text of the license can be found in the file eftcamb/LICENSE at
! the top level of the EFTCAMB distribution.
!
!----------------------------------------------------------------------------------------

!> @file 09p1_Designer_fR.f90
!! This file contains the relevant code for designer f(R) models.


!----------------------------------------------------------------------------------------
!> This module contains the relevant code for designer f(R) models.

!> @author Bin Hu, Marco Raveri

module EFTCAMB_designer_fR

    use precision
    use IniFile
    use equispaced_linear_interpolation_1D
    use EFTCAMB_rootfind
    use EFTCAMB_cache
    use EFTCAMB_abstract_parametrizations_1D
    use EFTCAMB_neutral_parametrization_1D
    use EFTCAMB_constant_parametrization_1D
    use EFTCAMB_linear_parametrizations_1D
    use EFTCAMB_abstract_model_designer

    implicit none

    private

    public EFTCAMB_fR_designer

    !----------------------------------------------------------------------------------------
    !> This is the designer f(R) model.
    type, extends ( EFTCAMB_designer_model ) :: EFTCAMB_fR_designer

        ! theory parameters:
        real(dl) :: B0                                                    !< The present day value of B0.

        ! the pure EFT functions model selection flags:
        integer  :: EFTwDE                                                !< Model selection flag for designer f(R) w DE.

        ! the pure EFT functions:
        class( parametrized_function_1D ), allocatable :: PureEFTwDE      !< The pure EFT function w_DE.

        ! the interpolated EFT functions that come out of the background sover:
        type(equispaced_linear_interpolate_function_1D) :: EFTOmega       !< The interpolated function Omega (and derivatives).
        type(equispaced_linear_interpolate_function_1D) :: EFTLambda      !< The interpolated function Lambda (and derivatives).

        ! some designer parameters:
        integer  :: designer_num_points = 1000                            !< Number of points sampled by the designer code.
        real(dl) :: x_initial           = log(10._dl**(-8._dl))           !< log(a start)
        real(dl) :: x_final             = 0._dl                           !< log(a final)

    contains

        ! initialization of the model:
        procedure :: read_model_selection            => EFTCAMBDesignerFRReadModelSelectionFromFile  !< subroutine that reads the parameters of the model from file
        procedure :: allocate_model_selection        => EFTCAMBDesignerFRAllocateModelSelection      !< subroutine that allocates the model selection.
        procedure :: init_model_parameters           => EFTCAMBDesignerFRInitModelParameters         !< subroutine taht initializes the model parameters based on the values found in an input array.
        procedure :: init_model_parameters_from_file => EFTCAMBDesignerFRInitModelParametersFromFile !< subroutine that reads the parameters of the model from file.

        ! background solver:
        procedure :: initialize_background           => EFTCAMBDesignerFRInitBackground   !< subroutine that initializes the background of designer f(R).
        procedure :: solve_designer_equations        => EFTCAMBDesignerFRSolveDesignerEquations !< subroutine that solves the designer f(R) background equations.
        procedure :: find_initial_conditions         => EFTCAMBDesignerFRFindInitialConditions  !< subroutine that solves the background equations several time to determine the values of the initial conditions.

        ! utility functions:
        procedure :: compute_param_number  => EFTCAMBDesignerFRComputeParametersNumber    !< subroutine that computes the number of parameters of the model.
        procedure :: feedback              => EFTCAMBDesignerFRFeedback                   !< subroutine that prints on the screen feedback information about the model.
        procedure :: parameter_names       => EFTCAMBDesignerFRParameterNames             !< subroutine that returns the i-th parameter name of the model.
        procedure :: parameter_names_latex => EFTCAMBDesignerFRParameterNamesLatex        !< subroutine that returns the i-th parameter name of the model.
        procedure :: parameter_values      => EFTCAMBDesignerFRParameterValues            !< subroutine that returns the i-th parameter value.

        ! CAMB related procedures:
        procedure :: compute_background_EFT_functions  => EFTCAMBDesignerFRBackgroundEFTFunctions   !< subroutine that computes the value of the background EFT functions at a given time.
        procedure :: compute_secondorder_EFT_functions => EFTCAMBDesignerFRSecondOrderEFTFunctions  !< subroutine that computes the value of the second order EFT functions at a given time.
        procedure :: compute_dtauda                    => EFTCAMBDesignerFRComputeDtauda            !< function that computes dtauda = 1/sqrt(a^2H^2).
        procedure :: compute_adotoa                    => EFTCAMBDesignerFRComputeAdotoa            !< subroutine that computes adotoa = H and its two derivatives wrt conformal time.
        procedure :: compute_H_derivs                  => EFTCAMBDesignerFRComputeHubbleDer         !< subroutine that computes the two derivatives wrt conformal time of H.

    end type EFTCAMB_fR_designer

    ! ---------------------------------------------------------------------------------------------

contains

    ! ---------------------------------------------------------------------------------------------
    !> Subroutine that reads the parameters of the model from file.
    subroutine EFTCAMBDesignerFRReadModelSelectionFromFile( self, Ini )

        implicit none

        class(EFTCAMB_fR_designer)  :: self   !< the base class
        type(TIniFile)              :: Ini    !< Input ini file

        ! read model selection flags:
        self%EFTwDE             = Ini_Read_Int_File( Ini, 'EFTwDE', 0 )

    end subroutine EFTCAMBDesignerFRReadModelSelectionFromFile

    ! ---------------------------------------------------------------------------------------------
    !> Subroutine that allocates the model selection.
    subroutine EFTCAMBDesignerFRAllocateModelSelection( self )

        implicit none

        class(EFTCAMB_fR_designer)  :: self   !< the base class

        ! allocate wDE:
        if ( allocated(self%PureEFTwDE) ) deallocate(self%PureEFTwDE)
        select case ( self%EFTwDE )
            case(0)
                allocate( wDE_LCDM_parametrization_1D::self%PureEFTwDE )
            case(1)
                allocate( constant_parametrization_1D::self%PureEFTwDE )
            case default
                write(*,'(a,I3)') 'No model corresponding to EFTwDE =', self%EFTwDE
                write(*,'(a)')    'Please select an appropriate model.'
        end select

        ! initialize the names:
        call self%PureEFTwDE%set_name( 'EFTw'     , 'w'            )

    end subroutine EFTCAMBDesignerFRAllocateModelSelection

    ! ---------------------------------------------------------------------------------------------
    !> Subroutine taht initializes the model parameters based on the values found in an input array.
    subroutine EFTCAMBDesignerFRInitModelParameters( self, array )

        implicit none

        class(EFTCAMB_fR_designer)  :: self   !< the base class
        real(dl), dimension(self%parameter_number), intent(in) :: array  !< input array with the values of the parameters.

        stop 'IW'

    end subroutine EFTCAMBDesignerFRInitModelParameters

    ! ---------------------------------------------------------------------------------------------
    !> Subroutine that reads the parameters of the model from file.
    subroutine EFTCAMBDesignerFRInitModelParametersFromFile( self, Ini )

        implicit none

        class(EFTCAMB_fR_designer)  :: self   !< the base class
        type(TIniFile)              :: Ini    !< Input ini file

        ! read w_DE parameters:
        call self%PureEFTwDE%init_from_file( Ini )
        ! read B0:
        self%B0 = Ini_Read_Double_File( Ini, 'EFTB0', 0._dl )

    end subroutine EFTCAMBDesignerFRInitModelParametersFromFile

    ! ---------------------------------------------------------------------------------------------
    !> Subroutine that initializes the background of designer f(R).
    subroutine EFTCAMBDesignerFRInitBackground( self, params_cache )

        implicit none

        class(EFTCAMB_fR_designer)                   :: self          !< the base class
        type(EFTCAMB_parameter_cache), intent(in)    :: params_cache  !< a EFTCAMB parameter cache containing cosmological parameters

        real(dl) :: A_ini, B0
        logical  :: success

        ! initialize interpolating functions:
        call self%EFTOmega%initialize  ( self%designer_num_points, self%x_initial, self%x_final, 0._dl )
        call self%EFTLambda%initialize ( self%designer_num_points, self%x_initial, self%x_final, 0._dl )

        ! call boundary conditions lookup:
        call self%find_initial_conditions( params_cache, A_ini, success )

        ! solve the background equations and store the solution:
        call self%solve_designer_equations( params_cache, A_ini, B0, only_B0=.False. )

    end subroutine EFTCAMBDesignerFRInitBackground

    ! ---------------------------------------------------------------------------------------------
    !> Subroutine that solves the designer f(R) background equations.
    subroutine EFTCAMBDesignerFRSolveDesignerEquations( self, params_cache, A, B0, only_B0 )

        implicit none

        class(EFTCAMB_fR_designer)                   :: self          !< the base class.
        type(EFTCAMB_parameter_cache), intent(in)    :: params_cache  !< a EFTCAMB parameter cache containing cosmological parameters.
        real(dl), intent(in)                         :: A             !< the initial value of the A coefficient. Refer to the numerical notes for the details.
        real(dl), intent(out)                        :: B0            !< present day value of B.
        logical , optional                           :: only_B0       !< logical flag that tells the code wether to compute only B0 or also the EFT functions.

        integer, parameter :: num_eq = 2   !<  Number of equations

        real(dl) :: Omegam_EFT, Omegavac_EFT, OmegaMassiveNu_EFT, OmegaGamma_EFT, OmegaNu_EFT
        real(dl) :: Omegarad_EFT, EquivalenceScale_fR, Ratio_fR, Initial_B_fR, Initial_C_fR
        real(dl) :: PPlus, yPlus, CoeffA_Part, yStar, x

        real(dl) :: y(num_eq), ydot(num_eq)

        integer  :: itol, itask, istate, iopt, LRN, LRS, LRW, LIS, LIN, LIW, JacobianMode, i
        real(dl) :: rtol, atol, t1, t2, B
        real(dl), allocatable :: rwork(:)
        integer,  allocatable :: iwork(:)

        ! digedt the input:
        if ( .not. present(only_B0) ) only_B0 = .False.

        ! 1) Cosmological parameters:
        Omegam_EFT         = params_cache%omegab + params_cache%omegac
        Omegavac_EFT       = params_cache%omegav
        OmegaMassiveNu_EFT = params_cache%omegan
        OmegaGamma_EFT     = params_cache%omegag
        OmegaNu_EFT        = params_cache%omegar

        Omegarad_EFT       = OmegaGamma_EFT + OmegaNu_EFT

        EquivalenceScale_fR = (Omegarad_EFT+ OmegaMassiveNu_EFT)/Omegam_EFT
        Ratio_fR = EquivalenceScale_fR/Exp( self%x_initial )

        ! 2) Growing mode solution:
        Initial_B_fR = (7._dl + 8._dl*Ratio_fR)/(2._dl*(1._dl + Ratio_fR))
        Initial_C_fR = -3._dl/(2._dl*(1._dl + Ratio_fR))
        PPlus = 0.5_dl*(-Initial_B_fR + Sqrt(Initial_B_fR**2 - 4._dl*Initial_C_fR))
        yPlus = exp(PPlus*self%x_initial)
        !    Construction of the particolar solution:
        CoeffA_Part = (-6._dl*Initial_C_fR)/(-3._dl*Exp(self%x_initial)*self%PureEFTwDE%first_derivative( Exp(self%x_initial) )&
            & +9._dl*self%PureEFTwDE%value( Exp(self%x_initial) )**2&
            & +(18._dl-3._dl*Initial_B_fR)*self%PureEFTwDE%value( Exp(self%x_initial) )&
            & +9._dl -3._dl*Initial_B_fR +Initial_C_fR)
        yStar = CoeffA_Part*Omegavac_EFT*Exp(-2._dl*self%x_initial)*self%PureEFTwDE%integral( Exp(self%x_initial) )

        ! 3) Set initial conditions:
        x    = self%x_initial
        y(1) = A*yPlus + yStar
        y(2) = PPlus*A*yPlus - 3._dl*( 1._dl+ self%PureEFTwDE%value(Exp(self%x_initial)) )*yStar
        ydot = 0._dl

        ! 4) Initialize DLSODA:
        ! set-up the relative and absolute tollerances:
        itol = 1
        rtol = 1.d-10
        atol = 1.d-14
        ! initialize task to do:
        itask  = 1
        istate = 1
        iopt   = 1
        ! initialize the work space:
        LRN = 20 + 16*num_eq
        LRS = 22 + 9*num_eq + num_eq**2
        LRW = max(LRN,LRS)
        LIS = 20 + num_eq
        LIN = 20
        LIW = max(LIS,LIN)
        ! allocate the arrays:
        allocate(rwork(LRW))
        allocate(iwork(LIW))
        ! optional lsoda input:
        RWORK(5) = 0._dl  ! the step size to be attempted on the first step. The default value is determined by the solver.
        RWORK(6) = 0._dl  ! the maximum absolute step size allowed. The default value is infinite.
        RWORK(7) = 0._dl  ! the minimum absolute step size allowed. The default value is 0.
        IWORK(5) = 0      ! flag to generate extra printing at method switches. IXPR = 0 means no extra printing (the default). IXPR = 1 means print data on each switch.
        IWORK(6) = 100    ! maximum number of (internally defined) steps allowed during one call to the solver. The default value is 500.
        IWORK(7) = 0      ! maximum number of messages printed (per problem) warning that T + H = T on a step (H = step size). This must be positive to result in a non-default value.  The default value is 10.
        IWORK(8) = 0      ! the maximum order to be allowed for the nonstiff (Adams) method.  the default value is 12.
        IWORK(9) = 0      ! the maximum order to be allowed for the stiff (BDF) method.  The default value is 5.
        ! additional lsoda stuff:
        CALL XSETF(0) ! suppress odepack printing
        ! Jacobian mode: 1=fullJacobian, 2=not provided
        JacobianMode = 2

        ! store the first value of the EFT functions:
        t1  = self%EFTOmega%x(1)
        ! compute output EFT functions if needed:
        if ( .not. only_B0 ) then
            call output( num_eq, 1, t1, y, B0 )
        end if

        ! 5) solve the equations:
        do i=1, self%EFTOmega%num_points-1
            ! set the time step:
            t1 = self%EFTOmega%x(i)
            t2 = self%EFTOmega%x(i+1)
            ! solve the system:
            !call DLSODA ( derivs, num_eq, y, t1, t2, itol, rtol, atol, itask, istate, iopt, RWORK, LRW, IWORK, LIW, jacobian, JacobianMode)
            ! check istate for LSODA good completion:


            call  derivs(num_eq, t1, y, ydot)
            call  EFT_rk4(num_eq, y, ydot, t1, self%EFTOmega%grid_width, y, derivs)

            ! compute output EFT functions if needed:
            if ( .not. only_B0 ) then
                call output( num_eq, i+1, t2, y, B0 )
            end if

        end do

        ! compute B0:
        if ( only_B0 ) then
            call output( num_eq, self%EFTOmega%num_points, t2, y, B0 )
        end if

        return

    contains

        ! ---------------------------------------------------------------------------------------------
        !> Subroutine that computes y' given y for the background of designer f(R)
        subroutine derivs( num_eq, x, y, ydot )

            implicit none

            integer , intent(in)                     :: num_eq !< number of equations in the ODE system
            real(dl), intent(in)                     :: x      !< time at which the derivatives of the system are computed
            real(dl), intent(in) , dimension(num_eq) :: y      !< input status of the system
            real(dl), intent(out), dimension(num_eq) :: ydot   !< value of the derivative at time x

            real(dl) :: a, EFT_E_gfun, EFT_E_gfunp, EFT_E_gfunpp, EFT_E_gfunppp
            real(dl) :: rhonu_tot, presnu_tot, presnudot_tot, presnudotdot_tot
            real(dl) :: EFT_E_nu, EFT_EP_nu, EFT_EPP_nu, EFT_E3P_nu, rhonu, presnu, grhormass_t
            real(dl) :: EFunction, EFunPrime, adotoa, Hdot, presnudot, presnudotdot
            real(dl) :: EFunPrime2, EFunPrime3
            integer  :: nu_i

            ! 1) convert x in a:
            a = Exp(x)

            ! 2) Compute the function g(x) and its derivatives:
            EFT_E_gfun    = -(Log( self%PureEFTwDE%integral(a) ) -2._dl*x)/3._dl
            EFT_E_gfunp   = 1._dl +self%PureEFTwDE%value(a)
            EFT_E_gfunpp  = Exp(x)*self%PureEFTwDE%first_derivative(a)
            EFT_E_gfunppp = Exp(x)*self%PureEFTwDE%first_derivative(a) +Exp(2._dl*x)*self%PureEFTwDE%second_derivative(a)

            ! 3) Compute energy and its derivatives:
            ! First compute massive neutrinos contribution:
            rhonu_tot  = 0._dl
            presnu_tot = 0._dl
            EFT_E_nu   = 0._dl
            EFT_EP_nu  = 0._dl
            if ( params_cache%Num_Nu_Massive /= 0) then
                do nu_i = 1, params_cache%Nu_mass_eigenstates

                    rhonu  = 0._dl
                    presnu = 0._dl
                    grhormass_t= params_cache%grhormass(nu_i)/a**2
                    call params_cache%Nu_background(a*params_cache%nu_masses(nu_i),rhonu,presnu)
                    rhonu_tot  = rhonu_tot + grhormass_t*rhonu
                    presnu_tot = presnu_tot + grhormass_t*presnu

                    EFT_E_nu   = EFT_E_nu  + params_cache%grhormass(nu_i)/3._dl/a**4/params_cache%h0_Mpc**2*rhonu
                    EFT_EP_nu  = EFT_EP_nu - params_cache%grhormass(nu_i)/params_cache%h0_Mpc**2/a**4*(rhonu +presnu)

                end do
            end if

            ! Add its contribution to E and E':
            EFunction = +OmegaRad_EFT*exp(-4._dl*x)&
                & +Omegam_EFT*exp(-3._dl*x)&
                & +Omegavac_EFT*exp(-3._dl*EFT_E_gfun) + EFT_E_nu
            EFunPrime = -4._dl*OmegaRad_EFT*exp(-4._dl*x)&
                & -3._dl*Omegam_EFT*exp(-3._dl*x)&
                & -3._dl*Omegavac_EFT*EFT_E_gfunp*exp(-3._dl*EFT_E_gfun) +EFT_EP_nu

            ! Compute everything of massive nu again to get the time derivatives:
            rhonu_tot  = 0._dl
            presnu_tot = 0._dl
            presnudot_tot = 0._dl
            presnudotdot_tot = 0._dl
            EFT_E_nu   = 0._dl
            EFT_EP_nu  = 0._dl
            EFT_EPP_nu = 0._dl
            EFT_E3P_nu = 0._dl
            if ( params_cache%Num_Nu_Massive /= 0 ) then
                do nu_i = 1, params_cache%Nu_mass_eigenstates

                    adotoa = +a*params_cache%h0_Mpc*sqrt(EFunction)
                    Hdot   = +0.5_dl*params_cache%h0_Mpc**2*a**2*EFunPrime +adotoa**2

                    rhonu        = 0._dl
                    presnu       = 0._dl
                    presnudot    = 0._dl
                    presnudotdot = 0._dl

                    grhormass_t = params_cache%grhormass(nu_i)/a**2

                    call params_cache%Nu_background(a*params_cache%nu_masses(nu_i),rhonu,presnu)
                    presnudot = params_cache%Nu_pidot(a*params_cache%nu_masses(nu_i),adotoa,presnu)
                    presnudotdot = params_cache%Nu_pidotdot(a*params_cache%nu_masses(nu_i),adotoa,Hdot,presnu,presnudot)

                    rhonu_tot  = rhonu_tot + grhormass_t*rhonu
                    presnu_tot = presnu_tot + grhormass_t*presnu
                    presnudot_tot  = presnudot_tot + grhormass_t*(presnudot -4._dl*adotoa*presnu)
                    presnudotdot_tot = presnudotdot_tot + grhormass_t*(presnudotdot &
                        & -8._dl*adotoa*presnudot +4._dl*presnu*(+4._dl*adotoa**2-Hdot))

                    EFT_E_nu   = EFT_E_nu + params_cache%grhormass(nu_i)/3._dl/a**4/params_cache%h0_Mpc**2*rhonu
                    EFT_EP_nu  = EFT_EP_nu - params_cache%grhormass(nu_i)/params_cache%h0_Mpc**2/a**4*(rhonu +presnu)
                    EFT_EPP_nu = EFT_EPP_nu + 3._dl/params_cache%h0_Mpc**2*params_cache%grhormass(nu_i)/a**4*(rhonu +presnu)&
                        & -grhormass_t*(presnudot -4._dl*adotoa*presnu)/params_cache%h0_Mpc**3/sqrt(EFunction)/a**3
                    EFT_E3P_nu = EFT_E3P_nu -9._dl/params_cache%h0_Mpc**2*params_cache%grhormass(nu_i)/a**4*(rhonu +presnu)&
                        & +(3._dl/adotoa/params_cache%h0_Mpc**2/a**2+Hdot/adotoa**3/params_cache%h0_Mpc**2/a**2)&
                        &*grhormass_t*(presnudot -4._dl*adotoa*presnu)&
                        & -grhormass_t*(presnudotdot &
                        & -8._dl*adotoa*presnudot +4._dl*presnu*(+4._dl*adotoa**2-Hdot))/adotoa**2/params_cache%h0_Mpc**2/a**2
                end do
            end if

            EFunPrime2 = 16._dl*OmegaRad_EFT*exp(-4._dl*x)&
                & +9._dl*Omegam_EFT*exp(-3._dl*x)&
                & -3._dl*Omegavac_EFT*exp(-3._dl*EFT_E_gfun)*(EFT_E_gfunpp -3._dl*EFT_E_gfunp**2) + EFT_EPP_nu
            EFunPrime3 = -64._dl*OmegaRad_EFT*exp(-4._dl*x)&
                & -27._dl*Omegam_EFT*exp(-3._dl*x)&
                & -3._dl*Omegavac_EFT*exp(-3._dl*EFT_E_gfun)*&
                &(EFT_E_gfunppp-9._dl*EFT_E_gfunp*EFT_E_gfunpp+9._dl*EFT_E_gfunp**3) + EFT_E3P_nu

            ! 4) Get the equation of motion:
            ydot(1) = y(2)
            ydot(2) = (1._dl+0.5_dl*EFunPrime/EFunction+(4._dl*EFunPrime2+EFunPrime3)/(4._dl*EFunPrime+EFunPrime2))*y(2) &
                & -0.5_dl*(4._dl*EFunPrime+EFunPrime2)/EFunction*y(1) &
                & -3._dl*Omegavac_EFT*exp(-3._dl*EFT_E_gfun)*(4._dl*EFunPrime+EFunPrime2)/EFunction

        end subroutine

        ! ---------------------------------------------------------------------------------------------
        !> Subroutine that computes the Jacobian of the system. Now a dummy function.
        !! Implementing it might increase performances.
        subroutine jacobian( num_eq, x, y, ml, mu, pd, nrowpd )

            implicit none

            integer                            :: num_eq !< number of components of the Jacobian
            integer                            :: ml     !< ignored
            integer                            :: mu     !< ignored
            integer                            :: nrowpd !< ignored
            real(dl)                           :: x      !< time at which the Jacobian is computed
            real(dl), dimension(num_eq)        :: y      !< input status of the system
            real(dl), dimension(nrowpd,num_eq) :: pd     !< output Jacobian

        end subroutine jacobian

        ! ---------------------------------------------------------------------------------------------
        !> Subroutine that takes the solution of the background f(R) equations and computes the value of
        !! B and stores the values of the EFT functions.
        subroutine output( num_eq, ind, x, y, B )

            implicit none

            integer , intent(in)                     :: num_eq !< number of equations in the ODE system.
            integer , intent(in)                     :: ind    !< index of the EFT functions interpolation tables to fill.
            real(dl), intent(in)                     :: x      !< time at which the derivatives of the system are computed.
            real(dl), intent(in) , dimension(num_eq) :: y      !< input status of the system.
            real(dl), intent(out)                    :: B      !< value of B at time x.

            real(dl) :: ydot(num_eq)
            real(dl) :: a, EFT_E_gfun, EFT_E_gfunp, EFT_E_gfunpp, EFT_E_gfunppp
            real(dl) :: rhonu_tot, presnu_tot, presnudot_tot, presnudotdot_tot
            real(dl) :: EFT_E_nu, EFT_EP_nu, EFT_EPP_nu, EFT_E3P_nu, rhonu, presnu, grhormass_t
            real(dl) :: EFunction, EFunPrime, adotoa, Hdot, presnudot, presnudotdot
            real(dl) :: EFunPrime2, EFunPrime3, Ricci, f_sub_R, Ede, Edep, Edepp
            integer  :: nu_i

            ! 1) convert x in a:
            a = Exp(x)

            ! 2) Compute the function g(x) and its derivatives:
            EFT_E_gfun    = -(Log( self%PureEFTwDE%integral(a) ) -2._dl*x)/3._dl
            EFT_E_gfunp   = 1._dl +self%PureEFTwDE%value(a)
            EFT_E_gfunpp  = Exp(x)*self%PureEFTwDE%first_derivative(a)
            EFT_E_gfunppp = Exp(x)*self%PureEFTwDE%first_derivative(a) +Exp(2._dl*x)*self%PureEFTwDE%second_derivative(a)

            ! 3) Compute energy and its derivatives:
            ! First compute massive neutrinos contribution:
            rhonu_tot  = 0._dl
            presnu_tot = 0._dl
            EFT_E_nu   = 0._dl
            EFT_EP_nu  = 0._dl
            if ( params_cache%Num_Nu_Massive /= 0) then
                do nu_i = 1, params_cache%Nu_mass_eigenstates

                    rhonu  = 0._dl
                    presnu = 0._dl
                    grhormass_t= params_cache%grhormass(nu_i)/a**2
                    call params_cache%Nu_background(a*params_cache%nu_masses(nu_i),rhonu,presnu)
                    rhonu_tot  = rhonu_tot + grhormass_t*rhonu
                    presnu_tot = presnu_tot + grhormass_t*presnu

                    EFT_E_nu   = EFT_E_nu  + params_cache%grhormass(nu_i)/3._dl/a**4/params_cache%h0_Mpc**2*rhonu
                    EFT_EP_nu  = EFT_EP_nu - params_cache%grhormass(nu_i)/params_cache%h0_Mpc**2/a**4*(rhonu +presnu)

                end do
            end if

            ! Add its contribution to E and E':
            EFunction = +OmegaRad_EFT*exp(-4._dl*x)&
                & +Omegam_EFT*exp(-3._dl*x)&
                & +Omegavac_EFT*exp(-3._dl*EFT_E_gfun) + EFT_E_nu
            EFunPrime = -4._dl*OmegaRad_EFT*exp(-4._dl*x)&
                & -3._dl*Omegam_EFT*exp(-3._dl*x)&
                & -3._dl*Omegavac_EFT*EFT_E_gfunp*exp(-3._dl*EFT_E_gfun) +EFT_EP_nu

            ! Compute everything of massive nu again to get the time derivatives:
            rhonu_tot  = 0._dl
            presnu_tot = 0._dl
            presnudot_tot = 0._dl
            presnudotdot_tot = 0._dl
            EFT_E_nu   = 0._dl
            EFT_EP_nu  = 0._dl
            EFT_EPP_nu = 0._dl
            EFT_E3P_nu = 0._dl
            if ( params_cache%Num_Nu_Massive /= 0 ) then
                do nu_i = 1, params_cache%Nu_mass_eigenstates

                    adotoa = +a*params_cache%h0_Mpc*sqrt(EFunction)
                    Hdot   = +0.5_dl*params_cache%h0_Mpc**2*a**2*EFunPrime +adotoa**2

                    rhonu  = 0._dl
                    presnu = 0._dl
                    presnudot = 0._dl
                    presnudotdot = 0._dl

                    grhormass_t = params_cache%grhormass(nu_i)/a**2

                    call params_cache%Nu_background(a*params_cache%nu_masses(nu_i),rhonu,presnu)
                    presnudot = params_cache%Nu_pidot(a*params_cache%nu_masses(nu_i),adotoa,presnu)
                    presnudotdot = params_cache%Nu_pidotdot(a*params_cache%nu_masses(nu_i),adotoa,Hdot,presnu,presnudot)

                    rhonu_tot  = rhonu_tot + grhormass_t*rhonu
                    presnu_tot = presnu_tot + grhormass_t*presnu
                    presnudot_tot  = presnudot_tot + grhormass_t*(presnudot -4._dl*adotoa*presnu)
                    presnudotdot_tot = presnudotdot_tot + grhormass_t*(presnudotdot &
                        & -8._dl*adotoa*presnudot +4._dl*presnu*(+4._dl*adotoa**2-Hdot))

                    EFT_E_nu   = EFT_E_nu + params_cache%grhormass(nu_i)/3._dl/a**4/params_cache%h0_Mpc**2*rhonu
                    EFT_EP_nu  = EFT_EP_nu - params_cache%grhormass(nu_i)/params_cache%h0_Mpc**2/a**4*(rhonu +presnu)
                    EFT_EPP_nu = EFT_EPP_nu + 3._dl/params_cache%h0_Mpc**2*params_cache%grhormass(nu_i)/a**4*(rhonu +presnu)&
                        & -grhormass_t*(presnudot -4._dl*adotoa*presnu)/params_cache%h0_Mpc**3/sqrt(EFunction)/a**3
                    EFT_E3P_nu = EFT_E3P_nu -9._dl/params_cache%h0_Mpc**2*params_cache%grhormass(nu_i)/a**4*(rhonu +presnu)&
                        & +(3._dl/adotoa/params_cache%h0_Mpc**2/a**2+Hdot/adotoa**3/params_cache%h0_Mpc**2/a**2)&
                        &*grhormass_t*(presnudot -4._dl*adotoa*presnu)&
                        & -grhormass_t*(presnudotdot &
                        & -8._dl*adotoa*presnudot +4._dl*presnu*(+4._dl*adotoa**2-Hdot))/adotoa**2/params_cache%h0_Mpc**2/a**2
                end do
            end if

            EFunPrime2 = 16._dl*OmegaRad_EFT*exp(-4._dl*x)&
                & +9._dl*Omegam_EFT*exp(-3._dl*x)&
                & -3._dl*Omegavac_EFT*exp(-3._dl*EFT_E_gfun)*(EFT_E_gfunpp -3._dl*EFT_E_gfunp**2) + EFT_EPP_nu
            EFunPrime3 = -64._dl*OmegaRad_EFT*exp(-4._dl*x)&
                & -27._dl*Omegam_EFT*exp(-3._dl*x)&
                & -3._dl*Omegavac_EFT*exp(-3._dl*EFT_E_gfun)*&
                &(EFT_E_gfunppp-9._dl*EFT_E_gfunp*EFT_E_gfunpp+9._dl*EFT_E_gfunp**3) + EFT_E3P_nu

            ! compute E dark energy:
            Ede   = +Omegavac_EFT*exp(-3._dl*EFT_E_gfun)
            Edep  = -3._dl*Omegavac_EFT*EFT_E_gfunp*exp(-3._dl*EFT_E_gfun)
            Edepp = -3._dl*Omegavac_EFT*exp(-3._dl*EFT_E_gfun)*(EFT_E_gfunpp -3._dl*EFT_E_gfunp**2)

            ! call derivs to compute ydot at a given time:
            call derivs( num_eq, x, y, ydot )

            ! Compute the Ricci:
            Ricci   = 3._dl*(4._dl*EFunction+EFunPrime)
            f_sub_R = ydot(1)/3._dl/(4._dl*EFunPrime +EFunPrime2)

            ! compute B:
            B       = 2._dl/3._dl/(1._dl +f_sub_R)*1._dl/(4._dl*EFunPrime +EFunPrime2)*EFunction/EFunPrime*&
                &( ydot(2) -ydot(1)*(4._dl*EFunPrime2+EFunPrime3)/(4._dl*EFunPrime +EFunPrime2) )

            ! compute the EFT functions:
            self%EFTOmega%y(ind)    = f_sub_R
            self%EFTOmega%yp(ind)   = Exp(-x)/(6._dl*EFunction*(EFunPrime2+4._dl*EFunPrime))*(-EFunPrime2*(6._dl*Ede+y(1))&
                &+EFunPrime*(ydot(1)-4._dl*(6._dl*Ede +y(1)))+2._dl*EFunction*ydot(1))

            self%EFTOmega%ypp(ind)  = Exp(-2._dl*x)/(12._dl*EFunction**2*(EFunPrime2+4._dl*EFunPrime))*&
                &(EFunPrime*(EFunPrime*(24._dl*Ede-ydot(1) +4._dl*y(1))-6._dl*EFunction*(8._dl*Edep +ydot(1)))&
                &+EFunPrime2*(EFunPrime*(6._dl*Ede +y(1))-12._dl*EFunction*Edep))
            self%EFTOmega%yppp(ind) = Exp(-3._dl*x)/(24._dl*EFunction**3*(EFunPrime2+4._dl*EFunPrime))*&
                &(2._dl*EFunction*(EFunPrime2**2*(6._dl*Ede+y(1))&
                & +4._dl*EFunPrime**2*(18._dl*Edep+6._dl*Ede+2._dl*ydot(1) +y(1))&
                & +EFunPrime*EFunPrime2*(18._dl*Edep+30._dl*Ede -ydot(1)+5._dl*y(1)))&
                & +12._dl*EFunction**2*(EFunPrime2*(-2._dl*Edepp+4._dl*Edep-ydot(1))&
                & +EFunPrime*(-8._dl*Edepp+16._dl*Edep +ydot(1)))&
                & +3._dl*EFunPrime**2*(EFunPrime*(ydot(1)-4._dl*(6._dl*Ede +y(1)))-EFunPrime2*(6._dl*Ede +y(1))))
            self%EFTLambda%y(ind)   = 0.5_dl*params_cache%h0_Mpc**2*( y(1) -f_sub_R*Ricci)*Exp(x)**2
            self%EFTLambda%yp(ind)  = -1.5_dl*params_cache%h0_Mpc**3*Sqrt(EFunction)*(Exp(x)**4*self%EFTOmega%yp(ind)*(4._dl*EFunction+EFunPrime))

        end subroutine

        ! ---------------------------------------------------------------------------------------------

        ! -------------------------------------------------------------------------------------------------

        !   5) Fourth order Runge-Kutta.
        !      This is a very simple algorithm that is used to solve the designer equation.
        !

        subroutine EFT_rk4(n, y, dydx, x, h, yout, deriv)
            ! n     = dimensionality of the problem;
            ! y     = 'position' at t=x;
            ! dydx  = 'velocity' at t=x;
            ! x     = initial time;
            ! h     = time step;
            ! yout  = 'position' at t=x+h computed using fourth order Runge-Kutta;
            ! deriv = name of the subroutine that computes dydx.
            use precision
            implicit none

            real(dl) :: x, h
            integer  :: n
            real(dl), dimension(n) :: y, dydx, yout

            external deriv

            real(dl), dimension(n) :: yt, dyt,dym
            real(dl) :: hh,h6,xh
            integer :: i

            hh=h*0.5_dl
            h6=h/6._dl

            xh=x+hh
            yt=y+hh*dydx

            call deriv(n, xh, yt, dyt)

            yt=y+hh*dyt

            call deriv(n, xh, yt, dym)

            yt  =y+h*dym
            dym =dyt+dym

            call deriv(n, x+h, yt, dyt)

            yout=y+h6*(dydx+dyt+2.0*dym)

            return
        end subroutine EFT_rk4


    end subroutine EFTCAMBDesignerFRSolveDesignerEquations

    ! ---------------------------------------------------------------------------------------------
    !> Subroutine that solves the background equations several time to determine the values of
    !! the initial conditions. Maps A at initial times to B0 today.
    subroutine EFTCAMBDesignerFRFindInitialConditions( self, params_cache, A_ini, success )

        implicit none

        class(EFTCAMB_fR_designer)                   :: self          !< the base class
        type(EFTCAMB_parameter_cache), intent(in)    :: params_cache  !< a EFTCAMB parameter cache containing cosmological parameters
        real(dl), intent(out)                        :: A_ini         !< value of A_initial that gives self%B0 today
        logical , intent(out)                        :: success       !< wether the calculation ended correctly or not

        real(dl) :: ATemp1, ATemp2, BTemp1, BTemp2, HorizAsyntB
        real(dl) :: VertAsyntA, ATemp3, ATemp4, BTemp3, BTemp4, realAp
        integer  :: ind

        !  Find initial conditions for designer F(R).
        !  Initial conditions are found solving B0(A)=B0wanted.
        !  The next part of code is complicated by the fact that B0(A) is not continuous and we have to adopt ad-hoc strategies.

        ! 1) Find the horizontal asymptote of B0(A)
        ATemp1 = 0._dl
        ATemp2 = 0._dl
        do ind=10, 100, 1
            ATemp1 = ATemp2
            ATemp2 = 10._dl**REAL(ind)
            BTemp1 = DesFR_BfuncA(ATemp1)
            BTemp2 = DesFR_BfuncA(ATemp2)
            if (Abs(BTemp1-BTemp2)/Abs(ATemp1-ATemp2).lt.1.d-100) exit
        end do
        HorizAsyntB = BTemp2

        write(*,*) 'f(R) designer: horizontal asymptote =',  HorizAsyntB

        ! 2) Check that the value of B0 given is not the forbidden one: the one corresponding to the horizontal asynt.
        if ( ABS(HorizAsyntB-self%B0)<1.d-15 ) then
            success=.false.
            return
        end if

        ! 3) Bracket the vertical asyntote
        ATemp1=-10._dl
        ATemp2=10._dl
        call zbrac(DesFR_BfuncA,ATemp1,ATemp2,success,HorizAsyntB)
        if (.not.success) then
            write(*,*) 'f(R) designer: failure of vert asynt bracketing'
            return
        end if

        ! 4) Find the vertical asyntote by tricking the root finding algorithm.
        VertAsyntA = zbrent(DesFR_BfuncA,ATemp1,ATemp2,1.d-100,HorizAsyntB,success)
        if (.not.success) then
            write(*,*) 'f(R) designer: vertical asyntote not found.'
            return
        end if

        write(*,*) 'f(R) designer: vertical asymptote =',  VertAsyntA

        ! 5) Find values for A that are on the left and on the right of the asyntote.
        do ind=-10, -1, 1
            ATemp1 = VertAsyntA+10._dl**ind
            ATemp2 = VertAsyntA-10._dl**ind
            BTemp1 = DesFR_BfuncA(ATemp1)
            BTemp2 = DesFR_BfuncA(ATemp2)
            if (BTemp1*BTemp2<0._dl) exit
        end do

        ! 6) Extablish on which side of the asyntote to look for the solution.
        ATemp3 = ATemp1
        ATemp4 = ATemp2
        do ind=1, 10, 1
            ATemp3 = ATemp3 + 10._dl**ind
            ATemp4 = ATemp4 - 10._dl**ind
            BTemp3 = DesFR_BfuncA(ATemp3)
            BTemp4 = DesFR_BfuncA(ATemp4)
            if ((BTemp1-self%B0)*(BTemp3-self%B0)<0.or.(BTemp2-self%B0)*(BTemp4-self%B0)<0) exit
        end do
        if ((BTemp1-self%B0)*(BTemp3-self%B0)<0.and.(BTemp2-self%B0)*(BTemp4-self%B0)<0) then
            write(*,*) 'f(R) designer: the root is on both side ???'
            stop
        end if

        ! 7) Solve the equation B0(A)=B0_wanted.
        if ((BTemp1-self%B0)*(BTemp3-self%B0)<0) then
            realAp = zbrent(DesFR_BfuncA,ATemp1,ATemp3,1.d-50,self%B0,success)
            if (.not.success) then
                write(*,*) 'f(R) designer: right side solution not found.'
                stop
            end if
        else if ((BTemp2-self%B0)*(BTemp4-self%B0)<0) then
            realAp = zbrent(DesFR_BfuncA,ATemp2,ATemp4,1.d-50,self%B0,success)
            if (.not.success) then
                write(*,*) 'f(R) designer: right side solution not found'
                stop
            end if
        else
            write(*,*) 'f(R) designer: the root was not on the right side nor the left one...'
            stop
        end if

        write(*,*) 'f(R) designer: initial condition A =', realAp

        ! 8) Check if the result found is compatible with the requested one. This is required only for debug.
        BTemp1 = DesFR_BfuncA(realAp)
        write(*,*) 'f(R) designer: B0 found=', BTemp1, 'B0 given= ',self%B0

        if (ABS(BTemp1-self%B0)/ABS(self%B0)>0.1_dl.and.ABS(BTemp1-self%B0)>1.d-8.and..false.) then
            write(*,*)  'EFTCAMB: designer code unable to find appropriate initial conditions'
            success = .false.
            return
        end if

        ! 9) output the value:
        A_ini = realAp

        return

    contains

        ! ---------------------------------------------------------------------------------------------
        !> Function that solves the designer f(R) equations and returns the present value of B0
        function DesFR_BfuncA(A)

            implicit none

            real(dl) :: A            !< input amplitude of the particular solution
            real(dl) :: DesFR_BfuncA !< value of B0
            real(dl) :: B0

            call self%solve_designer_equations( params_cache, A, B0, only_B0=.True. )

            DesFR_BfuncA = B0

        end function

    end subroutine EFTCAMBDesignerFRFindInitialConditions

    ! ---------------------------------------------------------------------------------------------
    !> Subroutine that computes the number of parameters of the model.
    subroutine EFTCAMBDesignerFRComputeParametersNumber( self )

        implicit none

        class(EFTCAMB_fR_designer)  :: self   !< the base class

        self%parameter_number = 1
        self%parameter_number = self%parameter_number +self%PureEFTwDE%parameter_number

    end subroutine EFTCAMBDesignerFRComputeParametersNumber

    ! ---------------------------------------------------------------------------------------------
    !> Subroutine that prints on the screen feedback information about the model.
    subroutine EFTCAMBDesignerFRFeedback( self )

        implicit none

        class(EFTCAMB_fR_designer)  :: self   !< the base class

        write(*,*)
        write(*,'(a,a)')    '   Model               =  ', self%name
        write(*,'(a,I3)')   '   Number of params    ='  , self%parameter_number
        ! print model functions informations:
        if ( self%EFTwDE /= 0 ) then
            write(*,*)
            write(*,'(a,I3)')  '   EFTwDE              =', self%EFTwDE
        end if
        write(*,*)
        write(*,'(a24,F12.6)') '   B0                  =', self%B0

        call self%PureEFTwDE%feedback()

    end subroutine EFTCAMBDesignerFRFeedback

    ! ---------------------------------------------------------------------------------------------
    !> Subroutine that returns the i-th parameter name of the model
    subroutine EFTCAMBDesignerFRParameterNames( self, i, name )

        implicit none

        class(EFTCAMB_fR_designer)  :: self   !< the base class
        integer     , intent(in)    :: i      !< the index of the parameter
        character(*), intent(out)   :: name   !< the output name of the i-th parameter

        stop 'IW: EFTCAMBDesignerFRParameterNames'

    end subroutine EFTCAMBDesignerFRParameterNames

    ! ---------------------------------------------------------------------------------------------
    !> Subroutine that returns the i-th parameter name of the model
    subroutine EFTCAMBDesignerFRParameterNamesLatex( self, i, latexname )

        implicit none

        class(EFTCAMB_fR_designer) :: self       !< the base class
        integer     , intent(in)    :: i          !< The index of the parameter
        character(*), intent(out)   :: latexname  !< the output latex name of the i-th parameter

        stop 'IW: EFTCAMBDesignerFRParameterNamesLatex'

    end subroutine EFTCAMBDesignerFRParameterNamesLatex

    ! ---------------------------------------------------------------------------------------------
    !> Subroutine that returns the i-th parameter name of the model
    subroutine EFTCAMBDesignerFRParameterValues( self, i, value )

        implicit none

        class(EFTCAMB_fR_designer) :: self   !< the base class
        integer , intent(in)        :: i      !< The index of the parameter
        real(dl), intent(out)       :: value  !< the output value of the i-th parameter

        stop 'IW: EFTCAMBDesignerFRParameterValues'

    end subroutine EFTCAMBDesignerFRParameterValues

    ! ---------------------------------------------------------------------------------------------
    !> Subroutine that computes the value of the background EFT functions at a given time.
    subroutine EFTCAMBDesignerFRBackgroundEFTFunctions( self, a, eft_par_cache, eft_cache )

        implicit none

        class(EFTCAMB_fR_designer)                  :: self          !< the base class
        real(dl), intent(in)                         :: a             !< the input scale factor
        type(EFTCAMB_parameter_cache), intent(inout) :: eft_par_cache !< the EFTCAMB parameter cache that contains all the physical parameters.
        type(EFTCAMB_timestep_cache ), intent(inout) :: eft_cache     !< the EFTCAMB timestep cache that contains all the physical values.

        real(dl) :: x

        x = log(a)

        eft_cache%EFTOmegaV    = self%EFTOmega%value(x)
        eft_cache%EFTOmegaP    = self%EFTOmega%first_derivative(x)
        eft_cache%EFTOmegaPP   = self%EFTOmega%second_derivative(x)
        eft_cache%EFTOmegaPPP  = self%EFTOmega%third_derivative(x)
        eft_cache%EFTc         = 0._dl
        eft_cache%EFTLambda    = self%EFTLambda%value(x)
        eft_cache%EFTcdot      = 0._dl
        eft_cache%EFTLambdadot = self%EFTLambda%first_derivative(x)

    end subroutine EFTCAMBDesignerFRBackgroundEFTFunctions

    ! ---------------------------------------------------------------------------------------------
    !> Subroutine that computes the value of the background EFT functions at a given time.
    subroutine EFTCAMBDesignerFRSecondOrderEFTFunctions( self, a, eft_par_cache, eft_cache )

        implicit none

        class(EFTCAMB_fR_designer)                  :: self          !< the base class
        real(dl), intent(in)                         :: a             !< the input scale factor
        type(EFTCAMB_parameter_cache), intent(inout) :: eft_par_cache !< the EFTCAMB parameter cache that contains all the physical parameters.
        type(EFTCAMB_timestep_cache ), intent(inout) :: eft_cache     !< the EFTCAMB timestep cache that contains all the physical values.

        eft_cache%EFTGamma1V  = 0._dl
        eft_cache%EFTGamma1P  = 0._dl
        eft_cache%EFTGamma2V  = 0._dl
        eft_cache%EFTGamma2P  = 0._dl
        eft_cache%EFTGamma3V  = 0._dl
        eft_cache%EFTGamma3P  = 0._dl
        eft_cache%EFTGamma4V  = 0._dl
        eft_cache%EFTGamma4P  = 0._dl
        eft_cache%EFTGamma4PP = 0._dl
        eft_cache%EFTGamma5V  = 0._dl
        eft_cache%EFTGamma5P  = 0._dl
        eft_cache%EFTGamma6V  = 0._dl
        eft_cache%EFTGamma6P  = 0._dl

    end subroutine EFTCAMBDesignerFRSecondOrderEFTFunctions

    ! ---------------------------------------------------------------------------------------------
    !> Function that computes dtauda = 1/sqrt(a^2H^2).For pure EFT std this has to be overridden
    !! for performance reasons.
    function EFTCAMBDesignerFRComputeDtauda( self, a, eft_par_cache, eft_cache )

        implicit none

        class(EFTCAMB_fR_designer)                  :: self          !< the base class
        real(dl), intent(in)                         :: a             !< the input scale factor
        type(EFTCAMB_parameter_cache), intent(inout) :: eft_par_cache !< the EFTCAMB parameter cache that contains all the physical parameters.
        type(EFTCAMB_timestep_cache ), intent(inout) :: eft_cache     !< the EFTCAMB timestep cache that contains all the physical values.

        real(dl) :: EFTCAMBDesignerFRComputeDtauda               !< the output dtauda

        real(dl) :: temp

        temp = eft_cache%grhoa2 +eft_par_cache%grhov*a*a*self%PureEFTwDE%integral(a)
        EFTCAMBDesignerFRComputeDtauda = sqrt(3/temp)

    end function EFTCAMBDesignerFRComputeDtauda

    ! ---------------------------------------------------------------------------------------------
    !> Subroutine that computes adotoa = H and its two derivatives wrt conformal time.
    subroutine EFTCAMBDesignerFRComputeAdotoa( self, a, eft_par_cache, eft_cache )

        implicit none

        class(EFTCAMB_fR_designer)                  :: self          !< the base class
        real(dl), intent(in)                         :: a             !< the input scale factor
        type(EFTCAMB_parameter_cache), intent(inout) :: eft_par_cache !< the EFTCAMB parameter cache that contains all the physical parameters.
        type(EFTCAMB_timestep_cache ), intent(inout) :: eft_cache     !< the EFTCAMB timestep cache that contains all the physical values.

        eft_cache%grhov_t = eft_par_cache%grhov*self%PureEFTwDE%integral(a)
        eft_cache%adotoa  = sqrt( ( eft_cache%grhom_t +eft_cache%grhov_t )/3._dl )

    end subroutine EFTCAMBDesignerFRComputeAdotoa

    ! ---------------------------------------------------------------------------------------------
    !> Subroutine that computes the two derivatives wrt conformal time of H.
    subroutine EFTCAMBDesignerFRComputeHubbleDer( self, a, eft_par_cache, eft_cache )

        implicit none

        class(EFTCAMB_fR_designer)                  :: self          !< the base class
        real(dl), intent(in)                         :: a             !< the input scale factor
        type(EFTCAMB_parameter_cache), intent(inout) :: eft_par_cache !< the EFTCAMB parameter cache that contains all the physical parameters.
        type(EFTCAMB_timestep_cache ), intent(inout) :: eft_cache     !< the EFTCAMB timestep cache that contains all the physical values.

        eft_cache%gpiv_t  = self%PureEFTwDE%value(a)*eft_cache%grhov_t
        eft_cache%Hdot    = -0.5_dl*( eft_cache%adotoa**2 +eft_cache%gpresm_t +eft_cache%gpiv_t )

        ! IW POSSIBLE BUG
        !eft_cache%Hdotdot = eft_cache%adotoa*( ( eft_cache%grhob_t +eft_cache%grhoc_t)/6._dl +2._dl*( eft_cache%grhor_t +eft_cache%grhog_t)/3._dl ) &
        !    & +eft_cache%adotoa*eft_cache%grhov_t*( 1._dl/6._dl +self%PureEFTwDE%value(a) +1.5_dl*self%PureEFTwDE%value(a)**2 -0.5_dl*a*self%PureEFTwDE%first_derivative(a) ) &
        !    & +eft_cache%adotoa*eft_cache%grhonu_tot/6._dl -0.5_dl*eft_cache%adotoa*eft_cache%gpinu_tot -0.5_dl*eft_cache%gpinudot_tot

        eft_cache%Hdotdot = 2._dl*eft_cache%adotoa*eft_cache%Hdot &
            & + 0.5_dl*eft_cache%adotoa*(eft_cache%grhob_t + eft_cache%grhoc_t + 8._dl*(eft_cache%grhog_t+eft_cache%grhor_t)/3._dl)&
            & + 0.5_dl*eft_cache%adotoa*eft_cache%grhov_t*( (1._dl+self%PureEFTwDE%value(a) )*(1._dl+3._dl*self%PureEFTwDE%value(a)) -a*self%PureEFTwDE%first_derivative(a))&
            & + eft_cache%adotoa/6._dl*eft_cache%grhonu_tot -0.5_dl*eft_cache%adotoa*eft_cache%gpinu_tot -0.5_dl*eft_cache%gpinudot_tot

    end subroutine EFTCAMBDesignerFRComputeHubbleDer

    ! ---------------------------------------------------------------------------------------------

end module EFTCAMB_designer_fR

!----------------------------------------------------------------------------------------
