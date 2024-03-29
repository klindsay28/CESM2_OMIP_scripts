;
; extract_ann_means_from_single_var_mon_tseries_OMIP.ncl
;

load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"

begin

  varname = "N_HEAT"

  print("varname  = "+varname)

  model_name = "CESM2"
  exprs     = (/     "omip2",     "omip1" /)
  cases     = (/ "g.e21.GOMIPECOIAF_JRA.TL319_g17.CMIP6-omip2.001", \
                 "g.e21.GOMIPECOIAF.T62_g17.CMIP6-omip1.002" /)
  yr_begs   = (/      1+5*61,      1+5*62 /)
  yr_ends   = (/        6*61,        6*62 /)

  setfileoption("nc", "Format", "NetCDF4Classic")
  setfileoption("nc", "CompressionLevel", 1)

  if (.not. isvar("expr")) then
    print("expr must be specified on ncl command line")
    exit
  end if
 
  expr_ind = ind(exprs .eq. expr)
  if ismissing(expr_ind) then
    print("unknown expr="+expr)
  end if

  case   = cases(expr_ind)
  yr_beg = yr_begs(expr_ind)
  yr_end = yr_ends(expr_ind)

  print("expr   = "+expr)
  print("case   = "+case)
  print("yr_beg = "+yr_beg)
  print("yr_end = "+yr_end)

  if (yr_end .lt. yr_beg) then
    print("yr_end must be >= yr_beg")
    exit
  end if

  outfile_dir = "/glade/work/klindsay/OMIP/work/"+expr+"/"
  if (.not. fileexists(outfile_dir)) then
    system("mkdir -p "+outfile_dir)
  end if

  mon_tseries_dir = "/glade/work/klindsay/OMIP/work/"+expr+"/"

  mon_tseries_pattern = case+".pop.h."+varname+".??????-??????.nc"

  print("extracting "+varname+" of years "+yr_beg+"-"+yr_end+" from "+expr)

  yr_cnt = yr_end-yr_beg+1

  ;
  ; open input files
  ;
  mon_tseries_files := systemfunc("ls "+mon_tseries_dir+mon_tseries_pattern)
  print("input files = ")
  print((/ mon_tseries_files /))

  print("opening files")
  f_in = addfiles(mon_tseries_files, "r")
  print("files opened")

  ;
  ; before proceeding, verify that varname has supported rank
  ;
  var_rank = dimsizes(filevardimsizes(f_in[0], varname))
  if (.not. any(var_rank .eq. (/ 1, 2, 3, 4, 5 /))) then
    print("rank "+var_rank+" not supported")
    exit
  end if

  ;
  ; find index of month whose lower time_bounds is 01 Jan of yr_beg
  ; assume months are consecutive from first with no gaps
  ;
  time_bounds_varname = f_in[0]->time@bounds
  time0 = round(f_in[0]->$time_bounds_varname$(0, 0), 0)
  time0@units = f_in[0]->time@units
  time0@calendar = f_in[0]->time@calendar
  yyyymm0 = cd_calendar(time0,-1)
  mm0 = yyyymm0 % 100
  yyyy0 = (yyyymm0 - mm0) / 100

  yr_beg_mon_ind = 12*(yr_beg-yyyy0) + 1-mm0
  print("yyyy0 = "+yyyy0)
  print("mm0   = "+mm0)
  print("yr_beg_mon_ind   = "+yr_beg_mon_ind)

  timetest = round(f_in[:]->$time_bounds_varname$(yr_beg_mon_ind, 0), 0)
  timetest@units = f_in[0]->time@units
  timetest@calendar = f_in[0]->time@calendar
  yyyymmtest = cd_calendar(timetest,-1)
  if (yyyymmtest .ne. yr_beg*100+1) then
    print("internal error finding start month index")
    print("  yr_beg*100+1 = "+(yr_beg*100+1))
    print("  yyyymmtest = "+yyyymmtest)
    print("  yr_beg_mon_ind = "+yr_beg_mon_ind)
    exit
  end if

  ;
  ; create output file
  ;
  yr_string = "."+sprinti("%0.4i", yr_beg)+"-"+sprinti("%0.4i", yr_end)
  outfile_name = outfile_dir+case+".pop.h."+varname+yr_string+".nc"
  print(outfile_name)

  system("rm -f "+outfile_name)
  f_out = addfile(outfile_name, "c")

  setfileoption(f_out, "DefineMode", True)

  ;
  ; define all dimensions, even though they may not all be necessary
  ;
  dim_names := getvardims(f_in[0])
  dim_sizes := getfiledimsizes(f_in[0])
  dim_unlimited := new(dimsizes(dim_names), logical)
  do dimind = 0, dimsizes(dim_names)-1
    dim_unlimited(dimind) = isunlimited(f_in[0], dim_names(dimind))
  end do
  filedimdef(f_out, dim_names, dim_sizes, dim_unlimited)

  ;
  ; define time invariant and varname variables
  ;   copy attributes
  ;
  varnames := getfilevarnames(f_in[0])
  do var_ind = 0, dimsizes(varnames)-1
    filevardims := getfilevardims(f_in[0], varnames(var_ind))
    if (filevardims(0) .ne. "time" .or. any(varnames(var_ind) .eq. (/ varname, "time", time_bounds_varname /))) then
      filevardef(f_out, \
                 varnames(var_ind), \
                 getfilevartypes(f_in[0], varnames(var_ind)), \
                 getfilevardims(f_in[0], varnames(var_ind)))
      varatts := getfilevaratts(f_in[0], varnames(var_ind))
      if (.not. ismissing(varatts(0))) then
        do attind = 0, dimsizes(varatts)-1
          ; if _FillValue is present, use its value for missing_value, instead of the provided missing_value value
          if (varatts(attind) .eq. "missing_value") then
            if isfilevaratt(f_in[0], varnames(var_ind), "_FillValue") then
              f_out->$varnames(var_ind)$@$varatts(attind)$ = f_in[0]->$varnames(var_ind)$@_FillValue
            else
              f_out->$varnames(var_ind)$@$varatts(attind)$ = f_in[0]->$varnames(var_ind)$@missing_value
            end if
            continue
          end if
          f_out->$varnames(var_ind)$@$varatts(attind)$ = f_in[0]->$varnames(var_ind)$@$varatts(attind)$
        end do
      end if
    end if
  end do

  ;
  ; copy global file attributes from first file
  ;
  fileatts := getvaratts(f_in[0])
  if(.not.any(ismissing(fileatts))) then
    do attind = 0, dimsizes(fileatts)-1
      attname = fileatts(attind)
      f_out@$attname$ = f_in[0]@$attname$
    end do
  end if

  setfileoption(f_out, "DefineMode", False)

  ;
  ; copy time invariant variables
  ;
  print("copying time invariant variables")
  do var_ind = 0, dimsizes(varnames)-1
    filevardims := getfilevardims(f_in[0], varnames(var_ind))
    if (filevardims(0) .ne. "time") then
      f_out->$varnames(var_ind)$ = (/ f_in[0]->$varnames(var_ind)$ /)
    end if
  end do
  print("time invariant variables copied")

  ;
  ; loop over years, create annual mean of varname, write it out
  ;
  yyyymm = ispan(101, 112, 1)
  do yr_ind = 0, yr_cnt-1
    print("extracting year "+(yr_beg+yr_ind))
    mon_ind_beg = yr_beg_mon_ind+12*yr_ind
    mon_ind_end = yr_beg_mon_ind+12*yr_ind+11
    f_out->time(yr_ind) = (/ 0.5 * (f_in[:]->$time_bounds_varname$(mon_ind_beg, 0) + \
                                    f_in[:]->$time_bounds_varname$(mon_ind_end, 1)) /)
    f_out->$time_bounds_varname$(yr_ind, 0) = (/ f_in[:]->$time_bounds_varname$(mon_ind_beg, 0) /)
    f_out->$time_bounds_varname$(yr_ind, 1) = (/ f_in[:]->$time_bounds_varname$(mon_ind_end, 1) /)
    if (var_rank .eq. 1) then
      tmp_mon := f_in[:]->$varname$(mon_ind_beg:mon_ind_end)
    end if
    if (var_rank .eq. 2) then
      tmp_mon := f_in[:]->$varname$(mon_ind_beg:mon_ind_end, :)
    end if
    if (var_rank .eq. 3) then
      tmp_mon := f_in[:]->$varname$(mon_ind_beg:mon_ind_end, :, :)
    end if
    if (var_rank .eq. 4) then
      tmp_mon := f_in[:]->$varname$(mon_ind_beg:mon_ind_end, :, :, :)
    end if
    if (var_rank .eq. 5) then
      tmp_mon := f_in[:]->$varname$(mon_ind_beg:mon_ind_end, :, :, :, :)
    end if
    tmp_ann := month_to_annual_weighted(yyyymm, tmp_mon, 1)
    if isatt(tmp_ann, "_FillValue") then
      delete(tmp_ann@_FillValue)
    end if
    if (var_rank .eq. 1) then
      f_out->$varname$(yr_ind) = (/ tmp_ann /)
    end if
    if (var_rank .eq. 2) then
      f_out->$varname$(yr_ind, :) = (/ tmp_ann /)
    end if
    if (var_rank .eq. 3) then
      f_out->$varname$(yr_ind, :, :) = (/ tmp_ann /)
    end if
    if (var_rank .eq. 4) then
      f_out->$varname$(yr_ind, :, :, :) = (/ tmp_ann /)
    end if
    if (var_rank .eq. 5) then
      f_out->$varname$(yr_ind, :, :, :, :) = (/ tmp_ann /)
    end if
  end do

end
