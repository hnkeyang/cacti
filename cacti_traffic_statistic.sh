#!/bin/sh
#
cacti_url="http://192.168.1.15"
cacti_userName="admin"
cacti_passWord="admin"

###which graphs will be statistics
local_graph_id=()
#csvurl='http://$cacti_url/graph_xport.php?local_graph_id=6046&rra_id=3&view_type='
#local_graph_id[x]=local_graph_id
local_graph_id[0]=6046
local_graph_id[1]=5998
local_graph_id[2]=6098
local_graph_id[3]=6022

###rrd_id
#rrd_id=2 ,Weekly statistics
#rrd_id=3 ,Monthly statistics
rra_id=2

#set period for total traffic
#default is 7,weekly
case $rra_id in
    2) period=7 ;;
    3) period=30 ;;
    *) period=7 ;;
esac

get_shdir(){
    cwd=$(pwd)
    cd $(dirname $0)
    shdir=$(pwd)
    cd $cwd
    echo $shdir
}
shdir=$(get_shdir)
cd $shdir
mkdir -p tmp/{csv,zb_html}

#
csv_file_prefix=$shdir/tmp/csv/$(date '+%F')_

get_max_avg_pre_server(){
    local_graph_id=$1
    rra_id=$2
    csv_file=$csv_file_prefix$rra_id-$local_graph_id.csv
    [ -f $csv_file ] || (
    /usr/bin/wget -q --keep-session-cookies --save-cookies $shdir/tmp/cookie.txt --post-data "action=login&login_password=$cacti_passWord&login_username=$cacti_userName" $cacti_url -O /dev/null
    /usr/bin/wget --load-cookies=$shdir/tmp/cookie.txt "$cacti_url/graph_xport.php?local_graph_id=$local_graph_id&rra_id=$rra_id&view_type=" -q -O $csv_file)
    /bin/sed '1,10 d;s/\"//g;s/,/ /g' $csv_file|/bin/awk '{printf("%f\n",$4)}' | /bin/awk '{if($1 > top){top=$1};sum=sum+$1}END{printf("%f %f\n",top/1000/1000,sum/FNR/1000/1000)}'
}

eval $(for local_graph_id in ${local_graph_id[*]};do
    get_max_avg_pre_server $local_graph_id $rra_id
done|/bin/awk -v period=$period '{sum_max=sum_max+$1;sum_avg=sum_avg+$2}END{printf("sum_max=%0.2f;traffic=%0.2f\n",sum_max,sum_avg*60*60*24*period/1024/1024)}')
echo sum_max:$sum_max
echo traffic:$traffic

###如果需要发邮件,下载 https://raw.github.com/mogaal/sendemail/master/sendEmail,重命名为 sendEmail.pl,设置了snmp，就可以了
#/bin/sed 's/%-max-%/'$sum_max'/g;s/%-tra-%/'$traffic'/g' $shdir/zb.html > $shdir/today.html
#LANG=C /usr/bin/perl $shdir/sendEmail.pl -o message-file=$shdir/today.html -u "周报-$(date '+%m%d')" -t hnkeyang@gmail.com -f user@163.com -s smtp.163.com -xu snmp_user -xp snmp_pass 
#mv $shdir/today.html $shdir/tmp/zb_html/zb-$(date '+%F').html
