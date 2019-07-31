#!/bin/csh -x

set varname = $1
set expr    = $2

ncl varname=\"$varname\" expr=\"$expr\" ./extract_ann_means_from_single_var_mon_tseries_OMIP.ncl
