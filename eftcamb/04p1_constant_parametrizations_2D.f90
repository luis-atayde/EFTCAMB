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

!> @file 04p1_constant_parametrizations_2D.f90
!! This file contains the definition of the constant parametrization, inheriting from
!! parametrized_function_2D.


!----------------------------------------------------------------------------------------
!> This module contains the definition of the constant parametrization, inheriting from
!! parametrized_function_2D.

<<<<<<< HEAD
<<<<<<< HEAD
!> @author Simone Peirone, Bin Hu, Marco Raveri
=======
!> @author Bin Hu, Marco Raveri
>>>>>>> added constant parametrization for 2D functions
=======
!> @author Simone Peirone, Bin Hu, Marco Raveri
>>>>>>> Added name to @author list

module EFTCAMB_constant_parametrization_2D

    use precision
    use EFTDef
    use EFTCAMB_abstract_parametrizations_2D

    implicit none

    ! ---------------------------------------------------------------------------------------------
    !> Type containing the constant function parametrization. Inherits from parametrized_function_2D.
    !! Notice that the derivatives are not overridden since they are zero identically.
    type, extends ( parametrized_function_2D ) :: constant_parametrization_2D

        real(dl) :: constant_value

    contains

        ! initialization:
        procedure :: init                  => ConstantParametrized2DInitialize          !< subroutine that initializes the constant parametrization
        procedure :: init_from_file        => ConstantParametrized2DInitFromFile        !< subroutine that reads a Ini file looking for the parameters of the function.
        procedure :: init_parameters       => ConstantParametrized2DInit                !< subroutine that initializes the function parameters based on the values found in an input array.

        ! utility functions:
        procedure :: feedback              => ConstantParametrized2DFeedback            !< subroutine that prints to screen the informations about the function.
        procedure :: parameter_names       => ConstantParametrized2DParameterNames      !< subroutine that returns the i-th parameter name of the function
        procedure :: parameter_names_latex => ConstantParametrized2DParameterNamesLatex !< subroutine that returns the i-th parameter name of the function in latex format
        procedure :: parameter_value       => ConstantParametrized2DParameterValues     !< subroutine that returns the value of the function i-th parameter.

        ! evaluation procedures:
        procedure :: value                 => ConstantParametrized2DValue               !< function that returns the value of the function

    end type constant_parametrization_2D

contains

    ! ---------------------------------------------------------------------------------------------
    ! Implementation of the constant function.
    ! ---------------------------------------------------------------------------------------------

    ! ---------------------------------------------------------------------------------------------
    !> Subroutine that initializes the constant parametrization
    subroutine ConstantParametrized2DInitialize( self, name, latexname )

        implicit none

        class(constant_parametrization_2D) :: self       !< the base class
        character(*), intent(in)           :: name       !< the name of the function
        character(*), intent(in)           :: latexname  !< the latex name of the function

        ! store the name of the function:
        self%name             = TRIM( name )
        ! store the latex name of the function:
        self%name_latex       = TRIM( latexname )
        ! initialize the number of parameters:
        self%parameter_number = 1

    end subroutine ConstantParametrized2DInitialize

    ! ---------------------------------------------------------------------------------------------
    !> Subroutine that reads a Ini file looking for the parameters of the function.
    subroutine ConstantParametrized2DInitFromFile( self, Ini )

        implicit none

        class(constant_parametrization_2D) :: self   !< the base class
        type(TIniFile)                     :: Ini    !< Input ini file

        character(len=EFT_names_max_length) :: param_name

        call self%parameter_names( 1, param_name )

        self%constant_value = Ini_Read_Double_File( Ini, TRIM(param_name), 0._dl )

    end subroutine ConstantParametrized2DInitFromFile

    ! ---------------------------------------------------------------------------------------------
    !> Subroutine that initializes the function parameters based on the values found in an input array.
    subroutine ConstantParametrized2DInit( self, array )

        implicit none

        class(constant_parametrization_2D)                      :: self   !< the base class.
        real(dl), dimension(self%parameter_number), intent(in)  :: array  !< input array with the values of the parameters.

        self%constant_value = array(1)

    end subroutine ConstantParametrized2DInit

    ! ---------------------------------------------------------------------------------------------
    !> Subroutine that prints to screen the informations about the function.
    subroutine ConstantParametrized2DFeedback( self )

        implicit none

        class(constant_parametrization_2D)  :: self       !< the base class

        integer                             :: i
        real(dl)                            :: param_value
        character(len=EFT_names_max_length) :: param_name

        write(*,*)     'Constant function: ', self%name
        do i=1, self%parameter_number
            call self%parameter_names( i, param_name  )
            call self%parameter_value( i, param_value )
            write(*,'(a23,a,F12.6)') param_name, '=', param_value
        end do

    end subroutine ConstantParametrized2DFeedback

    ! ---------------------------------------------------------------------------------------------
    !> Subroutine that returns the i-th parameter name
    subroutine ConstantParametrized2DParameterNames( self, i, name )

        implicit none

        class(constant_parametrization_2D) :: self   !< the base class
        integer     , intent(in)           :: i      !< the index of the parameter
        character(*), intent(out)          :: name   !< the output name of the i-th parameter

        select case (i)
            case(1)
                name = TRIM(self%name)//'0'
            case default
                write(*,*) 'Illegal index for parameter_names.'
                write(*,*) 'Maximum value is:', self%parameter_number
                stop
        end select

    end subroutine ConstantParametrized2DParameterNames

    ! ---------------------------------------------------------------------------------------------
    !> Subroutine that returns the latex version of the i-th parameter name
    subroutine ConstantParametrized2DParameterNamesLatex( self, i, latexname )

        implicit none

        class(constant_parametrization_2D) :: self        !< the base class
        integer     , intent(in)           :: i           !< The index of the parameter
        character(*), intent(out)          :: latexname   !< the output latex name of the i-th parameter

        select case (i)
            case(1)
                latexname = TRIM(self%name_latex)//'_0'
            case default
                write(*,*) 'Illegal index for parameter_names.'
                write(*,*) 'Maximum value is:', self%parameter_number
                stop
        end select

    end subroutine ConstantParametrized2DParameterNamesLatex


    ! ---------------------------------------------------------------------------------------------
    !> Subroutine that returns the value of the function i-th parameter.
    subroutine ConstantParametrized2DParameterValues( self, i, value )

        implicit none

        class(constant_parametrization_2D) :: self        !< the base class
        integer     , intent(in)           :: i           !< The index of the parameter
        real(dl)    , intent(out)          :: value       !< the output value of the i-th parameter

        select case (i)
            case(1)
                value = self%constant_value
            case default
                write(*,*) 'Illegal index for parameter_names.'
                write(*,*) 'Maximum value is:', self%parameter_number
                stop
        end select

    end subroutine ConstantParametrized2DParameterValues

    ! ---------------------------------------------------------------------------------------------
    !> Function that returns the value of the constant function.
    function ConstantParametrized2DValue( self, x, y )

        implicit none

<<<<<<< HEAD
<<<<<<< HEAD
        class(constant_parametrization_2D) :: self  !< the base class
        real(dl), intent(in)               :: x     !< the first input variable
        real(dl), intent(in)               :: y     !< the second input variable
        real(dl) :: ConstantParametrized2DValue     !< the output value
=======
        class(constant_parametrization_1D) :: self  !< the base class
        real(dl), intent(in)               :: x     !< the first input scale factor
        real(dl), intent(in)               :: y     !< the second input scale factor
        real(dl) :: ConstantParametrized1DValue     !< the output value
>>>>>>> added constant parametrization for 2D functions
=======
        class(constant_parametrization_2D) :: self  !< the base class
        real(dl), intent(in)               :: x     !< the first input variable
        real(dl), intent(in)               :: y     !< the second input variable
        real(dl) :: ConstantParametrized2DValue     !< the output value
>>>>>>> corrected minor mistake

        ConstantParametrized2DValue = self%constant_value

    end function ConstantParametrized2DValue

    ! ---------------------------------------------------------------------------------------------

end module EFTCAMB_constant_parametrization_2D

!----------------------------------------------------------------------------------------
