neuewelle /usr/local/app/mode0/tagionwave.json --option=subscription.tags:recorder,trt_created,monitor --keys /usr/local/app/mode0 < /usr/local/app/keys &
P1=$!
sleep 4 && \
wallet -x 0001 --list /usr/local/app/mode0/node0/wallet.json |grep 2024 |awk 'BEGIN{s="";}{s = s"\r\n"$3;}END{print "sed \x27s/#INDICES_PLACEHOLDER/"s"/g\x27 /tmp/webapp/static/explorer/wconfig.js > /tmp/webapp/static/explorer/temp && mv /tmp/webapp/static/explorer/temp /tmp/webapp/static/explorer/wconfig.js"}' |bash && \
tagionshell & 
P2=$!
wait $P1 $P2

