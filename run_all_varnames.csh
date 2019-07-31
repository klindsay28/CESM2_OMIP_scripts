#!/bin/csh -x

setenv CMD "sbatch -p dav --mem 10G -t 4:00:00 -n 1 -A P93300670"

foreach varname ( thetaoga soga msftmz \
                  thetao.gr so.gr uo vo \
                  sivoln sivols )
  foreach expr ( omip2 omip1 )
    $CMD -o /glade/work/klindsay/OMIP/scripts/logs/$varname.$expr.log ./run_single_varname.csh $varname $expr
    sleep 1
  end
end
