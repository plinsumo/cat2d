#!/usr/bin/perl
use strict;
use warnings;
use Time::Local;
use Net::SMTP;

my $input_day = shift;

my $CATReporterIMID = "SUMZ";
my $CATSubmitterID = "146310";
##SUMO CRD 146310
##GS CRD 361

#use ClearingAccount or SumoSource?
my %senderimids = (
    'SRDROPUAT'=>'146310:SUMZ'
);

my%clientimids = (
    'T.SUMO' => '146310:SUMZ'
);

# my %custAccounts = (
#     'AR161209'=>'AR161209',
# );

my %sessionids = (
    'ARCA'=>'PDART07',
    'NSDQ'=>'DEGSR1');

my %accountHolderType = (
	'MarketMaker' => 'O',
	'Customer' => 'A',
	'ProCustomer' => 'A',
	'Agency' => "P"
);

my %depttypes = (
	'Agency' => 'T',
);

my %initiator = (
	'3NM71209' => 'C',
	'AVTT1209' => 'F',
	'sumo.rsimik' => 'UNKNOW'
);

my $iscentral = 0;
my %reptimes;
my %canceltimes;
my %outs;
my %orig_times;
my %rejects;
my %replacerej;
my %replaced;
my %canceled;

my $sequence = 1;
my $file_sequence = 15;
my $file_h = &set_file($CATSubmitterID);


# Variables for 2d
my $CATactionType = "NEW";
my $CATerrorROEID = "";
my @CATtype = ("MENO","MEOA","MEOR","MEOC","MEOM","MONO","MOOA","MOOR","MOOC","MOOM","MLOR","MLNO","MLOA","MLOM","MLOC");
my $CATmanualFlag="false";
my $CATelectronicDupFlag="false";
my $CATelectronicTimestamp="";
my $CATmanualOrderKeyDate="";
my $CATmanualOrderID="";
my $CATsolicitationFlag="false";
my $CATRFQID = "";
my $CATtradingSession="REG";
my $CATcustDspIntrFlag="false";
my $CATinfoBarierID="";
my $CATaggregatedOrders="";
my $CATnegotiatedTradeFlag="false"; ### should be boolean!!!!
my $CATrepresentativeInd="N";
my $CATseqNum = "";
my $CATatsField="";
my $CATreceiverIMID=$CATSubmitterID.":".$CATReporterIMID;
my $CATsenderIMID = "146310:SUMZ";
my $CATisoInd="NA";
my $CATpairedOrderID = "";
my $CAToriginatingIMID="";
my $CATmultiLegInd="false";
my $CATquoteKeyDate="";
my $CATquoteID="";
my $CATpriorOrderKeyDate="";
my $CATpriorOrderID="";
my $CATreserved="";
my $CATrouteRejectedFlag="false";
my $CATretiredFieldPosition="";
my $CATdupROIDCond="false";

# temporary variables for 2d
my $CATnetPrice="";
my @CATdeptType = ("O","A","T");
my $CATminQty="";
my @CATaccountHolerType = ("O","A","P");
my @CATaffiliateFlag = ("TRUE","FALSE");
my $CATleavesQty=0;
my $CATinitiator="F";
my $CATrequestTimestamp="";
my @CATsenderType = ("E","O","F"); #line 112
my @CAThandlingInstructions=("DIR","RAR","ALG","PEG","");


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


#### create hasmaps on the fly
my %exchid;
my %desttypes;

my @files = <*.txt>; #119
my @sfiles =  sort {
    ($a =~ /_(\d+)/)[0] <=> ($b =~ /_(\d+)/)[0]
} @files;

foreach my $file (@sfiles) {
    open(IN, "<$file") or die "cannot open $file\n";
    my $exCode ="";
    my $cap="";
    while(<IN>) {
        chomp;
        my @lroms = split(/,/);
		if ($lroms[21] ne $exCode)  {
			if($lroms[21] eq ""){
				$exchid{$lroms[21]}="INCA";
			}else{
				$exchid{$lroms[21]}=$lroms[21];
			}
			if($lroms[21] eq "INCA" or $lroms[21] eq ""){
				$desttypes{$lroms[21]}="F"
			} elsif($lroms[21] ne "") {
				$desttypes{$lroms[21]}="E"
			}
			$exCode=$lroms[21];
		}
    }
    close(IN);
}

# foreach my $exch (sort keys %exchid) {
#     print "$exch => $exchid{$exch}\n";
# }
# foreach my $type (sort keys %desttypes) {
#     print "$type => $desttypes{$type}\n";
# }
# use ExecTransType to see if a message is to correct or cancel an order.
# New means the message can be used for Cat and should be the first time we have seen this status
# Cancel means that a fill of that order has been "busted" and is no longer good
# Correction will change the attributes of a fill
# ExecTransType is only on Executions so never on new orders or really Cancels and replaces.
# I think you can safely igno


@files = <*.txt>; #119
@sfiles =  sort {
    ($a =~ /_(\d+)/)[0] <=> ($b =~ /_(\d+)/)[0]
} @files;

foreach my $file (@sfiles) {
    open(IN, "<$file") or die "cannot open $file\n";
    while(<IN>) {
        chomp;
        my @lroms = split(/,/);
		if ($lroms[15] eq "EQUITY" and $lroms[30] eq "SingleSecurity")  {
            if( $lroms[0] eq "New") {
				$orig_times{$lroms[55]} = &create_time_str($lroms[2]);
            }
            if( $lroms[0] eq "ReplaceRequested") {
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
			if($lroms[0] eq "CancelRequested") {
				$canceltimes{$lroms[1]} = &create_time_str($lroms[2]);
#					$canceled{$lroms[36]} = $lroms[1];
			}
		}
    }
    close(IN);
}

foreach my $file (@sfiles) {
    open(IN, "<$file") or die "cannot open $file\n";

    while (<IN>) {
        chomp;
        my @romfields = split(/,/);
		my $sym = $romfields[13];
        if($sym eq "ZVZZT") {
			print "Test order: $sym, $romfields[28], $romfields[13], $romfields[55] \n";
		} else {
			if ($romfields[15] eq "EQUITY" and $romfields[30] eq "SingleSecurity")  {
				my $imid = "146310:SUMZ";
				if($romfields[0] eq "New" ) {
				   &create_new_order(\@romfields);
					my $OrderID=$romfields[55];
					my $origTime=$orig_times{$romfields[55]};
					&create_order_routed(\@romfields, $origTime, $OrderID);
				}  
				if($romfields[0] eq "Cancelled") {
						&create_order_cancel(\@romfields);
				}
				if($romfields[0] eq "Replaced") {
					my $OrderID=$romfields[55];
					my $origTime=$orig_times{$romfields[37]};
					&create_order_modify(\@romfields, $OrderID);
					&create_order_routed(\@romfields, $origTime, $OrderID);
				}
			}
		}
    }
    close(IN);
}

sub create_new_order {
    my $lroms = shift;
    my $output = sprintf("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n",
        $CATactionType,                                         #1
        $CATerrorROEID,                                         #2
        &create_fore_id($lroms->[3], $lroms->[55], $lroms->[2], $lroms->[51]),            #3
        $CATtype[0],                                            #4
        $CATReporterIMID,                                       #5
        &create_time_str($lroms->[2]),                          #6 orderKeyDate
        $lroms->[55],                                           #7 orderID
        &getSymbol($lroms->[13],$lroms->[14]),                  #8 symbol
        &create_time_str($lroms->[2]),                          #9 eventTimestamp
        $CATmanualFlag,                                         #10 
        $CATelectronicDupFlag,                                  #11
        $CATelectronicTimestamp,                                #12
        $CATmanualOrderKeyDate,                                 #13
        $CATmanualOrderID,                                      #14
        $CATdeptType[2],                                        #15 
        $CATsolicitationFlag,                                   #16
        $CATRFQID,                                              #17
        &convert_side($lroms->[6]),                             #18
        &checkPrice($lroms->[8], $lroms->[4]),                  #19
        $lroms->[7],                                            #20 quantity
        $CATminQty,                                             #21 &&get_minqty
        &convert_type($lroms->[4]),                             #22 orderType
        &checkTif($lroms->[5], $lroms->[2]),                    #23
        $CATtradingSession,                                     #24
        &setHandlingInstructions($lroms->[44], $lroms->[44], $CATtype[0]),   #25
        $CATcustDspIntrFlag,                                    #26
        $lroms->[28],                                            #27
        &getAccountHolderType($lroms->[34]),                    #28 &&get_account_holder_type
        $CATaffiliateFlag[1],                                   #29 &&get_affiliation
        $CATinfoBarierID,                                       #30
        $CATaggregatedOrders,                                   #31
        $CATnegotiatedTradeFlag,                                #32
        $CATrepresentativeInd,                                  #33
        $CATatsField,                                           #34
        $CATatsField,                                           #35
        $CATatsField,                                           #36
        $CATatsField,                                           #37
        $CATatsField,                                           #38
        $CATatsField,                                           #39
        $CATatsField,                                           #40
        $CATatsField,                                           #41
        $CATatsField,                                           #42
        $CATatsField,                                           #43
        $CATatsField,                                           #44
        $CATatsField,                                           #45
        $CATnetPrice                                            #46 &&get_net_price
    );
    my $lf = $file_h->{"file"};
    print $lf $output;

}

sub create_order_routed {
    my $lroms = shift;
    my $sentTime = shift;
	my $fixed_roid = shift;		
    my $output = sprintf ("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n",
        $CATactionType,                                     #1
        $CATerrorROEID,                                     #2
        &create_fore_id($lroms->[3], $lroms->[55], $lroms->[2], $lroms->[51]),        #3
        $CATtype[2],                                        #4
        $CATReporterIMID,                                   #5
        &getOriginalTime($lroms->[55], $lroms->[2]),        #6
        $lroms->[55],                                       #7
        &getSymbol($lroms->[13],$lroms->[14]),              #8 symbol
        $CAToriginatingIMID,                                #9
        $sentTime,                      					#10
        $CATmanualFlag,                                     #11
        $CATelectronicDupFlag,                              #12
        $CATelectronicTimestamp,                            #13
        $CATsenderIMID,            							#14
        "7897:INCA", #&get_imid_for_dest($lroms->[21]),      #15
        "F", #&get_dest_type($lroms->[21]),                       #16
        $lroms->[1],           								#17
        "", #&getSessionID($lroms->[21]),                        #18
        &convert_side($lroms->[6]),                         #19
        &checkPrice($lroms->[8], $lroms->[4]),              #20
        $lroms->[7],                                        #21
        $CATminQty,                                         #22 &&get_minqty
        &convert_type($lroms->[4]),                         #23
        &checkTif($lroms->[5],$lroms->[2]),                 #24
        &checkSessions($lroms->[21]),                       #25
        $CATaffiliateFlag[1],                               #26 &&get_affiliation
        $CATisoInd,                                         #27
        &setHandlingInstructions($lroms->[44], $lroms->[44], $CATtype[2]),   #28 &handlingInstruction->&setHandlingInstructions
        &checkReject($lroms->[1]),                          #29 
        $CATdupROIDCond,                         			#30 false
        $CATseqNum,                                         #31
        $CATmultiLegInd,                                    #32
        $CATpairedOrderID,                                  #33
        $CATinfoBarierID,                                   #34
        $CATnetPrice,                                       #35
        $CATquoteKeyDate,                                   #36
        $CATquoteID                                         #37
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
        &create_fore_id($lroms->[3], $lroms->[55], $lroms->[2], $lroms->[51]),    #3
        $CATtype[4],                                                              #4
        $CATReporterIMID,                                                         #5
        &getOriginalTime($lroms->[55], $lroms->[2]),                            	  #6
        $lroms->[55],                                                             #7
        &getSymbol($lroms->[13],$lroms->[14]),                                    #8 symbol
        $CATpriorOrderKeyDate,                                                    #9
        $CATpriorOrderID,                                                         #10
        $CAToriginatingIMID,                                                      #11
        &getModifyTime($lroms->[1], $lroms->[2]),                                 #12
        $CATmanualFlag,                                                           #13
        $CATmanualOrderKeyDate,                                                   #14
        $CATmanualOrderID,                                                        #15
        $CATelectronicDupFlag,                                                    #16
        $CATelectronicTimestamp,                                                  #17
        "", #$CATreceiverIMID,                      							#18
        "", #$CATsenderIMID,                                 						  #19
        "", #$CATsenderType[2],                       								  #20 &&get_sender_type F
        $lroms->[1],        													  #21
        $CATrequestTimestamp,                                                     #22
        $CATreserved,                                                          	  #23
        $CATreserved,                                                          	  #24
        $CATreserved,                                                          	  #25
        $CATinitiator,                                                            #26
        &convert_side($lroms->[6]),                                               #27
        &checkPrice($lroms->[8], $lroms->[4]),                                    #28
        $lroms->[7],                                                              #29
        $CATminQty,                                                               #30 &&get_minqty
        $lroms->[12],                                                             #31
        &convert_type($lroms->[4]),                                               #32
        &checkTif($lroms->[5], $lroms->[2]),                                      #33
        &checkSessions($lroms->[21]),                                             #34
        $CATisoInd,                                                               #35
        &setHandlingInstructions($lroms->[44], $lroms->[44], $CATtype[4]),        #36 &handlingInstruction->&setHandlingInstructions
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
        $CATnetPrice                                                              #53 &&get_net_price
    );
    my $lf = $file_h->{"file"};
    print $lf $output;
}

sub create_order_cancel {
    my $lroms = shift;
    my $output = sprintf("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n",
        $CATactionType,                                             #1
        $CATerrorROEID,                                             #2
        &create_fore_id($lroms->[3], $lroms->[55], $lroms->[2], $lroms->[51]),                #3
        $CATtype[3],                                                #4
        $CATReporterIMID,                                           #5
        &getOriginalTime($lroms->[55], $lroms->[2]),               	#6
        $lroms->[55],                                               #7
        &getSymbol($lroms->[13],$lroms->[14]),                                           #8 symbol
        $CAToriginatingIMID,                                        #9
        &create_time_str($lroms->[2]),                              #10
        $CATmanualFlag,                                             #11
        $CATelectronicTimestamp,                                    #12
        &determine_cancelled_qty($lroms->[7],$lroms->[11]),         #13
        $lroms->[12],	##$CATleavesQty,                            #14 &&get_leave_qty;
        $CATinitiator,                                              #15
        $CATseqNum,                                                 #16
        $CATrequestTimestamp,                                       #17 &&get_request_time
        $CATinfoBarierID                                            #18
    );
    my $lf = $file_h->{"file"};
    print $lf $output;
}


sub getModifyTime {
    my $myLastID = shift;
    my $myDefRomTime = shift;
    my $time = $reptimes{$myLastID};
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

sub checkRepRej { #not being used
	my $id = shift;
	my $rej = $replacerej{$id};
	if(defined $rej) {
		$rej;
	} else {
		"false";
	}
}

sub getSessionID {
    my $dest = shift;
    my $exch = $sessionids{$dest};
    if(defined $exch) {
        $exch;
    } else {
        "";
    }
}
sub getOpenClose { #not being used
    my $oc = shift;
    if($oc eq "1") {
        "Open";
    } else {
        "Close";
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
	if(defined $input_day){
		sprintf("%s_SUMZ_%d_SRockEquity_OrderEvents_%06d.csv", $who, $input_day, $file_sequence);
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
		sprintf("%s_SUMZ_%04d%02d%02d_SRockEquity_OrderEvents_%06d.csv", $who, $year + 1900, $mon + 1, $mday, $file_sequence);
	}
}

sub set_file {
    my $mpid = shift;
	my $file_name = &create_file($mpid, $input_day);
    my $conn = {};
    my $FILEH;
    open($FILEH, ">", $file_name) or die "cannot open $file_name\n";
    $conn->{"file"} = $FILEH;
    $conn->{"rec"} = 0;
    $conn;
}

# sub create_header_date { #not being used
#     my $sec;
#     my $min;
#     my $hour;
#     my $mday;
#     my $mon;
#     my $year;
#     my $wday;
#     my $yday;
#     my $isdst;
#     ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);
#     sprintf("%04d%02d%02d", $year + 1900, $mon + 1, $mday);
# 
# }

sub create_fore_id {
    my $account = shift;
    my $orderID = shift;
    my $eventDate = shift;
    my $source = shift;
    my $localRom = &create_time_str($eventDate);
    $sequence += 1;
    sprintf("%s_%s%s%s%d", substr($localRom, 0, 8), $account, $orderID, $source, $sequence);
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

sub get_sender_imid_for_dest {
    my $dest = shift;
    my $imid = $senderimids{$dest};
    if(defined $imid) {
        $imid;
    } else {
        print "Failed to find imid for $dest \n";
        "DEGS";
    }
}

sub get_routed_id_for_modify {
    my $myLastID = shift;
    my $route_id = shift;
    my $om_ex_tag = shift;
    my $time = $reptimes{$myLastID};
    if(defined $time) {
		if(length($route_id) < 5) {
			$om_ex_tag;
		} else {
			$route_id;
		}
   } else {
		$om_ex_tag
   }
}

sub get_sender_imid_for_clrid {
    my $clr_acc = shift;
    my $imid = $clientimids{$clr_acc};
    if(defined $imid) {
        $imid;
    } else {
        "146310:SUMZ";
    }
}

sub get_imid_for_dest {
    my $dest = shift;
    my $exch = $exchid{$dest};
    if(defined $exch) {
        $exch;
    } else {
        print "Failed to find exchange id for $dest \n";
        "";
    }
}

sub get_dest_type {
    my $dest = shift;
    my $dtype =  $desttypes{$dest};
    if(defined $dtype) {
        $dtype;
    } else {
        print "Failed to find desttype from $dest \n";
        "E";
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
    if($tif eq "IOC") {
        "IOC";
    } else {
        my $rtif = "DAY=" . &create_tif_day_date($time);
        $rtif;
    }
}

sub checkSessions {
    my $dest = shift;
    if($dest eq "ARCA") {
        "ALL";
    } else {
        "REG";
    }
}

sub convert_type {
    my $type = shift;
    if($type eq "Market") {
        "MKT";
    } else {
        "LMT";
    }
}

# sub getRoutedID {
#     my $refid = shift;
#     my $backup = shift;
#     my $orig = $outs{$refid};
#     if(defined $orig and length($orig) > 0) {
#         $orig;
#     } else {
#         $backup;
#     }
# }

sub getSymbol {
    my $sym = shift;
    my $suffix = shift;
    if($suffix ne ""){
    	$sym . " " . $suffix
    }else{
    	$sym;
    }
}

# sub clean_sym  #not being used
# {
#     my $sym = shift;
#     if(defined $sym) {
#         $sym =~ s/\// /g;
#         $sym =~ s/\./ /g;
#         $sym =~ s/_/ /g;
#     }
#     $sym;
# }

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

# 57 Execution Instruction, 73 AlgoType E message

# sub setHandlingInstructions{
#     my $type = shift;
#     my $algoFlag = shift;
#     my $event = shift;
#     if($event eq "MENO" or $event eq "MEOA" or $event eq "MEOM") {
#         "DIR|RAR";
#             }elsif($event eq "MEOR") {
# 		"RAR";
# 			} else {
# 		""}
# }

sub getAccountHolderType {
	my $cap = shift;
	my $ahtype = $accountHolderType{$cap};
	if(defined $ahtype) {
		$ahtype;
	} else {
		"P"
	}
}

# sub getCancelTime {
# 	my $roid=shift;
# 	my $time=shift;
# 	if(defined $canceltimes{roid}){
# 		$time = create_time_str($canceltimes{roid})
# 	} else {
# 		$time
# 	}
# }

#### change note
# go live om 3/25/2022
# 20220411 add a sub getCancelTime to allow using the message timestamp for Canceled without CancelRequested.
# add a hashmap for initiator;
# 4/13/2022: add SellShortExempt to the sub convert_side.
# 4/23: blank out $CATreceiverIMID, #$CATsenderIMID and $CATsenderType[3] for modified #20 senderType should be ""
# 20220520: changed if($romfields[0] eq "Open" ) to if($romfields[0] eq "New" ) for MENO/MEOR events
# 20220524: changed from &getCancelTime($lroms->[1], &create_time_str($lroms->[2])) to #&create_time_str($lroms->[2])for #10 eventTimestamp
# 20220808: changed the initiator to a default value "F" for MOOM and MOOC from using a hashmap by account.
# 20230201: updated sub setHandlingInstructions: no DIR/RAR
# 20220928: modify and use getSymbol for to add suffix to the base if exists. sub clean_sym is not used anymore.
# 20230201: updated sub setHandlingInstructions: no DIR/RAR