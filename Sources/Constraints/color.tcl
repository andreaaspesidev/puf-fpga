set NUM_INSTANCES 640

set HIGH_LIMIT_4 {$NUM_INSTANCES - 4}


for {set INSTANCE_NUM 0} {$INST_NUM < $NUM_INSTANCES} {incr INSTANCE_NUM 4} {

    highlight_objects -color blue -leaf_cells [get_cells PUF_inst/Core_inst/gen_TEROS[$INSTANCE_NUM].TEROS]
    highlight_objects -color red -leaf_cells [get_cells PUF_inst/Core_inst/gen_TEROS[[expr {$INSTANCE_NUM + 1}]].TEROS]
    highlight_objects -color green -leaf_cells [get_cells PUF_inst/Core_inst/gen_TEROS[[expr {$INSTANCE_NUM + 2}]].TEROS]
    highlight_objects -color yellow -leaf_cells [get_cells PUF_inst/Core_inst/gen_TEROS[[expr {$INSTANCE_NUM + 3}]].TEROS]
}