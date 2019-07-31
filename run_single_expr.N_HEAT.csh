#!/bin/csh -x

set expr = $1

ncl expr=\"$expr\" ./extract_ann_means_from_single_var_mon_tseries_N_HEAT.ncl
