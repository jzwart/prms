submodule (PRMS_GWFLOW) sm_gwflow
  contains

    module function constructor_Gwflow(ctl_data, model_basin, &
                                       model_climate, intcp, soil, runoff, basin_summary, nhru_summary) result(this)
      use prms_constants, only: dp, SWALE
      implicit none

      type(Gwflow) :: this
      type(Control), intent(in) :: ctl_data
      type(Basin), intent(in) :: model_basin
      type(Climateflow), intent(in) :: model_climate
      type(Interception), intent(in) :: intcp
      type(Soilzone), intent(in) :: soil
      type(Srunoff), intent(in) :: runoff
      type(Basin_summary_ptr), intent(inout) :: basin_summary
      type(Nhru_summary_ptr), intent(inout) :: nhru_summary

      ! Local Variables
      integer(i32) :: chru
      integer(i32) :: jj
      integer(i32) :: jjj

      ! Control
      ! nhru, nlake
      ! cascadegw_flag, dprst_flag, gwr_swale_flag, init_vars_from_file,
      ! lake_route_flag, print_debug

      ! Parameter
      ! elevlake_init, gwflow_coef, gwstor_init, gwstor_min, hru_area, lake_hru_id,

      ! Basin
      ! active_gwrs, basin_area_inv, gwr_route_order, gwr_type, weir_gate_flag

      ! Climateflow
      ! pkwater_equiv

      ! Interception
      ! hru_intcpstor

      ! Soilzone
      ! soil_moist_tot

      ! Srunoff
      ! dprst_stor_hru, hru_impervstor

      ! ------------------------------------------------------------------------
      associate(basinOutON_OFF => ctl_data%basinOutON_OFF%value, &
                basinOutVars => ctl_data%basinOutVars%value, &
                basinOutVar_names => ctl_data%basinOutVar_names%values, &
                cascadegw_flag => ctl_data%cascadegw_flag%value, &
                dprst_flag => ctl_data%dprst_flag%value, &
                gsflow_mode => ctl_data%gsflow_mode, &
                gwr_swale_flag => ctl_data%gwr_swale_flag%value, &
                init_vars_from_file => ctl_data%init_vars_from_file%value, &
                ! lake_route_flag => ctl_data%lake_route_flag%value, &
                nhruOutON_OFF => ctl_data%nhruOutON_OFF%value, &
                nhruOutVars => ctl_data%nhruOutVars%value, &
                nhruOutVar_names => ctl_data%nhruOutVar_names%values, &
                ! model_mode => ctl_data%model_mode%values, &
                param_hdl => ctl_data%param_file_hdl, &
                print_debug => ctl_data%print_debug%value, &
                strmflow_module => ctl_data%strmflow_module%values, &

                ! elevlake_init => param_data%elevlake_init%values, &
                ! gwflow_coef => param_data%gwflow_coef%values, &
                ! gwstor_init => param_data%gwstor_init%values, &
                ! gwstor_min => param_data%gwstor_min%values, &

                nhru => model_basin%nhru, &
                nlake => model_basin%nlake, &
                active_gwrs => model_basin%active_gwrs, &
                basin_area_inv => model_basin%basin_area_inv, &
                gwr_route_order => model_basin%gwr_route_order, &
                gwr_type => model_basin%gwr_type, &
                hru_area => model_basin%hru_area, &
                lake_hru_id => model_basin%lake_hru_id, &
                weir_gate_flag => model_basin%weir_gate_flag, &

                pkwater_equiv => model_climate%pkwater_equiv, &

                hru_intcpstor => intcp%hru_intcpstor, &

                soil_moist_tot => soil%soil_moist_tot, &

                dprst_stor_hru => runoff%dprst_stor_hru, &
                hru_impervstor => runoff%hru_impervstor)

        call this%set_module_info(name=MODNAME, desc=MODDESC, version=MODVERSION)

        if (print_debug > -2) then
          ! Output module and version information
          call this%print_module_info()
        endif

        ! Dimensions
        this%ngw = param_hdl%get_dimension('ngw')
        if (this%ngw == 0) then
          this%ngw = nhru
        endif

        ! Parameters
        allocate(this%gwflow_coef(this%ngw))
        call param_hdl%get_variable('gwflow_coef', this%gwflow_coef)

        allocate(this%gwsink_coef(this%ngw))
        call param_hdl%get_variable('gwsink_coef', this%gwsink_coef)

        allocate(this%gwstor_init(this%ngw))
        call param_hdl%get_variable('gwstor_init', this%gwstor_init)

        allocate(this%gwstor_min(this%ngw))
        call param_hdl%get_variable('gwstor_min', this%gwstor_min)

        if (weir_gate_flag == 1) then
          allocate(this%elevlake_init(this%ngw))
          call param_hdl%get_variable('elevlake_init', this%elevlake_init)

          allocate(this%gw_seep_coef(this%ngw))
          call param_hdl%get_variable('gw_seep_coef', this%gw_seep_coef)

          allocate(this%lake_seep_elev(nlake))
          call param_hdl%get_variable('lake_seep_elev', this%lake_seep_elev)
        end if

        ! Other variables
        if (cascadegw_flag > 0) then
          allocate(this%gw_upslope(nhru))
          allocate(this%hru_gw_cascadeflow(nhru))
        endif

        allocate(this%gw_in_soil(nhru))
        allocate(this%gw_in_ssr(nhru))
        allocate(this%gwres_flow(nhru))
        allocate(this%gwres_in(nhru))
        allocate(this%gwres_sink(nhru))
        allocate(this%gwres_stor(nhru))   ! moved from flowvars
        ! allocate(this%gwstor_minarea(nhru))
        allocate(this%gwstor_minarea_wb(nhru))
        allocate(this%hru_lateral_flow(nhru))
        allocate(this%hru_storage(nhru))
        allocate(this%hru_streamflow_out(nhru))

        if (dprst_flag == 1) then
          allocate(this%gwin_dprst(nhru))
        endif

        ! if (nlake > 0 .and. strmflow_module(1)%s == 'muskingum_lake' .and. model_mode(1)%s /= 'GSFLOW') then
        if (nlake > 0 .and. strmflow_module(1)%s == 'muskingum_lake' .and. .not. gsflow_mode) then
        ! if (lake_route_flag == 1) then
          allocate(this%lake_seepage(nlake))
          allocate(this%lake_seepage_max(nlake))
          allocate(this%gw_seep_lakein(nlake))
          allocate(this%lake_seepage_gwr(nhru))
          allocate(this%elevlake(nlake))
        endif

        allocate(this%basin_dnflow)
        allocate(this%basin_gw_upslope)
        allocate(this%basin_gwflow)
        allocate(this%basin_gwin)
        allocate(this%basin_gwsink)
        allocate(this%basin_gwstor)
        allocate(this%basin_gwstor_minarea_wb)
        allocate(this%basin_lake_seep)

        ! Connect any basin summary variables that need to be output
        if (basinOutON_OFF == 1) then
          do jj = 1, basinOutVars
            ! TODO: This is where the daily basin values are linked based on
            !       what was requested in basinOutVar_names.
            select case(basinOutVar_names(jj)%s)
              case('basin_gwflow')
                call basin_summary%set_basin_var(jj, this%basin_gwflow)
              case('basin_gwstor')
                call basin_summary%set_basin_var(jj, this%basin_gwstor)
              case('basin_gwin')
                call basin_summary%set_basin_var(jj, this%basin_gwin)
              case('basin_gwsink')
                call basin_summary%set_basin_var(jj, this%basin_gwsink)
              case('basin_gwstor_minarea_wb')
                call basin_summary%set_basin_var(jj, this%basin_gwstor_minarea_wb)
              case('basin_lake_seep')
                call basin_summary%set_basin_var(jj, this%basin_lake_seep)
              case('basin_gw_upslope')
                call basin_summary%set_basin_var(jj, this%basin_gw_upslope)
              case('basin_dnflow')
                call basin_summary%set_basin_var(jj, this%basin_dnflow)
              case default
                ! pass
            end select
          enddo
        endif

        ! Initialize
        this%gwres_stor = 0.0_dp  ! moved from flowvars

        ! this%gwminarea_flag = 0
        ! this%gwstor_minarea = 0.0_dp
        this%gwstor_minarea_wb = 0.0_dp
        this%basin_gwstor_minarea_wb = 0.0_dp

        if (init_vars_from_file == 0 .or. init_vars_from_file == 2 .or. init_vars_from_file == 6) then
          do chru=1, nhru
            this%gwres_stor(chru) = dble(this%gwstor_init(chru))
          enddo
        endif

        ! Lakes (moved from flowvars)
        if (nlake > 0) then
          allocate(this%lake_vol(nlake))
          this%lake_vol = 0.0_dp
        endif

        this%hru_storage = 0.0_dp
        this%basin_gwstor = 0.0_dp

        this%has_gwstor_minarea = .false.
        if (any(this%gwstor_min > 0.0_r32)) then
          this%has_gwstor_minarea = .true.
          allocate(this%gwstor_minarea(nhru))
          this%gwstor_minarea = dble(this%gwstor_min * hru_area)
        endif

        do jj = 1, active_gwrs
          chru = gwr_route_order(jj)
          this%basin_gwstor = this%basin_gwstor + this%gwres_stor(chru) * dble(hru_area(chru))

          if (this%gwflow_coef(chru) > 1.0) then
            if (print_debug > -1) print *, 'WARNING, gwflow_coef value > 1.0 for GWR:', chru, this%gwflow_coef(chru)
          endif

          ! TODO: Uncomment once gwr_type has been created in parameter file
          ! GWR's cannot be swales unless gwr_swale_flag > 0
          ! if (gwr_type(chru) == SWALE) then
          !   ! NOTE: rsr, may need to add gwr_type and gwr_segment
          !   if (gwr_swale_flag == 0) then
          !     print *, 'ERROR, GWRs cannot be swales when gwr_swale_flag = 0, GWR:', chru
          !   elseif (gwr_swale_flag == 1) then
          !     if (print_debug > -1) print *, 'WARNING, GWR:', chru, ' is treated as a swale, flow sent to sink'
          !   elseif (gwr_swale_flag == 2) then
          !     if (print_debug > -1) print *, 'WARNING, GWR:', chru, &
          !                                    ' is treated as a swale, flow sent to basin_cfs and hru_segment if > 0'
          !   else
          !     ! maybe gwr_swale_flag = 3 abs(hru_segment) so hru_segment could be changed from 0 to allow HRU swales
          !     print *, 'ERROR, invalid gwr_swale_flag value, specified as:', gwr_swale_flag
          !   endif
          ! endif

          this%hru_storage(chru) = dble(soil_moist_tot(chru) + hru_intcpstor(chru) + hru_impervstor(chru)) + &
                                this%gwres_stor(chru) + pkwater_equiv(chru)

          if (dprst_flag == 1) then
            this%hru_storage(chru) = this%hru_storage(chru) + dprst_stor_hru(chru)
          endif
        enddo

        this%basin_gwstor = this%basin_gwstor * basin_area_inv

        if (dprst_flag == 1) then
          this%gwin_dprst = 0.0_dp
        endif

        if (weir_gate_flag == 1) then
          if (init_vars_from_file == 0 .or. init_vars_from_file == 2 .or. init_vars_from_file == 4) then
            this%elevlake = this%elevlake_init
          endif

          this%lake_seepage_max = 0.0_dp

          if (init_vars_from_file == 0) then
            this%lake_seepage_gwr = 0.0_dp
            this%lake_seepage = 0.0_dp
            this%gw_seep_lakein = 0.0_dp
          endif

          ! TODO: Uncomment once gwr_type is created in parameter file
          ! do chru=1, active_gwrs
          !   j = gwr_route_order(chru)
          !
          !   if (gwr_type(j) == 2) then
          !     jjj = lake_hru_id(j)
          !
          !     if (jjj == 0) then
          !       print *, 'ERROR, GWR specified as a lake but lake_hru_id value = 0, GWR:', j
          !       CYCLE
          !     endif
          !   endif
          ! enddo
        endif

        if (init_vars_from_file == 0) then
           this%basin_gwflow = 0.0_dp
           this%basin_gwsink = 0.0_dp
           this%basin_gwin = 0.0_dp
           this%basin_gw_upslope = 0.0_dp
           this%basin_dnflow = 0.0_dp
           this%basin_lake_seep = 0.0_dp
        endif

        ! Do only once, so restart uses saved values
        if (cascadegw_flag > 0) then
           this%gw_upslope = 0.0_dp
           this%hru_gw_cascadeflow = 0.0
        endif

        this%gwres_flow = 0.0_dp
        this%gwres_in = 0.0_dp
        this%gwres_sink = 0.0_dp
        this%gw_in_ssr = 0.0_dp
        this%gw_in_soil = 0.0_dp
        this%hru_streamflow_out = 0.0_dp
        this%hru_lateral_flow = 0.0_dp

        ! Connect any nhru_summary variables that need to be output
        if (nhruOutON_OFF == 1) then
          do jj=1, nhruOutVars
            select case(nhruOutVar_names(jj)%s)
              case('gw_in_soil')
                call nhru_summary%set_nhru_var(jj, this%gw_in_soil)
              case('gw_in_ssr')
                call nhru_summary%set_nhru_var(jj, this%gw_in_ssr)
              case('gwres_flow')
                call nhru_summary%set_nhru_var(jj, this%gwres_flow)
              case('gwres_in')
                call nhru_summary%set_nhru_var(jj, this%gwres_in)
              case('hru_lateral_flow')
                call nhru_summary%set_nhru_var(jj, this%hru_lateral_flow)
              case('hru_storage')
                call nhru_summary%set_nhru_var(jj, this%hru_storage)
              case('hru_streamflow_out')
                call nhru_summary%set_nhru_var(jj, this%hru_streamflow_out)
              case default
                ! pass
            end select
          enddo
        endif
      end associate
    end function



    module subroutine run_Gwflow(this, ctl_data, model_basin, &
                                   model_climate, intcp, soil, runoff, model_time)
      ! USE PRMS_WATER_USE, ONLY: gwr_transfers_on, gwr_transfer, gwr_gain
      use iso_fortran_env, only: output_unit
      use prms_constants, only: dp, LAKE, BCWEIR, GATEOP, SWALE, DNEARZERO
      implicit none

      class(Gwflow), intent(inout) :: this
      type(Control), intent(in) :: ctl_data
      type(Basin), intent(in) :: model_basin
      ! type(Cascade), intent(in) :: model_cascade
      type(Climateflow), intent(in) :: model_climate
      type(Interception), intent(in) :: intcp
      type(Soilzone), intent(in) :: soil
      type(Srunoff), intent(in) :: runoff
      type(Time_t), intent(in) :: model_time

      ! Local Variables
      integer(i32) :: chru
      integer(i32) :: j
      integer(i32) :: jj
      integer(i32) :: jjj

      ! TODO: Uncomment when cascade module is converted
      ! real(r32) :: dnflow

      ! real(r64) :: gwarea
      real(r64) :: gwflow
      real(r64) :: gwin
      real(r64) :: gwsink
      real(r64) :: gwstor
      real(r64) :: gwstor_last

      ! TODO: Uncomment next 2 when cascade module is converted
      ! real(r64) :: inch2acre_feet
      ! real(r64) :: seepage

      ! Control
      ! cascadegw_flag, dprst_flag, gwr_swale_flag, print_debug,

      ! Parameter
      ! gwflow_coef, gwsink_coef, gw_seep_coef, gwr_type, hru_area, lake_hru_id,
      ! lake_seep_elev, lake_type,

      ! Basin
      ! active_gwrs, basin_area_inv, gwr_route_order, hru_area_dble, weir_gate_flag,

      ! Cascade
      ! ncascade_gwr,

      ! Climateflow
      ! pkwater_equiv

      ! Interception
      ! hru_intcpstor

      ! Soilzone
      ! soil_moist_tot, ssres_flow, soil_to_gw, ssr_to_gw,

      ! Srunoff
      ! dprst_seep_hru, dprst_stor_hru, hru_impervstor, sroff,

      ! Time_t
      ! cfs_conv

      ! water_used_read
      ! gwr_gain, gwr_transfer, gwr_transfers_on,

      ! ------------------------------------------------------------------------
      associate(cascadegw_flag => ctl_data%cascadegw_flag%value, &
                dprst_flag => ctl_data%dprst_flag%value, &
                gwr_swale_flag => ctl_data%gwr_swale_flag%value, &
                print_debug => ctl_data%print_debug%value, &

                active_gwrs => model_basin%active_gwrs, &
                basin_area_inv => model_basin%basin_area_inv, &
                gwr_route_order => model_basin%gwr_route_order, &
                hru_area => model_basin%hru_area, &
                hru_area_dble => model_basin%hru_area_dble, &
                lake_hru_id => model_basin%lake_hru_id, &
                lake_type => model_basin%lake_type, &
                weir_gate_flag => model_basin%weir_gate_flag, &

                ! ncascade_gwr => model_cascade%ncascade_gwr, &

                pkwater_equiv => model_climate%pkwater_equiv, &

                hru_intcpstor => intcp%hru_intcpstor, &

                soil_moist_tot => soil%soil_moist_tot, &
                soil_to_gw => soil%soil_to_gw, &
                ssr_to_gw => soil%ssr_to_gw, &
                ssres_flow => soil%ssres_flow, &

                dprst_seep_hru => runoff%dprst_seep_hru, &
                dprst_stor_hru => runoff%dprst_stor_hru, &
                hru_impervstor => runoff%hru_impervstor, &
                sroff => runoff%sroff, &

                cfs_conv => model_time%cfs_conv, &
                nowtime => model_time%Nowtime)

        if (cascadegw_flag > 0) then
          this%gw_upslope = 0.0_dp
          this%basin_dnflow = 0.0_dp
          this%basin_gw_upslope = 0.0_dp
        endif

        if (weir_gate_flag == 1) then
          ! elevlake from last timestep
          this%lake_seepage = 0.0_dp
          this%gw_seep_lakein = 0.0_dp
          this%basin_lake_seep = 0.0_dp

          do jj=1, active_gwrs
            j = gwr_route_order(jj)

            ! TODO: how to handle gwr_type
            ! if (gwr_type(j) /= LAKE) CYCLE

            jjj = lake_hru_id(j)

            ! What happens when lake goes dry? Need lake bottom elevation ?
            if (lake_type(jjj) == BCWEIR .or. lake_type(jjj) == GATEOP) then
              this%lake_seepage_max(jjj) = dble((this%elevlake(jjj) - this%lake_seep_elev(jjj)) * 12.0 * this%gw_seep_coef(j))  ! units = inches
            endif
          enddo

          ! TODO: Uncomment when gwr_type is figured out
          ! do jj = 1, active_gwrs
          !   j = gwr_route_order(jj)
          !
          !   if (gwr_type(j) == LAKE) then  ! only if a weir gate lake
          !     jjj = lake_hru_id(j)  !! jjj must be > zero due to check above
          !
          !     if (lake_type(jjj) == BCWEIR .or. lake_type(jjj) == GATEOP) then
          !       inch2acre_feet = hru_area_dble(j) / 12.0_dp
          !       seepage = this%lake_seepage_max(jjj)
          !       ! seepage added to GWR
          !       ! rsr, need seepage variable for WB
          !
          !       if (seepage < 0.0_dp) then
          !         ! Water to lake from GWR, negative value of seepage
          !         if (dabs(seepage) > this%gwres_stor(j)) then
          !           if (print_debug > -1) then
          !             print *, 'WARNING, GWR storage insufficient for discharge to lake:', jjj, ' GWR:', j
          !             ! call print_date(1)
          !             print *, 'GWR storage:', this%gwres_stor(j), ', computed discharge:', seepage
          !             print *, 'Discharge set to available GWR storage'
          !             !?? adjust lake storage and elevation
          !             print *, 'Lake elevation, storage, and water balance not adjusted'
          !           endif
          !
          !           seepage = -this%gwres_stor(j)
          !         endif
          !         this%gw_seep_lakein(jjj) = this%gw_seep_lakein(jjj) - seepage * inch2acre_feet  ! units, acre-feet
          !       else
          !         ! Water from lake to GWR, positive value of seepage needed
          !         ! because lakes could go dry.
          !         ! WARNING: needed for multiple HRU lakes, if lake goes dry some
          !         ! GWRs won't receive seepage, withdrawn from lake based on route
          !         ! order.
          !         if (this%lake_vol(jjj) < seepage * inch2acre_feet) then
          !           seepage = this%lake_vol(jjj) / inch2acre_feet
          !         endif
          !
          !         this%lake_seepage(jjj) = this%lake_seepage(jjj) + seepage * inch2acre_feet  ! units, acre-feet
          !         this%basin_lake_seep = this%basin_lake_seep + seepage * hru_area_dble(j)  ! units, acre-inches
          !       endif
          !
          !       this%gwres_stor(j) = this%gwres_stor(j) + seepage
          !       this%lake_seepage_gwr(j) = seepage  ! can be positive or negative value
          !       this%lake_vol(jjj) = this%lake_vol(jjj) - seepage * inch2acre_feet
          !     endif
          !   endif
          ! enddo

          this%basin_lake_seep = this%basin_lake_seep * basin_area_inv
        endif

        this%basin_gwstor_minarea_wb = 0.0_dp
        this%basin_gwsink = 0.0_dp

        do j=1, active_gwrs
          chru = gwr_route_order(j)
          ! gwarea = hru_area_dble(chru)
          gwstor = this%gwres_stor(chru) * hru_area_dble(chru)  ! acre-inches

          ! soil_to_gw is for whole HRU, not just perv
          this%gw_in_soil(chru) = soil_to_gw(chru) * hru_area(chru)
          this%gw_in_ssr(chru) = ssr_to_gw(chru) * hru_area(chru)
          gwin = this%gw_in_soil(chru) + this%gw_in_ssr(chru)

          if (cascadegw_flag > 0) then
            ! WARNING: gw_slope is initialized to zero at line 372
            !          gw_slope is not updated until the call to
            !          rungw_cascade (around line 587). This means that the
            !          gw_upslope is zero when added to gwin and basin_gw_slope.
            gwin = gwin + this%gw_upslope(chru)
            this%basin_gw_upslope = this%basin_gw_upslope + this%gw_upslope(chru)
          endif

          if (dprst_flag == 1) then
            ! TODO: rsr, need basin variable for WB
            this%gwin_dprst(chru) = dprst_seep_hru(chru) * hru_area_dble(chru)
            gwin = gwin + this%gwin_dprst(chru)
          endif

          ! TODO: Uncomment when water use module is converted
          ! if (gwr_transfers_on == 1) then
          !   gwin = gwin + (gwr_gain(chru) - gwr_transfer(chru)) / cfs_conv
          ! endif

          gwstor = gwstor + gwin
          ! this%basin_gwin = this%basin_gwin + gwin

          if (this%has_gwstor_minarea) then
            ! Check to be sure gwres_stor >= gwstor_minarea before computing outflows
            if (gwstor < this%gwstor_minarea(chru)) then
              if (gwstor < 0.0_dp) then
                if (print_debug > -1) then
                  print *, 'Warning, groundwater reservoir for HRU:', chru, &
                           ' is < 0.0 with gwstor_min active', gwstor
                endif
              endif

              gwstor_last = gwstor
              gwstor = this%gwstor_minarea(chru)

              !rsr, keep track of change in storage for WB
              this%gwstor_minarea_wb(chru) = gwstor - gwstor_last
              this%basin_gwstor_minarea_wb = this%basin_gwstor_minarea_wb + this%gwstor_minarea_wb(chru)
              this%gwstor_minarea_wb(chru) = this%gwstor_minarea_wb(chru) / hru_area_dble(chru)

              if (print_debug > -1) then
                print *, 'Added to gwres_stor as storage < gwstor_min to GWR:', chru, &
                         ' amount:', this%gwstor_minarea_wb(chru)
              endif
            else
              this%gwstor_minarea_wb(chru) = 0.0_dp
            endif
          endif

          gwsink = 0.0_dp
          if (gwstor < 0.0_dp) then
            ! Could happen with water use
            if (print_debug > -1) then
              print *, 'Warning, groundwater reservoir for HRU:', chru, ' is < 0.0', gwstor
            endif

            gwflow = 0.0_dp
            this%gwres_sink(chru) = 0.0_dp
          else
            ! Compute groundwater discharge
            gwflow = gwstor * dble(this%gwflow_coef(chru))

            ! WARNING: PAN - added 2019-02-19 to handle SIGFPE error when writing
            !          gwres_flow to netcdf summary file.
            if (gwflow > 0.0_dp .and. gwflow < DNEARZERO) then
              ! write(output_unit, 9008) MODNAME, '%run() WARNING: gwflow less than 2.2e-16,', chru, gwflow, ', reset to zero ', nowtime(1:3)
              gwflow = 0.0_dp
            endif

            ! Reduce storage by outflow
            gwstor = gwstor - gwflow

            9008 format(A, A, I6, es12.4e2, A, I4, 2('/', I2.2))

            if (this%gwsink_coef(chru) > 0.0) then
              ! if gwsink_coef > 1, could have had negative gwstor
              gwsink = min(gwstor * dble(this%gwsink_coef(chru)), gwstor)
              gwstor = gwstor - gwsink
            endif

            ! If gwr_swale_flag==1 swale GWR flow goes to sink, 2 included in
            ! stream network and cascades maybe gwr_swale_flag==3 abs(hru_segment)
            ! so hru_segment could be changed from 0 to allow HRU swales.
            ! TODO: Uncommented when gwr_type figured out
            ! if (gwr_swale_flag == 1) then
            !   if (gwr_type(chru) == SWALE) then
            !     gwsink = gwsink + gwflow
            !     gwflow = 0.0_dp
            !   endif
            ! endif

            this%gwres_sink(chru) = gwsink / hru_area_dble(chru)
            this%basin_gwsink = this%basin_gwsink + gwsink
          endif

          ! $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
          ! if (chru == 816) then
          !   write(*, *) chru, gwflow, hru_area_dble(chru), gwstor, gwflow_coef(chru)
          ! endif

          this%gwres_flow(chru) = gwflow / hru_area_dble(chru)

          ! TODO: Uncomment when cascade module is converted
          ! if (cascadegw_flag > 0) then
          !   if (ncascade_gwr(chru) > 0) then
          !     call rungw_cascade(runoff, model_time, chru, ncascade_gwr(chru), this%gwres_flow(chru), dnflow)
          !
          !     this%hru_gw_cascadeflow(chru) = dnflow
          !     this%basin_dnflow = this%basin_dnflow + dnflow * hru_area_dble(chru)
          !   endif
          ! endif

          ! Leave gwin in inch-acres
          this%gwres_in(chru) = gwin
          this%gwres_stor(chru) = gwstor / hru_area_dble(chru)
          this%hru_lateral_flow(chru) = this%gwres_flow(chru) + sroff(chru) + ssres_flow(chru)

          ! cfs_conv converts acre-inches per timestep to cfs
          this%hru_streamflow_out(chru) = hru_area_dble(chru) * cfs_conv * this%hru_lateral_flow(chru)
          this%hru_storage(chru) = dble(soil_moist_tot(chru) + hru_intcpstor(chru) + hru_impervstor(chru)) + &
                                this%gwres_stor(chru) + pkwater_equiv(chru)

          if (dprst_flag == 1) then
            this%hru_storage(chru) = this%hru_storage(chru) + dprst_stor_hru(chru)
          endif
        enddo

        ! TODO: Mask by active gwr
        this%basin_gwflow = sum(this%gwres_flow * hru_area_dble) * basin_area_inv
        this%basin_gwstor = sum(this%gwres_stor * hru_area_dble) * basin_area_inv
        this%basin_gwin = sum(this%gwres_in) * basin_area_inv

        this%basin_gwsink = this%basin_gwsink * basin_area_inv
        this%basin_gw_upslope = this%basin_gw_upslope * basin_area_inv
        this%basin_gwstor_minarea_wb = this%basin_gwstor_minarea_wb * basin_area_inv
        this%basin_dnflow = this%basin_dnflow * basin_area_inv
      end associate
    end subroutine

    module subroutine cleanup_Gwflow(this)
      class(Gwflow) :: this
        !! Gwflow class
    end subroutine


    !***********************************************************************
    !     Compute cascading GW flow
    !***********************************************************************
    ! TODO: Uncomment when cascade module is converted
    ! module subroutine rungw_cascade(this, runoff, model_time, igwr, ncascade_gwr, gwres_flow, dnflow)
    !   implicit none
    !
    !   ! Arguments
    !   class(Gwflow), intent(inout) :: this
    !   ! type(Cascade), intent(in) :: model_cascade
    !   type(Srunoff), intent(inout) :: runoff
    !   type(Time_t), intent(in) :: model_time
    !   integer(i32), intent(in) :: igwr
    !   integer(i32), intent(in) :: ncascade_gwr
    !   real(r32), intent(inout) :: gwres_flow
    !     !! in inches
    !   real(r32), intent(out) :: dnflow
    !
    !   ! Local variables
    !   integer(i32) :: j
    !   integer(i32) :: k
    !
    !   ! Cascade
    !   ! cascade_gwr_area, gwr_down, gwr_down_frac
    !
    !   ! Srunoff
    !   ! strm_seg_in(RW)
    !
    !   ! model_time
    !   ! cfs_conv
    !
    !   !***********************************************************************
    !   associate(cfs_conv => model_time%cfs_conv, &
    !             strm_seg_in => runoff%strm_seg_in)
    !     dnflow = 0.0
    !
    !     do k=1, ncascade_gwr
    !       j = gwr_down(k, igwr)
    !
    !       if (j > 0) then
    !         ! if gwr_down(k, igwr) > 0, cascade contributes to a downslope GWR
    !         this%gw_upslope(j) = this%gw_upslope(j) + gwres_flow * cascade_gwr_area(k, igwr)
    !         dnflow = dnflow + gwres_flow * gwr_down_frac(k, igwr)
    !       elseif (j < 0) then
    !         ! if gwr_down(k, igwr) < 0, cascade contributes to a stream
    !         j = iabs(j)
    !         strm_seg_in(j) = strm_seg_in(j) + dble(gwres_flow * cascade_gwr_area(k, igwr) ) * cfs_conv
    !       endif
    !     enddo
    !
    !     ! gwres_flow reduced by cascading flow to HRUs
    !     gwres_flow = gwres_flow - dnflow
    !     if (gwres_flow < 0.0) gwres_flow = 0.0
    !   end associate
    ! end subroutine



end submodule
