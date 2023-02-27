#!/usr/bin/perl
use strict;
#use warnings;
use warnings FATAL => 'all';
use Time::Local;
use Net::SMTP;

my $input_day = shift;
my $title_date = substr($input_day,0,4) . "-" . substr($input_day,4,2) . "-" . substr($input_day,6,2);

my $CATSubmitterID = "146310";

my %sessionids = (
);

my %skipAcounts = (
	'AVTT1209' => 'AVTT1209',
	'3NM71209' => '3NM71209'
);

my %destination = (
	"DASH"=>"104031:DFIN",
	"DASU"=>"104031:DFIN",
	"DASO"=>"104031:DFIN",
	"DASM"=>"104031:DFIN",
	"GS"=>"361:GSCS",
	"GSCO"=>"361:GSCS",
	"GSCM"=>"361:GSCS",
	"GSDO"=>"361:GSCS",
	"GSFF"=>"361:GSCS",
	"GSGU"=>"361:GSCS",
	"CTDL"=>"116797:CDRG",
	"CTDU"=>"116797:CDRG",  #added 562022
	"ARCO"=>"ARCA",
	"ARCX"=>"ARCA",
	"CDEL"=>"116797:CDEL"
);

my %lastmarket = (
	"7" =>"361:GSCS"
);

my %exchid;
my %desttypes = (
	"ARCA"=>"E",
	"7"=>"F"
);

my $iscentral = 0;
my %reptimes;
my %cancelreqtimes;
my %replacereqtimes;
my %outs;
my %orig_times;
my %rejects;
my %replacerej;
my %replaced;
my %canceled;

my $sequence = 1;
my $file_sequence = 15;

my $CATactionType = "NEW";
my $CATerrorROEID = "";
my $CATfirmROEID;
my @CATtype = ("MENO","MEOA","MEOR","MEOC","MEOM","MONO","MOOA","MOOR","MOOC","MOOM","MLOR","MLNO","MLOA","MLOM","MLOC");
my $CATReporterIMID= "SUMZ";
my $CATorderKeyDate;
my $CATorderID;
my $CATsymbol;
my $CATeventTimestamp;
my $CATmanualFlag="false";
my $CATelectronicDupFlag="false";
my $CATelectronicTimestamp="";
my $CATmanualOrderKeyDate="";
my $CATmanualOrderID="";
my $CATdeptType="T";
my $CATsolicitationFlag="false";
my $CATRFQID = "";
my $CATside;
my $CATprice;
my $CATquantity;
my $CATminQty="";
my $CATorderType;
my $CATtimeInForce;
my $CATtradingSession;
my $CAThandlingInstructions;
my $CATcustDspIntrFlag="false";
my $CATfirmDesignatedID;
my $CATaccountHolderType = "P";
my @CATaffiliateFlag = ("TRUE","FALSE");
my $CATinfoBarierID="";
my $CATaggregatedOrders="";
my $CATnegotiatedTradeFlag="false"; 
my $CATrepresentativeInd="N";
my $CATseqNum = "";
my $CATatsField="";
my $CATnetPrice="";

my $CAToriginatingIMID="";
my $CATsenderIMID;
my $CATdestination;
my $CATdestinationType;
my $CATroutedOrderID;
my $CATsession="";
my $CATrouteRejectedFlag = "";
my $CATdupROIDCond="false";
my $CATmultiLegInd="false";
my $CATpairedOrderID = "";
my $CATquoteKeyDate="";
my $CATquoteID="";

my $CATpriorOrderKeyDate="";
my $CATpriorOrderID="";
my $CATreceiverIMID="";
my $CATsenderType="";
my $CATreservedForFutureUse="";
my $CATinitiator="F";
my $CATrequestTimestamp="";
my $CATleavesQty;
my $CATisoInd="NA";
my $CATinfoBarrierID="";
my $CATcancelQty;


my $tzinfo = `strings /etc/localtime | egrep -o "[CE]ST[56][CE]DT"`;
if (!defined($tzinfo) || length($tzinfo) == 0) {
    print "cannot determine time zone\n";
}
if ($tzinfo =~ "CST6CDT") {
    $iscentral = 1;
    print "Central time\n";
} else {
    print "Eastern time\n";
}
print "$tzinfo\n";

my @files = <*out*$title_date.csv>; #119
my @sfiles =  sort {
    ($a =~ /_(\d+)/)[0] <=> ($b =~ /_(\d+)/)[0]
} @files;


# foreach my $exch (sort keys %exchid) {
#     print "$exch => $exchid{$exch}\n";
# }
# foreach my $type (sort keys %desttypes) {
#     print "$type => $desttypes{$type}\n";
# }

my $source="Redi";

my $file_h = &set_file($CATSubmitterID, $source);

foreach my $file (@sfiles) {
    open(IN, "<$file") or die "cannot open $file\n";
    while(<IN>) {
        chomp;
        my @lroms = split(/,/);
		my $sym = $lroms[13];
        if($sym eq "ZVZZT") {
			#print "Test order: $sym, $lroms[28], $lroms[13], $lroms[55] \n";
			#print "Test order: \n";
		} elsif($lroms[0] ne "Execution") {
			if ($lroms[15] eq "EQUITY" and ($lroms[30] eq "SingleSecurity" or $lroms[30] eq ""))  {
				if( $lroms[0] eq "New") {
					$orig_times{$lroms[37]} = &create_time_str($lroms[2]);
				}
				if( $lroms[0] eq "Replaced") {
					$reptimes{$lroms[1]} = &create_time_str($lroms[2]);
					$replaced{$lroms[36]} = $lroms[1];
				}
				if($lroms[0] eq "Rejected") {
					$rejects{$lroms[1]} = "true";
					$outs{$lroms[1]} = $lroms[1];
				}
				if($lroms[0] eq "ReplaceRejected") {
					$replacerej{$lroms[1]} = "true";
				}
				if($lroms[0] eq "CancelPending" or $lroms[0] eq "CancelRequested") {
					$cancelreqtimes{$lroms[1]} = &create_time_str($lroms[2]);
					#$orig_times{$lroms[36]} = &create_time_str($lroms[2]);
				}
				if($lroms[0] eq "ReplaceRequested" or $lroms[0] eq "ReplacePending") {
					$replacereqtimes{$lroms[36]} = &create_time_str($lroms[2]);
					#$orig_times{$lroms[36]} = &create_time_str($lroms[2]);
				}
				
			}
		}
    }
    close(IN);
}

# foreach my $exch (sort keys %cancelreqtimes) {
#     print "$exch => $cancelreqtimes{$exch}\n";
# }

my %orderdest;
my $rsv;
my $instruction="";

foreach my $file (@sfiles) {
    open(IN, "<$file") or die "cannot open $file\n";

    while (<IN>) {
        chomp;
        my @romfields = split(/,/);
		my $sym = $romfields[13];
        if($sym eq "ZVZZT" or defined $skipAcounts{$romfields[3]} or defined $skipAcounts{$romfields[28]}) {
			print "Test order: $sym, $romfields[28], $romfields[13], $romfields[37] \n";
		} elsif($romfields[0] ne "Execution" and defined $romfields[37]) {
			if ($romfields[15] eq "EQUITY" and $romfields[30] eq "SingleSecurity" and defined $romfields[37])  {
				if(defined $romfields[46] and $romfields[46] ne ""){
					$instruction="RSV|DISQ=" . $romfields[46];
				}elsif(defined $romfields[44] and $romfields[44] eq "VWAP"){
					$instruction="ALG"
				}else{
				$instruction="";
				}

				my $imid = "146310:SUMZ";
				if($romfields[0] eq "New" ) {
				   &create_new_order(\@romfields);
					my $OrderID=$romfields[37];
					my $origTime=$orig_times{$romfields[37]};
					$orderdest{$OrderID}=$romfields[29];
					&create_order_routed(\@romfields, $origTime, $OrderID, $orderdest{$OrderID});
				}  
				if($romfields[0] eq "Cancelled") {
					&create_order_cancel(\@romfields);
				}
				if($romfields[0] eq "Replaced") {
					my $OrderID=$romfields[37];
					my $origTime=$replacereqtimes{$romfields[36]};
					&create_order_modify(\@romfields, $OrderID);
					&create_order_routed(\@romfields, $origTime, $OrderID, $orderdest{$OrderID});
				}
			}
		}
    }
    close(IN);
}

sub create_new_order {
    my $lroms = shift;
    my $output = sprintf("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n",
        $CATactionType,                                                                               #1
        $CATerrorROEID,                                                                               #2
        $CATfirmROEID=&create_fore_id($lroms->[3], $lroms->[37], &create_time_str($lroms->[2]), $lroms->[51], $CATtype[0]),          #3
        $CATtype[0],                                                                                  #4
        $CATReporterIMID,                                                                             #5
        $CATorderKeyDate=&getOriginalTime($lroms->[37], $lroms->[2]), #&create_time_str($lroms->[2]),                        						  #6
        $CATorderID=$lroms->[37],                                                                     #7
        $CATsymbol=&get_symbol($lroms->[13],$lroms->[14] ,$lroms->[50]),   							  #8
        $CATeventTimestamp=&create_time_str($lroms->[2]),                                             #9
        $CATmanualFlag,                                                                               #10 
        $CATelectronicDupFlag,                                                                        #11
        $CATelectronicTimestamp,                                                                      #12
        $CATmanualOrderKeyDate,                                                                       #13
        $CATmanualOrderID,                                                                            #14
        $CATdeptType,                                                                                 #15 
        $CATsolicitationFlag,                                                                         #16
        $CATRFQID,                                                                                    #17
        $CATside=&convert_side($lroms->[6]),                                                          #18
        $CATprice=&checkPrice($lroms->[8], $lroms->[4]),                                              #19
        $CATquantity=$lroms->[7],                                                                     #20 
        $CATminQty,                                                                                   #21
        $CATorderType=&convert_type($lroms->[4]),                                                     #22
        $CATtimeInForce=&checkTif($lroms->[5], $lroms->[2], $lroms->[47]),                                          #23
        $CATtradingSession=&checkSessions(&create_time_str($lroms->[2]),$lroms->[5]),                                   #24
        $CAThandlingInstructions=&setHandlingInstructions($CATtype[0],$instruction), #,$lroms->[53]  				  #25
        $CATcustDspIntrFlag,                                                                          #26
        $CATfirmDesignatedID=&get_clear_account($lroms->[3],$lroms->[28]),  						  #27
        $CATaccountHolderType="P",                    			                                      #28
        $CATaffiliateFlag[1],                                                                         #29
        $CATinfoBarierID,                                                                             #30
        $CATaggregatedOrders,                                                                         #31
        $CATnegotiatedTradeFlag,                                                                      #32
        $CATrepresentativeInd,                                                                        #33
        $CATatsField,                                                                                 #34
        $CATatsField,                                                                                 #35
        $CATatsField,                                                                                 #36
        $CATatsField,                                                                                 #37
        $CATatsField,                                                                                 #38
        $CATatsField,                                                                                 #39
        $CATatsField,                                                                                 #40
        $CATatsField,                                                                                 #41
        $CATatsField,                                                                                 #42
        $CATatsField,                                                                                 #43
        $CATatsField,                                                                                 #44
        $CATatsField,                                                                                 #45
        $CATnetPrice                                                                                  #46
    );
    my $lf = $file_h->{"file"};
    print $lf $output;

}

sub create_order_routed {
    my $lroms = shift;
    my $sentTime = shift;
	my $fixed_roid = shift;		
	my $dest = shift;
    my $output = sprintf ("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n",
        $CATactionType,                                     				#1
        $CATerrorROEID,                                     				#2
        $CATfirmROEID=&create_fore_id($lroms->[3], $lroms->[37], &create_time_str($lroms->[2]), $lroms->[51], $CATtype[2]),        #3
        $CATtype[2],                                        				#4
        $CATReporterIMID,                                   				#5
        $CATorderKeyDate=&getOriginalTime($lroms->[37], $lroms->[2]),       #6
        $CATorderID=$lroms->[37],                                       	#7
        $CATsymbol=&get_symbol($lroms->[13],$lroms->[14] ,$lroms->[50]),   	#8
        $CAToriginatingIMID,                                				#9
        $sentTime,                      									#10
        $CATmanualFlag,                                     				#11
        $CATelectronicDupFlag,                              				#12
        $CATelectronicTimestamp,                            				#13
        $CATsenderIMID = "146310:SUMZ",            							#14
        $CATdestination=&get_destination($dest),				        #15
        $CATdestinationType=&get_dest_type(&get_destination($dest)),		            #16
        $CATroutedOrderID=$lroms->[1],           							#17
        $CATsession=&session_id($CATdestinationType,$CATdestination),		#18
        $CATside=&convert_side($lroms->[6]),                         		#19
        $CATprice=&checkPrice($lroms->[8], $lroms->[4]),              		#20
        $CATquantity=$lroms->[7],                                        	#21
        $CATminQty,                                         				#22
        $CATorderType=&convert_type($lroms->[4]),                         	#23
        $CATtimeInForce=&checkTif($lroms->[5],$lroms->[2], $lroms->[47]),                 #24
        $CATtradingSession=&checkSessions(&create_time_str($lroms->[2]),$lroms->[5]),		    #25
        $CATaffiliateFlag[1],                               				#26
        $CATisoInd,                                         				#27
        $CAThandlingInstructions=&setHandlingInstructions($CATtype[2],$instruction), #,$lroms->[53]),   	#28
        $CATrouteRejectedFlag=&checkReject($lroms->[1]),    				#29 
        $CATdupROIDCond,                         							#30
        $CATseqNum,                                         				#31
        $CATmultiLegInd,                                    				#32
        $CATpairedOrderID,                                  				#33
        $CATinfoBarierID,                                   				#34
        $CATnetPrice,                                       				#35
        $CATquoteKeyDate,                                   				#36
        $CATquoteID                                         				#37
    );
    my $lf = $file_h->{"file"};
    print $lf $output;
}

sub create_order_modify {
    my $lroms = shift;
	my $fixed_roid = shift;
    my $output = sprintf("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n",
        $CATactionType,                                                           #1
        $CATerrorROEID,                                                           #2
        $CATfirmROEID=&create_fore_id($lroms->[3], $lroms->[37], &create_time_str($lroms->[2]), $lroms->[51], $CATtype[4]),    #3
        $CATtype[4],                                                              #4
        $CATReporterIMID,                                                         #5
        $CATorderKeyDate=&getOriginalTime($lroms->[37], $lroms->[2]),			  #6
        $CATorderID=$lroms->[37],                                                 #7
        $CATsymbol=&get_symbol($lroms->[13],$lroms->[14] ,$lroms->[50]),         #8
        $CATpriorOrderKeyDate,                                                    #9
        $CATpriorOrderID,                                                         #10
        $CAToriginatingIMID,                                                      #11
        $CATeventTimestamp=&create_time_str($lroms->[2]), #&getModifyTime($lroms->[1], $lroms->[2]),              #12
        $CATmanualFlag,                                                           #13
        $CATmanualOrderKeyDate,                                                   #14
        $CATmanualOrderID,                                                        #15
        $CATelectronicDupFlag,                                                    #16
        $CATelectronicTimestamp,                                                  #17
        $CATreceiverIMID,                      							  		  #18
        $CATsenderIMID="",	                                 					  #19
        $CATsenderType,		                       								  #20 
        $CATroutedOrderID="",			        								  #21
        $CATrequestTimestamp=&getModifyTime($lroms->[1],$replacereqtimes{$lroms->[36]}), #$CATrequestTimestamp,                                                     #22
        $CATreservedForFutureUse,                                                 #23
        $CATreservedForFutureUse,                                                 #24
        $CATreservedForFutureUse,                                                 #25
        $CATinitiator,			                                                  #26
        $CATside=&convert_side($lroms->[6]),                                      #27
        $CATprice=&checkPrice($lroms->[8], $lroms->[4]),                          #28
        $CATquantity=$lroms->[7],                                                 #29
        $CATminQty,                                                               #30
        $CATleavesQty=$lroms->[12],                                               #31
        $CATorderType=&convert_type($lroms->[4]),                                 #32
        $CATtimeInForce=&checkTif($lroms->[5], $lroms->[2], $lroms->[47]),                      #33
        $CATtradingSession=&checkSessions(&create_time_str($lroms->[2]),$lroms->[5]),			      #34
        $CATisoInd,                                                               #35
        $CAThandlingInstructions=&setHandlingInstructions($CATtype[4],$instruction), #,$lroms->[53]),			  #36
        $CATcustDspIntrFlag,                                                      #37
        $CATinfoBarierID,                                                         #38
        $CATaggregatedOrders,                                                     #39
        $CATrepresentativeInd,                                                    #40
        $CATseqNum,                                                               #41
        $CATatsField,                                                             #42
        $CATatsField,                                                             #43
        $CATatsField,                                                             #44
        $CATatsField,                                                             #45
        $CATatsField,                                                             #46
        $CATatsField,                                                             #47
        $CATatsField,                                                             #48
        $CATatsField,                                                             #49
        $CATatsField,                                                             #50
        $CATatsField,                                                             #51
        $CATatsField,                                                             #52
        $CATnetPrice                                                              #53
    );
    my $lf = $file_h->{"file"};
    print $lf $output;
}

sub create_order_cancel {
    my $lroms = shift;
    my $output = sprintf("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n",
        $CATactionType,                                             							#1
        $CATerrorROEID,                                             							#2
        $CATfirmROEID=&create_fore_id($lroms->[3], $lroms->[37], &create_time_str($lroms->[2]), $lroms->[51], $CATtype[3]),    #3
        $CATtype[3],                                                							#4
        $CATReporterIMID,                                           							#5
        $CATorderKeyDate=&getOriginalTime($lroms->[37], $lroms->[2]),    						#6
        $CATorderID=$lroms->[37],                                   							#7
        $CATsymbol=&get_symbol($lroms->[13],$lroms->[14] ,$lroms->[50]), 						#8
        $CAToriginatingIMID,                                        							#9
        $CATeventTimestamp=&create_time_str($lroms->[2]),    									#10
        $CATmanualFlag,                                            								#11
        $CATelectronicTimestamp,                                    							#12
        $CATcancelQty=&determine_cancelled_qty($lroms->[7],$lroms->[11]),         				#13
        $CATleavesQty=$lroms->[12],					                							#14
        $CATinitiator,               															#15
        $CATseqNum,                                                 							#16
        $CATrequestTimestamp=&get_req_time($cancelreqtimes{$lroms->[1]},$lroms->[2]),     		#17
        $CATinfoBarierID                                            							#18
    );
    my $lf = $file_h->{"file"};
    print $lf $output;
}

sub getModifyTime {
    #my $myLastID = shift;
    my $myDefRomTime = shift;
    my $time = shift; #$reptimes{$myLastID};
    if(defined $time) {
        $time;
    } else {
        #print "Could not find Rep sending time for $myLastID \n";
        &create_time_str($myDefRomTime);
    }
}

sub getOriginalTime {
    my $id = shift;
    my $myDefTime = shift;
    my $time = $orig_times{$id};
    if(defined $time) {
        $time;
    } else {
        #print "Could not find original sending time for $id \n";
        &create_time_str($myDefTime);
    }
}

sub checkReject {
	my $id = shift;
	my $rej = $rejects{$id};
	if(defined $rej) {
		$rej;
	} else {
		"false";
	}
}

sub determine_cancelled_qty {
    my $size = shift;
    my $cum = shift;
    my $rez = $size - $cum;
    if($rez < 0) {
        $rez=0;
    }
    $rez;
}

sub create_file {
	my $who = shift;
	my $input_day = shift;
	my $vendor=shift;
	if(defined $input_day){
		sprintf("%s_SUMZ_%d_%sEquity_OrderEvents_%06d.csv", $who, $input_day, $vendor, $sequence +14);
	}else{
		my $sec;
		my $min;
		my $hour;
		my $mday;
		my $mon;
		my $year;
		my $wday;
		my $yday;
		my $isdst;
		($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);
		sprintf("%s_SUMZ_%04d%02d%02d_%sEquity_OrderEvents_%06d.csv", $who, $year + 1900, $mon + 1, $mday, $vendor, $sequence +14);
	}
}

sub set_file {
    my $mpid = shift;
    my $source = shift;
	my $file_name = &create_file($mpid, $input_day, $source);
    my $conn = {};
    my $FILEH;
    open($FILEH, ">", $file_name) or die "cannot open $file_name\n";
    $conn->{"file"} = $FILEH;
    $conn->{"rec"} = 0;
    $conn;
}


sub create_fore_id {
    my $account = shift;
    my $orderID = shift;
    my $eventDate = shift;
    my $source = shift;
    my $event=shift;
    if($source eq "DASHLB" or $source eq "ACTSUMOMETALSOP" or $source eq "ACTSUMOMETALS"){
    	$orderID = substr($orderID,16,length($orderID)-16)
    }
    my $sublength=length($account)+length($orderID)+length($source);
    if($sublength > 44){
    	$account =""
    }
    $sequence += 1;
    sprintf("%s_%s%s%s%d%s", substr($eventDate, 0, 8), $account, $orderID, $source, $sequence, $event);
}

sub convert_side
{
    my $side = shift;
    if(defined $side) {
        if($side eq "Buy") {
            "B";
        } elsif($side eq "Sell") {
            "SL";
        } elsif($side eq "SellShort") {
            "SS";
        } elsif($side eq "SellShortExempt") {
            "SX";
        }
    }
}

sub create_tif_day_date {
    my $utcDate = shift;
    my $local = &create_time_str($utcDate);
    substr($local, 0,8);
}

sub create_time_str {
    my $time_str = shift;
    if ($time_str =~ /(\d{4})(\d{2})(\d{2})-(\d{2}):(\d{2}):(\d{2}).(\d{3})/) {
        my $time = timegm($6, $5, $4, $3, $2 - 1, $1);
        my $milli = $7;
        #print "$milli\n";
        my ($sec, $min, $hour, $mday, $mon, $year) = localtime($time);
        if ($iscentral > 0) {
            $hour += 1;
        }
        sprintf("%04d%02d%02d %02d%02d%02d.%03d",
            $year + 1900, $mon + 1, $mday, $hour, $min, $sec, $milli);
    }
    elsif ($time_str =~ /(\d{4})(\d{2})(\d{2})-(\d{2}):(\d{2}):(\d{2})/) {
        my $time = timegm($6, $5, $4, $3, $2 - 1, $1);
        my ($sec, $min, $hour, $mday, $mon, $year) = localtime($time);
        if ($iscentral > 0) {
            $hour += 1;
        }
        sprintf("%04d%02d%02d %02d%02d%02d.000",
            $year + 1900, $mon + 1, $mday, $hour, $min, $sec);
    }
}

sub checkPrice {
    my $price = shift;
    my $type = shift;
    if($type eq "Market") {
        "";
    } else {
    	my $decimal = index($price, ".")+1;
	 	$price = substr($price,0,$decimal).substr($price,$decimal,8);
        #$price;
    }
}

sub checkTif {
	my $tif = shift;
	my $time = shift;
	my $expiretime = shift;
	my $rtif;
	if (uc($tif) eq "DAY") {
		$rtif = "DAY=" . &create_tif_day_date($time);
	}elsif(uc($tif) eq "GTD"){
		$rtif = "GTT=" . &create_time_str($expiretime);
	}else{
		my $rtif=$tif
	}
}

sub convert_type {
	my $type = shift;
	if($type eq "Market" or $type eq "MarketOnClose") {
		"MKT";
	} elsif($type eq "Limit" or $type eq "LimitOnClose") {
		"LMT";
	} else {
		$type
	}
}

sub clean_sym
{
    my $sym = shift;
    if(defined $sym) {
        $sym =~ s/\// /g;
        $sym =~ s/\./ /g;
    }
    $sym;
}

sub setHandlingInstructions{
    my $event = shift;
    my $instr = shift;

    if(($event eq "MENO" or $event eq "MEOM" or $event eq "MEOR") and defined $instr and $instr ne "") {
        	$instr
#     }elsif(($event eq "MENO" or $event eq "MEOM") and (not defined $instr or $instr eq "")) {
#         "DIR|RAR";
#     }elsif($event eq "MEOR") {
# 		"RAR";
	} else {
		""}
}

sub get_req_time {
	my $request_time=shift;
	my $cancel_time=shift;
	if(not defined $request_time){
		""	#&create_time_str($cancel_time)
	}else{
		$request_time
	}
}

sub get_cancel_initiator {
	my $request_time=shift;
	if(not defined $request_time){
		my $initiator="F"
	}else{
		my $initiator="C"
	}
}

sub get_clear_account {
	my $account=shift;
	my $clraccount=shift;
	my $fdid;
	if(defined $clraccount and $clraccount ne ""){
		$fdid=$clraccount
	}elsif(defined $account and $account ne ""){
		$fdid=$account
	}else{
		$fdid="whatsup"
	}

}

sub session_id {
	my $desttype=shift;
	my $dest=shift;
	if($desttype eq "E" and defined $sessionids{$dest}){
		$sessionids{$dest}
	}elsif($desttype eq "F"){
		""
	}else{
		print("Need session id for the destination ", $dest, "!!!!\n")
	}
}

sub get_symbol {
	my $base=shift;
	my $suffix=shift;
	my $futcode=shift;
	my $sym;
	if($suffix ne ""){
		$sym=$base . " " . $suffix
	}elsif($base eq "SPX" and substr($futcode,0,4) eq "SPXW"){
		$sym=substr($futcode,0,4)
	}else{
		$sym=$base
	}
}

sub get_destination{
	my $broker=shift;
	my $dest;
	if(defined $broker and defined $destination{$broker}){
		$dest=$destination{$broker}
	}else{
		$dest="NoDestination"
	}
}

sub get_dest_type {
    my $dest = shift;
    my $dtype =  $desttypes{$dest};
    if(defined $dtype) {
        $dtype;
    } else {
        "F";
    }
}

sub checkSessions {
    my $time = substr(shift,9,12);
    my $tif = shift;
    if($tif eq "GTC"){
    	"ALL"
    }elsif($time le "093000.000") {
        "PREREG";
    }elsif($time ge "160000.000") {
        "REGPOST";
    }elsif($time ge "093000.000" and $time le "160000.000") {
        "REG";
    }else {
        "SESSIONS";
    }
}

# sub checkSessions {
#     my $time = substr(shift,9,12);
#     my $eventype = shift;
#     if($time le "09:30:00.000") {
#         "PRE";
#     }elsif($time ge "16:00:00.000") {
#         "POST";
#     }elsif($time ge "09:30:00.000" and $time le "16:00:00.000") {
#         "REG";
#     }else {
#         "SESSIONS";
#     }
# }

# sub checkSessions {
#     my $time = substr(shift,9,12);
#     my $eventype = shift;
#     if($time le "09:30:00.000" and ($eventype eq "MENO" or $eventype eq "MEOM" or $eventype eq "MEOR")) {
#         "PRE";
#     }elsif($time ge "16:00:00.000" and ($eventype eq "MENO" or $eventype eq "MEOM" or $eventype eq "MEOR")) {
#         "POST";
#     }elsif($time ge "09:30:00.000" and $time le "16:00:00.000" and $eventype eq "MEOC") {
#         "ALL";
# 	}elsif($time ge "16:00:00.000" and $eventype eq "MEOC") {
#         "ALL"; 
#     }else {
#         "REG";
#     }
# }

# sub get_routed_id_for_modify {
#     my $myLastID = shift;
#     my $route_id = shift;
#     my $om_ex_tag = shift;
#     my $time = $reptimes{$myLastID};
#     if(defined $time) {
# 		if(length($route_id) < 5) {
# 			$om_ex_tag;
# 		} else {
# 			$route_id;
# 		}
#    } else {
# 		$om_ex_tag
#    }
# }

# sub getSymbol { #not being used
#     my $sym = shift;
#     $sym =~ s/_/ /g;
#     $sym;
# }

