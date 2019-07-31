#!/bin/csh -x

setenv CMD "sbatch -p dav --mem 10G -t 4:00:00 -n 1 -A P93300670"

foreach expr ( omip2 omip1 )
  $CMD -o /glade/work/klindsay/OMIP/scripts/logs/N_HEAT.$expr.log ./run_single_expr.N_HEAT.csh $expr
  sleep 1
end
