! fplot_plot_3d.f90

submodule (fplot_core) fplot_plot_3d
contains
! ------------------------------------------------------------------------------
    !> @brief Cleans up resources held by the plot_3d object.
    !!
    !! @param[in,out] this The plot_3d object.
    module subroutine p3d_clean_up(this)
        type(plot_3d), intent(inout) :: this
        call this%free_resources()
        if (associated(this%m_xAxis)) then
            deallocate(this%m_xAxis)
            nullify(this%m_xAxis)
        end if
        if (associated(this%m_yAxis)) then
            deallocate(this%m_yAxis)
            nullify(this%m_yAxis)
        end if
        if (associated(this%m_zAxis)) then
            deallocate(this%m_zAxis)
            nullify(this%m_zAxis)
        end if
    end subroutine

! ------------------------------------------------------------------------------
    !> @brief Initializes the plot_3d object.
    !!
    !! @param[in] this The plot_3d object.
    !! @param[in] term An optional input that is used to define the terminal.
    !!  The default terminal is a WXT terminal.  The acceptable inputs are:
    !!  - GNUPLOT_TERMINAL_PNG
    !!  - GNUPLOT_TERMINAL_QT
    !!  - GNUPLOT_TERMINAL_WIN32
    !!  - GNUPLOT_TERMINAL_WXT
    !!  - GNUPLOT_TERMINAL_LATEX
    !! @param[out] err An optional errors-based object that if provided can be
    !!  used to retrieve information relating to any errors encountered during
    !!  execution.  If not provided, a default implementation of the errors
    !!  class is used internally to provide error handling.  Possible errors and
    !!  warning messages that may be encountered are as follows.
    !! - PLOT_OUT_OF_MEMORY_ERROR: Occurs if insufficient memory is available.
    module subroutine p3d_init(this, term, err)
        ! Arguments
        class(plot_3d), intent(inout) :: this
        integer(int32), intent(in), optional :: term
        class(errors), intent(inout), optional, target :: err

        ! Local Variables
        integer(int32) :: flag
        class(errors), pointer :: errmgr
        type(errors), target :: deferr

        ! Initialization
        if (present(err)) then
            errmgr => err
        else
            errmgr => deferr
        end if

        ! Initialize the base class
        call plt_init(this, term, errmgr)
        if (errmgr%has_error_occurred()) return

        ! Process
        flag = 0
        if (.not.associated(this%m_xAxis)) then
            allocate(this%m_xAxis, stat = flag)
        end if
        if (flag == 0 .and. .not.associated(this%m_yAxis)) then
            allocate(this%m_yAxis, stat = flag)
        end if
        if (flag == 0 .and. .not.associated(this%m_zAxis)) then
            allocate(this%m_zAxis, stat = flag)
        end if

        ! Error Checking
        if (flag /= 0) then
            call errmgr%report_error("p3d_init", &
                "Insufficient memory available.", PLOT_OUT_OF_MEMORY_ERROR)
            return
        end if
    end subroutine

! ------------------------------------------------------------------------------
    !> @brief Gets the GNUPLOT command string to represent this plot_3d
    !! object.
    !!
    !! @param[in] this The plot_3d object.
    !! @return The command string.
    module function p3d_get_cmd(this) result(x)
        ! Arguments
        class(plot_3d), intent(in) :: this
        character(len = :), allocatable :: x

        ! Local Variables
        type(string_builder) :: str
        integer(int32) :: i, n
        class(plot_data), pointer :: ptr
        class(plot_axis), pointer :: xAxis, yAxis, zAxis
        class(terminal), pointer :: term
        type(legend), pointer :: leg

        ! Initialization
        call str%initialize()

        ! Write the terminal commands
        term => this%get_terminal()
        call str%append(term%get_command_string())

        ! Grid
        if (this%get_show_gridlines()) then
            call str%append(new_line('a'))
            call str%append("set grid")
        end if

        ! Title
        n = len_trim(this%get_title())
        if (n > 0) then
            call str%append(new_line('a'))
            call str%append('set title "')
            call str%append(this%get_title())
            call str%append('"')
        end if

        ! Axes
        call str%append(new_line('a'))
        xAxis => this%get_x_axis()
        if (associated(xAxis)) call str%append(xAxis%get_command_string())

        call str%append(new_line('a'))
        yAxis => this%get_y_axis()
        if (associated(yAxis)) call str%append(yAxis%get_command_string())

        call str%append(new_line('a'))
        zAxis => this%get_z_axis()
        if (associated(zAxis)) call str%append(zAxis%get_command_string())

        ! Tic Marks
        if (.not.this%get_tics_inward()) then
            call str%append(new_line('a'))
            call str%append("set tics out")
        end if
        if (xAxis%get_zero_axis() .or. yAxis%get_zero_axis() .or. &
                zAxis%get_zero_axis()) then
            call str%append(new_line('a'))
            call str%append("set tics axis")
        end if

        ! Border
        if (this%get_draw_border()) then
            n = 31
        else
            n = 0
            if (.not.xAxis%get_zero_axis()) n = n + 1
            if (.not.yAxis%get_zero_axis()) n = n + 4
            if (.not.zAxis%get_zero_axis()) n = n + 16

            call str%append(new_line('a'))
            call str%append("set xtics nomirror")
            call str%append(new_line('a'))
            call str%append("set ytics nomirror")
            call str%append(new_line('a'))
            call str%append("set ztics nomirror")
        end if
        call str%append(new_line('a'))
        if (n > 0) then
            call str%append("set border ")
            call str%append(to_string(n))
        else
            call str%append("unset border")
        end if

        ! Force the z-axis to move to the x-y plane
        if (this%get_z_intersect_xy()) then
            call str%append(new_line('a'))
            call str%append("set ticslevel 0")
        end if

        ! Legend
        call str%append(new_line('a'))
        leg => this%get_legend()
        if (associated(leg)) call str%append(leg%get_command_string())

        ! Orientation
        call str%append(new_line('a'))
        call str%append("set view ")
        call str%append(to_string(this%get_elevation()))
        call str%append(",")
        call str%append(to_string(this%get_azimuth()))

        ! Define the plot function and data formatting commands
        n = this%get_count()
        call str%append(new_line('a'))
        call str%append("splot ")
        do i = 1, n
            ptr => this%get(i)
            if (.not.associated(ptr)) cycle
            call str%append(ptr%get_command_string())
            if (i /= n) call str%append(", ")
        end do

        ! Define the data to plot
        do i = 1, n
            ptr => this%get(i)
            if (.not.associated(ptr)) cycle
            call str%append(new_line('a'))
            call str%append(ptr%get_data_string())
            if (i /= n) then
                call str%append("e")
            end if
        end do

        ! End
        x = str%to_string()
    end function

! ------------------------------------------------------------------------------
    !> @brief Gets the x-axis object.
    !!
    !! @param[in] this The plot_3d object.
    !! @return A pointer to the x-axis object.
    module function p3d_get_x_axis(this) result(ptr)
        class(plot_3d), intent(in) :: this
        class(plot_axis), pointer :: ptr
        ptr => this%m_xAxis
    end function

! ------------------------------------------------------------------------------
    !> @brief Gets the y-axis object.
    !!
    !! @param[in] this The plot_3d object.
    !! @return A pointer to the y-axis object.
    module function p3d_get_y_axis(this) result(ptr)
        class(plot_3d), intent(in) :: this
        class(plot_axis), pointer :: ptr
        ptr => this%m_yAxis
    end function

! ------------------------------------------------------------------------------
    !> @brief Gets the z-axis object.
    !!
    !! @param[in] this The plot_3d object.
    !! @return A pointer to the z-axis object.
    module function p3d_get_z_axis(this) result(ptr)
        class(plot_3d), intent(in) :: this
        class(plot_axis), pointer :: ptr
        ptr => this%m_zAxis
    end function

! ------------------------------------------------------------------------------
    !> @brief Gets the plot elevation angle.
    !!
    !! @param[in] this The plot_3d object.
    !! @return The elevation angle, in degrees.
    pure module function p3d_get_elevation(this) result(x)
        class(plot_3d), intent(in) :: this
        real(real64) :: x
        x = this%m_elevation
    end function

! --------------------
    !> @brief Sets the plot elevation angle.
    !!
    !! @param[in,out] this The plot_3d object.
    !! @param[in] x The elevation angle, in degrees.
    module subroutine p3d_set_elevation(this, x)
        class(plot_3d), intent(inout) :: this
        real(real64), intent(in) :: x
        this%m_elevation = x
    end subroutine

! ------------------------------------------------------------------------------
    !> @brief Gets the plot azimuth angle.
    !!
    !! @param[in] this The plot_3d object.
    !! @return The azimuth angle, in degrees.
    pure module function p3d_get_azimuth(this) result(x)
        class(plot_3d), intent(in) :: this
        real(real64) :: x
        x = this%m_azimuth
    end function

! --------------------
    !> @brief Sets the plot azimuth angle.
    !!
    !! @param[in,out] this The plot_3d object.
    !! @param[in] x The azimuth angle, in degrees.
    module subroutine p3d_set_azimuth(this, x)
        class(plot_3d), intent(inout) :: this
        real(real64), intent(in) :: x
        this%m_azimuth = x
    end subroutine

! ------------------------------------------------------------------------------
    !> @brief Gets a value determining if the z-axis should intersect the x-y 
    !! plane.
    !!
    !! @param[in] this The plot_3d object.
    !! @return Returns true if the z-axis should intersect the x-y plane; else,
    !!  false to allow the z-axis to float.
    pure module function p3d_get_z_axis_intersect(this) result(x)
        class(plot_3d), intent(in) :: this
        logical :: x
        x = this%m_zIntersect
    end function

! --------------------
    !> @brief Sets a value determining if the z-axis should intersect the x-y 
    !! plane.
    !!
    !! @param[in,out] this The plot_3d object.
    !! @param[in] x Set to true if the z-axis should intersect the x-y plane; 
    !!  else, false to allow the z-axis to float.
    module subroutine p3d_set_z_axis_intersect(this, x)
        class(plot_3d), intent(inout) :: this
        logical, intent(in) :: x
        this%m_zIntersect = x
    end subroutine

end submodule
