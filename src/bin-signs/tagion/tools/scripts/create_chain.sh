#!/usr/bin/env bash

if [[ "$1" == "--begin" ]]; then
  signs -f delivery_order.hibon -o courierb_handover.hibon -r @A5eZWdF6MFIAqghay4Ipwrp9AVBtWHt44tcDau71uJTw -p district_centre
else
  signs -f courierb_handover.hibon -o service_delivery_point_handover.hibon -r @A87RMkiNOWkuMoyaFIPjQ3P-CAaBKWjpFnELUl_9MZLm -p courierb
  signs -f service_delivery_point_handover.hibon -o courierd_handover.hibon -r @AoG38SGTwVAELn8uW3IHmb-ESmlQrcVllw3PsVIr2y_J -p service_delivery_point
  signs -f courierd_handover.hibon -o final_destination.hibon -r @A1nCdFZhx_cGFBykloXgTnvqkyq6bUw_SCKySkT24Odk -p courierd
fi
