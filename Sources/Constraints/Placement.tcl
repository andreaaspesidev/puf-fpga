# Generic constants
set NUM_INSTANCES 640  
# NUM_LOOPS/2

# Initial positions for placement
set PUF_COLUMN1_START_X 2
set PUF_COLUMN2_START_X 42
set PUF_START_Y 2

# For each TERO Instance
for { set INSTANCE_NUM  0} {$INSTANCE_NUM < $NUM_INSTANCES} {incr NUM_INSTANCES} {
    # Load puf specification
    if { $INSTANCE_NUM == 0 } {
        # Fill clock regions X0Y0 and X0Y1 (with a margin of two CLB)
        # Each clock region has 100 rows, so we have 4 columns: 100*4
        # To keep a margin of two at the top and bottom: (4*2)*2
        set X1 $PUF_COLUMN1_START_X
        set X2 $PUF_COLUMN1_START_X
        set X3 $PUF_COLUMN1_START_X
        set X4 $PUF_COLUMN1_START_X
        incr $X2 1
        incr $X3 2
        incr $X4 3
        set Y  $PUF_START_Y
    } elseif { $INSTANCE_NUM == 400 - 16} {
        # Fill clock regions X1Y0 and X1Y1 (with a margin of two CLB)
        set X1 $PUF_COLUMN2_START_X
        set X2 $PUF_COLUMN2_START_X
        set X3 $PUF_COLUMN2_START_X
        set X4 $PUF_COLUMN2_START_X
        incr $X2 1
        incr $X3 2
        incr $X4 3
        set Y  $PUF_START_Y
    }

    set OR_COLUMN_RIGHT   $X1
    incr $OR_COLUMN_RIGHT 4
    set OR_COLUMN_LEFT    $X1
    incr $OR_COLUMN_LEFT -2
    
    # Calculate X position for each TERO instance
    if { $INSTANCE_NUM % 4 == 0 } { 
        # first column
        set X $X1
    } elseif { $INSTANCE_NUM % 4 == 1 } { 
        # second column
        set X $X2
    } elseif { $INSTANCE_NUM % 4 == 2 } { 
        # third column
        set X $X3
    } else {    
        # fourth column
        set X $X4
    }
    
    # Calculate Y position for each TERO instance
    if { $INSTANCE_NUM % 4 == 0 } {  
        # If start of the row
        if { $INSTANCE_NUM > 0 } {   
            # But we had a row before
            incr Y  # Increment for this row
        }
    }

    # Fix the placement of the first loop of the instance
    # ---- LUT 1 (yellow)
    place_cell PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop1_block1 SLICE_X$X\Y$Y/B6LUT
    set_property LOCK_PINS {I0:A1 I1:A2 I2:A3 I3:A4 I4:A5 I5:A6} [get_cells PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop1_block1]
    # ---- LUT 2 (blue)
    place_cell PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop1_block2 SLICE_X$X\Y$Y/C6LUT
    set_property LOCK_PINS {I0:A1 I1:A2 I2:A3 I3:A4 I4:A5 I5:A6} [get_cells PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop1_block2]
   
    # Pin the placement of the second loop of the instance
    # ---- LUT 1 (green)
    place_cell PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop2_block1 SLICE_X$X\Y$Y/A6LUT
    set_property LOCK_PINS {I0:A1 I1:A2 I2:A3 I3:A4 I4:A5 I5:A6} [get_cells PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop2_block1]
    # ---- LUT 2 (violet)
    place_cell PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop2_block2 SLICE_X$X\Y$Y/D6LUT
    set_property LOCK_PINS {I0:A1 I1:A2 I2:A3 I3:A4 I4:A5 I5:A6} [get_cells PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop2_block2]        

    # Pin the placement of the enable buffers of the instance
    # ---- loop 1
    place_cell PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop1_enable1_buff SLICE_X$X\Y$Y/BFF
    place_cell PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop1_enable2_buff SLICE_X$X\Y$Y/CFF
    # ---- loop 2
    place_cell PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop2_enable1_buff SLICE_X$X\Y$Y/AFF
    place_cell PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop2_enable2_buff SLICE_X$X\Y$Y/DFF

    # Pin the placement of the OR and the first stage counter
    # The first two instances (4 loops) are wired to the OR and then the OR to the counter on the right
    # The last two instances (4 loops) are wired to the OR and then the OR to the counter on the left

    # OR3  FF3     4   5        6   7      OR2  FF2
    # OR1  FF1     0   1        2   3      OR0  FF0
    if { $INSTANCE_NUM % 4 == 0 } { # first two instances
        # place on the right
        # --- OR
        place_cell PUF_inst/Core_inst/gen_OR[[expr {$INSTANCE_NUM / 2}]].LUT4_inst SLICE_X[$OR_COLUMN_RIGHT]\Y$Y/A6LUT
        set_property LOCK_PINS {I0:A5 I1:A3 I2:A4 I3:A6} [get_cells PUF_inst/Core_inst/gen_OR[[expr {$INSTANCE_NUM / 2}]].LUT4_inst]
        # --- first FF of counter
        place_cell PUF_inst/Core_inst/gen_cnt_fst_stage[[expr {$INSTANCE_NUM / 2}]].cnt/gen_ripple_block[0].FDCE_inst SLICE_X[$OR_COLUMN_RIGHT]\Y$Y/AFF
    } elseif { $INSTANCE_NUM % 4 == 2 } {
        # place on the left
        # --- OR
        place_cell PUF_inst/Core_inst/gen_OR[[expr {$INSTANCE_NUM / 2}]].LUT4_inst SLICE_X[$OR_COLUMN_LEFT]\Y$Y/A6LUT
        set_property LOCK_PINS {I0:A5 I1:A3 I2:A4 I3:A6} [get_cells PUF_inst/Core_inst/gen_OR[[expr {$INSTANCE_NUM / 2}]].LUT4_inst]
        # --- first FF of counter
        place_cell PUF_inst/Core_inst/gen_cnt_fst_stage[[expr {$INSTANCE_NUM / 2}]].cnt/gen_ripple_block[0].FDCE_inst SLICE_X[$OR_COLUMN_LEFT]\Y$Y/AFF
    }

    # Pin the routes
    if { $INSTANCE_NUM % 4 == 0 } { # first column
        # --- LUT1 NOT output
        set_property FIXED_ROUTE { { CLBLM_M_BMUX CLBLM_LOGIC_OUTS21 IMUX31 CLBLM_M_C5 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop1_block1/O5]
        set_property FIXED_ROUTE { { CLBLM_M_CMUX CLBLM_LOGIC_OUTS22 IMUX24 CLBLM_M_B5 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop1_block2/O5]
        # --- LUT2 NOT output
        set_property FIXED_ROUTE { { CLBLM_M_AMUX CLBLM_LOGIC_OUTS20 IMUX44 CLBLM_M_D4 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop2_block1/O5]
        set_property FIXED_ROUTE { { CLBLM_M_DMUX CLBLM_LOGIC_OUTS23 IMUX11 CLBLM_M_A4 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop2_block2/O5]
        # --- LUT1 AND self loop
        set_property FIXED_ROUTE { { CLBLM_M_B CLBLM_LOGIC_OUTS13  { EL1BEG0 ER1BEG1 IMUX4 CLBLM_M_A6 }  IMUX27 CLBLM_M_B4 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop1_block1/O6]
        set_property FIXED_ROUTE { { CLBLM_M_C CLBLM_LOGIC_OUTS14 IMUX28 CLBLM_M_C4 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop1_block2/O6]
        # --- LUT2 AND self loop
        set_property FIXED_ROUTE { { CLBLM_M_A CLBLM_LOGIC_OUTS12  { EE2BEG0 IMUX1 CLBLM_M_A3 }  IMUX8 CLBLM_M_A5 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop2_block1/O6]
        set_property FIXED_ROUTE { { CLBLM_M_D CLBLM_LOGIC_OUTS15 IMUX47 CLBLM_M_D5 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop2_block2/O6]
        # --- LUT1 enables
        set_property FIXED_ROUTE { { CLBLM_M_BQ CLBLM_LOGIC_OUTS5 IMUX18 CLBLM_M_B2 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop1_enable1_buff]
        set_property FIXED_ROUTE { { CLBLM_M_CQ CLBLM_LOGIC_OUTS6 IMUX29 CLBLM_M_C2 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop1_enable2_buff]
        # --- LUT2 enables
        set_property FIXED_ROUTE { { CLBLM_M_AQ CLBLM_LOGIC_OUTS4 IMUX1 CLBLM_M_A3 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop2_enable1_buff]
        set_property FIXED_ROUTE { { CLBLM_M_DQ CLBLM_LOGIC_OUTS7 IMUX38 CLBLM_M_D3 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop2_enable2_buff]
        # --- OR to first FF clk (needed?)
        set_property FIXED_ROUTE { { CLBLM_M_A CLBLM_LOGIC_OUTS12 NL1BEG_N3 FAN_ALT5 FAN_BOUNCE5 CLK1 CLBLM_M_CLK }  } [ get_nets PUF_inst/Core_inst/ored_out[[expr {$INSTANCE_NUM / 2}]] ] # ored_out_[expr {$INSTANCE_NUM / 2}]
    } elseif { $INSTANCE_NUM % 4 == 1 } { # second column
        # --- LUT1 NOT output
        set_property FIXED_ROUTE { { CLBLM_L_BMUX CLBLM_LOGIC_OUTS17 IMUX30 CLBLM_L_C5 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop1_block1/O5]
        set_property FIXED_ROUTE { { CLBLM_L_CMUX CLBLM_LOGIC_OUTS18 IMUX25 CLBLM_L_B5 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop1_block2/O5]
        # --- LUT2 NOT output
        set_property FIXED_ROUTE { { CLBLM_L_AMUX CLBLM_LOGIC_OUTS16 IMUX37 CLBLM_L_D4 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop2_block1/O5]
        set_property FIXED_ROUTE { { CLBLM_L_DMUX CLBLM_LOGIC_OUTS19 IMUX10 CLBLM_L_A4 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop2_block2/O5]
        # --- LUT1 AND self loop
        set_property FIXED_ROUTE { { CLBLM_L_B CLBLM_LOGIC_OUTS9  { EE2BEG1 IMUX11 CLBLM_M_A4 }  IMUX26 CLBLM_L_B4 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop1_block1/O6]
        set_property FIXED_ROUTE { { CLBLM_L_C CLBLM_LOGIC_OUTS10 IMUX21 CLBLM_L_C4 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop1_block2/O6]
        # --- LUT2 AND self loop
        set_property FIXED_ROUTE { { CLBLM_L_A CLBLM_LOGIC_OUTS8  { ER1BEG1 EL1BEG0 IMUX8 CLBLM_M_A5 }  IMUX9 CLBLM_L_A5 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop2_block1/O6]
        set_property FIXED_ROUTE { { CLBLM_L_D CLBLM_LOGIC_OUTS11 IMUX46 CLBLM_L_D5 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop2_block2/O6]
        # --- LUT1 enables
        set_property FIXED_ROUTE { { CLBLM_L_BQ CLBLM_LOGIC_OUTS1 IMUX19 CLBLM_L_B2 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop1_enable1_buff]
        set_property FIXED_ROUTE { { CLBLM_L_CQ CLBLM_LOGIC_OUTS2 IMUX20 CLBLM_L_C2 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop1_enable2_buff]
        # --- LUT2 enables
        set_property FIXED_ROUTE { { CLBLM_L_AQ CLBLM_LOGIC_OUTS0 IMUX0 CLBLM_L_A3 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop2_enable1_buff]
        set_property FIXED_ROUTE { { CLBLM_L_DQ CLBLM_LOGIC_OUTS3 IMUX39 CLBLM_L_D3 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop2_enable2_buff]
    } elseif { $INSTANCE_NUM % 4 == 2 } { # third column
        # --- LUT1 NOT output
        set_property FIXED_ROUTE { { CLBLL_LL_BMUX CLBLL_LOGIC_OUTS21 IMUX_L31 CLBLL_LL_C5 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop1_block1/O5]
        set_property FIXED_ROUTE { { CLBLL_LL_CMUX CLBLL_LOGIC_OUTS22 IMUX_L24 CLBLL_LL_B5 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop1_block2/O5]
        # --- LUT2 NOT output
        set_property FIXED_ROUTE { { CLBLL_LL_AMUX CLBLL_LOGIC_OUTS20 IMUX_L44 CLBLL_LL_D4 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop2_block1/O5]
        set_property FIXED_ROUTE { { CLBLL_LL_DMUX CLBLL_LOGIC_OUTS23 IMUX_L11 CLBLL_LL_A4 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop2_block2/O5]
        # --- LUT1 AND self loop
        set_property FIXED_ROUTE { { CLBLL_LL_B CLBLL_LOGIC_OUTS13  { IMUX_L27 CLBLL_LL_B4 }  WW2BEG1 IMUX_L11 CLBLL_LL_A4 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop1_block1/O6]
        set_property FIXED_ROUTE { { CLBLL_LL_C CLBLL_LOGIC_OUTS14 IMUX_L28 CLBLL_LL_C4 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop1_block2/O6]
        # --- LUT2 AND self loop
        set_property FIXED_ROUTE { { CLBLL_LL_A CLBLL_LOGIC_OUTS12  { IMUX_L8 CLBLL_LL_A5 }  WW2BEG0 IMUX_L2 CLBLL_LL_A2 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop2_block1/O6]
        set_property FIXED_ROUTE { { CLBLL_LL_D CLBLL_LOGIC_OUTS15 IMUX_L47 CLBLL_LL_D5 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop2_block2/O6]
        # --- LUT1 enables
        set_property FIXED_ROUTE { { CLBLL_LL_BQ CLBLL_LOGIC_OUTS5 IMUX_L18 CLBLL_LL_B2 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop1_enable1_buff]
        set_property FIXED_ROUTE { { CLBLL_LL_CQ CLBLL_LOGIC_OUTS6 IMUX_L29 CLBLL_LL_C2 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop1_enable2_buff]
        # --- LUT2 enables
        set_property FIXED_ROUTE { { CLBLL_LL_AQ CLBLL_LOGIC_OUTS4 IMUX_L1 CLBLL_LL_A3 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop2_enable1_buff]
        set_property FIXED_ROUTE { { CLBLL_LL_DQ CLBLL_LOGIC_OUTS7 IMUX_L38 CLBLL_LL_D3 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop2_enable2_buff]
        # --- OR to first FF clk (needed?)
        set_property FIXED_ROUTE { { CLBLL_LL_A CLBLL_LOGIC_OUTS12 NL1BEG_N3 FAN_ALT5 FAN_BOUNCE5 CLK_L1 CLBLL_LL_CLK }  } [ get_nets PUF_inst/Core_inst/ored_out[[expr {$INSTANCE_NUM / 2}]] ]
    } else {    # fourth column
        # --- LUT1 NOT output
        set_property FIXED_ROUTE { { CLBLL_L_BMUX CLBLL_LOGIC_OUTS17 IMUX_L30 CLBLL_L_C5 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop1_block1/O5]
        set_property FIXED_ROUTE { { CLBLL_L_CMUX CLBLL_LOGIC_OUTS18 IMUX_L25 CLBLL_L_B5 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop1_block2/O5]
        # --- LUT2 NOT output
        set_property FIXED_ROUTE { { CLBLL_L_AMUX CLBLL_LOGIC_OUTS16 IMUX_L37 CLBLL_L_D4 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop2_block1/O5]
        set_property FIXED_ROUTE { { CLBLL_L_DMUX CLBLL_LOGIC_OUTS19 IMUX_L10 CLBLL_L_A4 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop2_block2/O5]
        # --- LUT1 AND self loop
        set_property FIXED_ROUTE { { CLBLL_L_B CLBLL_LOGIC_OUTS9  { IMUX_L26 CLBLL_L_B4 }  WR1BEG2 WL1BEG0 IMUX_L1 CLBLL_LL_A3 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop1_block1/O6]
        set_property FIXED_ROUTE { { CLBLL_L_C CLBLL_LOGIC_OUTS10 IMUX_L21 CLBLL_L_C4 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop1_block2/O6]
        # --- LUT2 AND self loop
        set_property FIXED_ROUTE { { CLBLL_L_A CLBLL_LOGIC_OUTS8  { IMUX_L9 CLBLL_L_A5 }  WR1BEG1 WR1BEG2 IMUX_L4 CLBLL_LL_A6 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop2_block1/O6]
        set_property FIXED_ROUTE { { CLBLL_L_D CLBLL_LOGIC_OUTS11 IMUX_L46 CLBLL_L_D5 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop2_block2/O6]
        # --- LUT1 enables
        set_property FIXED_ROUTE { { CLBLL_L_BQ CLBLL_LOGIC_OUTS1 IMUX_L19 CLBLL_L_B2 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop1_enable1_buff]
        set_property FIXED_ROUTE { { CLBLL_L_CQ CLBLL_LOGIC_OUTS2 IMUX_L20 CLBLL_L_C2 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop1_enable2_buff]
        # --- LUT2 enables
        set_property FIXED_ROUTE { { CLBLL_L_AQ CLBLL_LOGIC_OUTS0 IMUX_L0 CLBLL_L_A3 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop2_enable1_buff]
        set_property FIXED_ROUTE { { CLBLL_L_DQ CLBLL_LOGIC_OUTS3 IMUX_L39 CLBLL_L_D3 }  } [get_nets PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS/loop2_enable2_buff] 
    }
}