#!/usr/bmn/perl -w
use strict;
use warnings FATAL => 'all';
use Time::Local;
use Net::SMTP;

my $input_day = shift;

my $CATReporterIMID = "SUMZ";#"DART";
my $CATSubmitterID = "146310";#"140802";

my %non_reports = (
);

#we need sessionid for all destination.
my %sessionids = (
    'ARCA'=>'PDART07',
    'NSDQ'=>'DEGSR1');
    
# my %accountHolderType = (
# 	'MarketMaker' => 'O',
# 	'Customer' => 'A',
# 	'ProCustomer' => 'A',
# 	'Agency' => "P"
# );

#accountHolderType
my %accountHolderType = (
 	'3NM71209' => 'O'
);

my %initiator = (
	'3NM71209' => 'C',
	'AVTT1209' => 'F',
	'sumo.rsimik' => 'C'
);

my $iscentral = 0;
my %orderid;
my %replaced;
my %canceled;
my %outs;
my %rejects;
my %orig_times;
my %reptimes;
my %canceltimes;
my $sequence = 1;
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
my $CATtradingSession="ALL";
my $CATcustDspIntrFlag="false";
my $CATinfoBarierID="";
my $CATaggregatedOrders="";
my $CATnegotiatedTradeFlag="";
my $CATrepresentativeInd="N";
my $CATseqNum = "";
my $CATsenderIMID="146310:SUMZ";
#my $CATdestination="140802:DART";
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
my $CATreservedForFutureUse="";
my $CATexchOriginCode="";
my $CATdestinationType="F";
my $CATsession="";
my $CATreceiverIMID="";
my $blank="";
my $CATopenCloseIndicator="";
# temporary variables for 2d
my $CATnetPrice="";
my @CATdeptType = ("O","A","T");
my $CATminQty="";
my @CATaccountHolderType = ("O","A","P");
my @CATaffiliateFlag = ("TRUE","FALSE");
my $CATleavesQty=0;
my $CATinitiator="F";
my $CATrequestTimestamp="";
my @CATsenderType = ("E","O","F",""); #line 112
my @CAThandlingInstructions=("DIR","RAR","ALG","PEG","");
my $CATsetHandlingInstructions="ALG";

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

my %replacerej;

# pub enum OrderTypes {
#     Market,
#     Limit,
#     Stop,
#     StopLimit,
#     MarketOnClose,
#     WithOrWithout,
#     LimitOrBetter,
#     LimitWithOrWithout,
#     OnBasis,
#     OnClose,
#     LimitOnClose,
#     ForexMarket,
#     PreviouslyQuoted,
#     PreviouslyIndicated,
#     ForexLimit,
#     ForexSwap,
#     ForexPreviouslyQuoted,
#     Funari,
#     Pegged,
#     Unknown(String),
# }

# pub enum Status {
#     New,
#     Open,
#     Filled,
#     PartialFill,
#     DoneForDay,
#     Cancelled,
#     CancelRequested,
#     CancelPending,
#     Replaced,
#     ReplaceRequested,
#     ReplacePending,
#     CancelRejected,
#     ReplaceRejected,
#     Rejected,
#     Expired,
#     Stopped,
#     Suspended,
#     PendingNew,
#     Calculated,
#     Restated,
#     Trade,
#     TradeCorrect,
#     TradeCancel,
#     OrderStatus,
#     TradeInClearingHold,
#     TradeReleasedToClearing,
#     Triggered,
#     Locked,
#     Released,
#     Unknown,
# }

# pub enum OrderSides {
#     Buy,
#     Sell,
#     SellShort,
#     Undisclosed,
#     BuyMinus,
#     SellPlus,
#     SellShortExempt,
#     Cross,
#     CrossShort,
#     CrossShortExempt,
#     AsDefined,
#     Opposite,
#     Subscribe,
#     Redeem,
#     Lend,
#     Borrow,
#     SellUndisclosed,
#     Unknown(String),
# }
#### create hasmaps on the fly
my %exchid;
my %desttypes;

my @files = <*parent*.txt>; #119
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
				$exchid{$lroms[21]}="SREX";
			}else{
				$exchid{$lroms[21]}=$lroms[21];
			}
			if($lroms[21] eq "SREX" or $lroms[21] eq ""){
				$desttypes{$lroms[21]}="F"
			} elsif($lroms[21] ne "") {
				$desttypes{$lroms[21]}="E"
			}
			$exCode=$lroms[21];
		}
    }
    close(IN);
}

# foreach my $type (sort keys %desttypes) {
#     print "$type => $desttypes{$type}\n";
# }

@sfiles = <*parent*.txt>;
# @sfiles =  sort {
# 	($a =~ /_(\d+)/)[0] <=> ($b =~ /_(\d+)/)[0]
# } @files;

foreach my $file (@sfiles) {
	open(IN, "<$file") or die "cannot open $file\n";
	while(<IN>) { 
		chomp;
		my @lroms = split(/,/);
		my $sym = $lroms[13];
        if($sym eq "ZVZZT") {
			#print "Test order: $sym, $lroms[28], $lroms[13], $lroms[55] \n";
			#print "Test order: \n";
		} else {
			if ($lroms[15] eq "OPTION" and $lroms[30] eq "SingleSecurity")  {
				if( $lroms[0] eq "New") {
					#$outs{$lroms[1]} = $lroms[49];
					$orig_times{$lroms[55]} = &create_time_str($lroms[2]);
				}
				if( $lroms[0] eq "Open") {
					$outs{$lroms[1]} = $lroms[49];
				}
				if( $lroms[0] eq "ReplaceRequested") {
					$reptimes{$lroms[1]} = &create_time_str($lroms[2]);
					$replaced{$lroms[36]} = $lroms[1];
				}
				if($lroms[0] eq "Rejected") {
					$rejects{$lroms[1]} = "true";
					#$outs{$lroms[1]} = $lroms[1];
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
	}
	close(IN);
}

# foreach my $ot (sort keys %orig_times) {
#     print "$ot => $orig_times{$ot}\n";
# }

foreach my $file (@sfiles) {
	open(IN, "<$file") or die "cannot open $file\n";

	while (<IN>) {
		chomp;
		my @romfields = split(/,/);
		my $sym = $romfields[13];
        if($sym eq "ZVZZT") {
			#print "Test order: $sym, $romfields[28], $romfields[13], $romfields[55] \n";
		} elsif(defined $romfields[55]) {
			if ($romfields[15] eq "OPTION" and $romfields[30] eq "SingleSecurity")  {
				my $imid = "146310:SUMZ";
				if($romfields[0] eq "New" ) {
					my $OrderID=$romfields[55];
					my $origTime=$orig_times{$romfields[55]};
					&create_new_order(\@romfields, $OrderID);
					&create_order_routed(\@romfields, $origTime, $OrderID);
				}  
				if($romfields[0] eq "Cancelled") {
					&create_order_cancel(\@romfields);
				}
				if($romfields[0] eq "Replaced") {
# 					my $OrderID=$romfields[55];
# 					my $origTime=$orig_times{$romfields[55]};
# 					&create_order_modify(\@romfields, $OrderID);
# 					&create_order_routed(\@romfields, $origTime, $OrderID);
					my $roid = $romfields[1];
					&create_order_modify(\@romfields, $roid);
					&create_order_routed(\@romfields, &getModifyTime($romfields[1], $romfields[2]), $roid);
				}
			}
		}
	}
	close(IN);
}

sub create_new_order {
	my $lroms = shift;
	my $orderid = shift;
	my $output = sprintf("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n",
		$CATactionType,                                                                                #1
		$CATerrorROEID ,                                                                               #2
		&create_fore_id($lroms->[3], $lroms->[55], $lroms->[2], $lroms->[51]),                         #3 firmROEID
		$CATtype[5],                                                                                   #4
		$CATReporterIMID,                                                                              #5
		&create_time_str($lroms->[2]),                                                                 #6 orderKeyDate
		$lroms->[55],                                                                                  #7 orderID
		&getSymbol($lroms->[13],$lroms->[16], $lroms->[17], $lroms->[18], $lroms->[20], $lroms->[23]), #8 optionID
		&create_time_str($lroms->[2]),                                                                 #9 eventTimeStamp
		$CATmanualFlag,                                                                                #10 
		$CATmanualOrderKeyDate,                                                                        #11
		$CATmanualOrderID,                                                                             #12
		$CATelectronicDupFlag,                                                                         #13
		$CATelectronicTimestamp,                                                                       #14
		$CATdeptType[2],                                                                               #15 &&get_dept_type
		&convert_side($lroms->[6]),                                                                    #16 side
		&checkPrice($lroms->[8], $lroms->[4]),                                                         #17 price
		$lroms->[7],                                                                                   #18 quantity
		$CATminQty,                                                                                    #19 &&get_minqty
		&convert_type($lroms->[4]),                                                                    #20 orderType
		&checkTif($lroms->[5], $lroms->[2]),                                                           #21 timeInForce
		$CATtradingSession,                                                                            #22
		$CATsetHandlingInstructions, #&setHandlingInstructions($lroms->[44], $lroms->[44], $CATtype[5]),                             #23 &&handlingInstruction
		$lroms->[28], #&create_firm_id($lroms->[12],$lroms->[46]),                                      #24 firmDesignatedID
		&getAccountHolderType($lroms->[28]),                                                           #25 &&get_account_holder_type
		$CATaffiliateFlag[1],                                                                          #26 &&get_affiliation
		$CATaggregatedOrders,                                                                          #27
		$CATsolicitationFlag,                                                                          #28
		$CATopenCloseIndicator, #&getOpenClose($lroms->[43]),                                                                   #29 openCloseIndicator
		$CATrepresentativeInd,                                                                         #30
		$CATretiredFieldPosition,                                                                      #31
		$CATRFQID,                                                                                     #32
		$CATnetPrice                                                                   				   #33
	);
	my $lf = $file_h->{"file"}; 
	print $lf $output;

}

sub create_order_routed {
	my $lroms = shift;
	my $sentTime = shift;
	my $fixed_roid = shift;		
	my $output = sprintf("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n",
		$CATactionType,                                                                                            #1
		$CATerrorROEID,                                                                                            #2
		&create_fore_id($lroms->[3], $lroms->[55], $lroms->[2], $lroms->[51]),                                     #3 firmROEID
		$CATtype[7],                                                                                               #4
		$CATReporterIMID,                                                                                          #5
		&getOriginalTime($lroms->[55], $lroms->[2]),                                                                #6 orderKeyDate
		$lroms->[55],                                                                                              #7 orderID
		&getSymbol($lroms->[13],$lroms->[16], $lroms->[17], $lroms->[18], $lroms->[20], $lroms->[23]),             #8 optionID
		$CAToriginatingIMID,                                                                                       #9 
		&create_time_str($lroms->[2]),                                                                           	 #10 eventTimeStamp
		$CATmanualFlag,                                                                                            #11
		$CATelectronicDupFlag,                                                                                     #12
		$CATelectronicTimestamp,                                                                                   #13
		$CATsenderIMID,                                                    										   #14 sender
		"148743:SREX", #&get_imid_for_dest($lroms->[21]),                                                          #15 destination
		"F", #&get_dest_type($lroms->[21]),                 		                                               #16 destination type
		$lroms->[1],								                                 							   #17 RoutedOrderID
		"", #&getSessionID($lroms->[21]),             				                                                   #18 session ""
		&convert_side($lroms->[6]),                                                                                #19 side
		&checkPrice($lroms->[8], $lroms->[4]),                                                                     #20 price
		$lroms->[7],                                                                                               #21 quantity
		$CATminQty,                                                                                                #22 &&get_minqty
		&convert_type($lroms->[4]),                                                                                #23 orderType
		&checkTif($lroms->[5], $lroms->[2]),                                                                       #24 timeInForce
		$CATtradingSession="ALL", #&checkSessions($lroms->[21]),                                                                              #25
		$CATsetHandlingInstructions, #&setHandlingInstructions($lroms->[44], $lroms->[44], $CATtype[7]),                                         #26 &&handlingInstruction
		&checkReject($lroms->[1]),                                                                                 #27 routeRejectedFlag
		$CATexchOriginCode,	                                                        							   #28
		$CATaffiliateFlag[1],                                                                                      #29 &&get_affiliation
		$CATmultiLegInd,                                                                                           #30
		$CATopenCloseIndicator, #&getOpenClose($lroms->[43]),                                                                               #31 openCloseIndicator
		$CATretiredFieldPosition,                                                                                  #32
		$CATretiredFieldPosition,                                                                                  #33
		$CATpairedOrderID,                                                                                         #34
		$CATnetPrice     
	);
	my $lf = $file_h->{"file"};
	print $lf $output;
}

sub create_order_modify {
	my $lroms = shift;
	my $fixed_roid = shift;
	my $output = sprintf("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n",
		$CATactionType,                                                                                      #1
		$CATerrorROEID,                                                                                      #2
		&create_fore_id($lroms->[3], $lroms->[55], $lroms->[2], $lroms->[51]),                               #3 firmROEID
		$CATtype[9],                                                                                         #4
		$CATReporterIMID,                                                                                    #5
		&getOriginalTime($lroms->[55], $lroms->[2]),                                                          #6 orderKeyDate
		$lroms->[55],                                                                                        #7 orderID
		&getSymbol($lroms->[13],$lroms->[16], $lroms->[17], $lroms->[18], $lroms->[20], $lroms->[23]),       #8 OptionID
		$CATpriorOrderKeyDate,                                                                               #9
		$CATpriorOrderID,                                                                                    #10
		$CAToriginatingIMID,                                                                                 #11
		&getModifyTime($lroms->[1], $lroms->[2]),                                                            #12 eventTimestamp
		$CATmanualOrderKeyDate,                                                                              #13
		$CATmanualOrderID,                                                                                   #14
		$CATmanualFlag,                                                                                      #15
		$CATelectronicDupFlag,                                                                               #16
		$CATelectronicTimestamp,                                                                             #17
		$CATreceiverIMID,                                                									 #18 receiver IMID senderIMID should be ""
		"",	#$CATsenderIMID,                      		                                      				 #19 senderIMID should be ""
		$CATsenderType[3],                                                    								 #20 senderType should be ""
		$lroms->[1],				  #&get_routed_id_for_modify($lroms->[12],$lroms->[3],$lroms->[28]),     #21 routedOrderID 
		$CATinitiator,                                                                                       #22 "F"
		&convert_side($lroms->[6]),                                                                          #23 side
		&checkPrice($lroms->[8], $lroms->[4]),                                                               #24 price
		$lroms->[7],                                                                                         #25 quantity
		$CATminQty,                                                                                          #26 &&get_minqty
		$lroms->[12],                                                                                        #27 leaveqty
		&convert_type($lroms->[4]),                                                                          #28 orderType
		&checkTif($lroms->[5], $lroms->[2]),                                                                 #29 timeInForce
		$CATtradingSession="ALL", #&checkSessions($lroms->[21]),                                                                        #30
		$CATsetHandlingInstructions, #&setHandlingInstructions($lroms->[44], $lroms->[44], $CATtype[9]),                                   #31  &&handlingInstruction
		$CATopenCloseIndicator, #&getOpenClose($lroms->[43]),                                                                         #32 openCloseIndicator
		$CATrequestTimestamp,                                                                                #33 &&get_request_time
		$CATreservedForFutureUse,                                                                            #34
		$CATaggregatedOrders,                                                                                #35
		$CATrepresentativeInd,                                                                               #36
		$CATretiredFieldPosition,                                                                            #37
		$CATretiredFieldPosition,                                                                            #38
		$CATnetPrice                                                                                         #39 &&get_net_price
	);
	my $lf = $file_h->{"file"};
	print $lf $output;
}
sub create_order_cancel {
	my $lroms = shift;
	my $output = sprintf("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n",
		$CATactionType,                                                                                 #1
		$CATerrorROEID ,                                                                                #2
		&create_fore_id($lroms->[3], $lroms->[55], $lroms->[2], $lroms->[51]),                          #3 firmROEID
		$CATtype[8],                                                                                    #4
		$CATReporterIMID,                                                                               #5
		&getOriginalTime($lroms->[55], $lroms->[2]),                                                    #6 orderKeyDate
		$lroms->[55],                                                                                   #7 orderID
		&getSymbol($lroms->[13],$lroms->[16], $lroms->[17], $lroms->[18], $lroms->[20], $lroms->[23]),  #8 optionID
		$CAToriginatingIMID,                                                                            #9
		&create_time_str($lroms->[2]),                                     #10 eventTimestamp
		$CATmanualFlag,                                                                                 #11 
		$CATelectronicTimestamp,                                                                        #12
		&determine_cancelled_qty($lroms->[7],$lroms->[11]),                                             #13 cancelQty
		$lroms->[12],	##$CATleavesQty,                                                                #14 &&get_leave_qty
		$CATinitiator,                                                                                  #15
		$CATretiredFieldPosition,                                                                       #16
		$CATrequestTimestamp,                                                                           #17 &&get_request_time
	);
	my $lf = $file_h->{"file"};
	print $lf $output;
}

#&get_routed_id_for_modify_sumo($lroms->[3], $lroms->[28])
# sub get_routed_id_for_modify_sumo {
# 	my $route_id = shift;
#     my $om_ex_tag = shift;
#     if(length($route_id) < 5) {
#         $om_ex_tag;
#     } else {
#         $route_id;
#     }
# 
# }

sub determine_cancelled_qty {
	my $size = shift;
	my $cum = shift;
	my $rez = $size - $cum;
	if($rez < 0) {
		$rez = 0;
	}
	$rez;
}


sub create_file {
	my $who = shift;
	my $input_day = shift;
	if(defined $input_day){
		sprintf("%s_SUMZ_%d_SRockOption_OrderEvents_%06d.csv", $who, $input_day, $sequence +33);
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
		sprintf("%s_SUMZ_%04d%02d%02d_SRockOption_OrderEvents_%06d.csv", $who, $year + 1900, $mon + 1, $mday, $sequence +33);
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
 

sub getOpenClose {
	my $oc = shift;
	if($oc eq "1" or $oc eq "Open") {
		"Open";
	} else {
		"Close";
	}
}

sub convert_side
{
	my $side = shift;
	if(defined $side) {
		if($side eq "Buy") {
			"B";
		} else {
			"S";
		}
	}
}
sub getModifyTime {
	my $myLastID = shift;
	my $myDefRomTime = shift;
	my $time = $reptimes{$myLastID};
	if(defined $time) {
		$time;
	} else {
		print "Could not find Rep sending time for $myLastID \n";
		&create_time_str($myDefRomTime);
	}
}
sub getOriginalTime {
	my $id = shift;
	my $myDefRomTime = shift;
	my $time = $orig_times{$id};
	if(defined $time) {
		$time;
	} else {
		print "Could not find original sending time for $id \n";
		&create_time_str($myDefRomTime);
	}
}

sub getAccountHolderType {
	my $account = shift;
	my $ahtype = $accountHolderType{$account};
	if(defined $ahtype) {
		$ahtype;
	} else {
		"P"
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

sub create_tif_day_date {
	my $utcDate = shift;
	my $local = &create_time_str($utcDate);
	substr($local, 0, 8);
}
# sub create_fore_id {
# 	my $romtag = shift;
# 	my $romtime = shift;
# 	$sequence += 1;
# 	sprintf("%s_%s%d", substr($romtime, 0, 8), $romtag, $sequence);
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

sub checkTif {
	my $tif = shift;
	my $time = shift;
	if ($tif eq "3") {
		"IOC";
	}
	else {
		my $rtif = "DAY=" . &create_tif_day_date($time);
		$rtif;
	}
}

sub create_time_str {
	my $cwa = shift;
	if ($cwa =~ /(\d{4})(\d{2})(\d{2})-(\d{2}):(\d{2}):(\d{2}).(\d{3})/) {
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
	elsif ($cwa =~ /(\d{4})(\d{2})(\d{2})-(\d{2}):(\d{2}):(\d{2})/) {
		my $time = timegm($6, $5, $4, $3, $2 - 1, $1);
		my ($sec, $min, $hour, $mday, $mon, $year) = localtime($time);
		if ($iscentral > 0) {
			$hour += 1;
		}
		sprintf("%04d%02d%02d %02d%02d%02d.000",
			$year + 1900, $mon + 1, $mday, $hour, $min, $sec);
	}
}

sub getSymbol {
	my $baseSym = shift;      #5 13
	my $yy = substr(shift,2,2); #16 year
	my $mm = shift;  # month 17
	my $day = shift;          # 18
	my $dstrike = shift;      # 20
	my $putCall = shift;      # 23

	my $strike = ($dstrike * 1000);
	#my$output =sprintf("%-6s%s%02s%02s%s%08d", $baseSym, $yy, $mm, $day,$putCall,$strike);
	my$output =sprintf("%-6s%s%02s%02s%s%08s", $baseSym, $yy, $mm, $day,substr($putCall,0,1),$strike);
	$output;

}
sub checkPrice {
	my $price = shift;
	my $type = shift;
	if($type eq "1" or $type eq "Market") {
		"";
	} else {
		my $decimal = index($price, ".")+1;
	 	$price = substr($price,0,$decimal).substr($price,$decimal,8);
		#$price;
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

sub setHandlingInstructions
{
    my $event = shift;
    my $instr = shift;
    if(($event eq "MONO" or $event eq "MOOM" or $event eq "MOOR") and defined $instr and $instr ne ""){
    	$instr
#     }elsif(($event eq "MONO" or $event eq "MOOM") and not defined $instr) {
#         "DIR|RAR";
#     } elsif ($event eq "MOOR") {
#         "RAR";
    } else {""}
}

# 57 Execution Instruction, 73 AlgoType S message
# sub setHandlingInstructions
# {
#     my $type = shift;
#     my $algoFlag = shift;
#     my $event = shift;
#     if($event eq "MONO") {
#         if(defined $algoFlag and $algoFlag ne "0") {
#             "ALG";
#         } elsif (defined $type) {
#             if($type eq "P" or $type eq "M" or $type eq "R") {
#             	"PEG";
#             } else {
#         		"RAR";
#             }
#         } else {
#             "DIR|RAR";
#         }
#     } elsif ($event eq "MOOR") {
#         "RAR";
#     } else {""}
# }

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

sub getSessionID {
    my $dest = shift;
    my $exch = $sessionids{$dest};
    if(defined $exch) {
        $exch;
    } else {
        "";
   }
}

sub checkSessions {
    my $dest = shift;
    if($dest eq "ARCA") {
        "ALL";
    } else {
        "ALL";
    }
}

#### change note
# go live om 3/25/2022
# 4/11/20222
# modified to read the parent output as the input raw orders
# fixed the script for modified events
# add a hashmap for initiator;
# changed handlinginstruction to "ALG" for all types of events
# changed session = "ALL" from "REG"
# 4/23: blank out 		"",	#$CATsenderIMID and $CATsenderType[3] for modified                                              								 #20 senderType should be ""
# 5/2: modified code to the following
# 					my $OrderID=$romfields[55];
# 					my $origTime=$orig_times{$romfields[55]};
# 					&create_order_modify(\@romfields, $OrderID);
# 					&create_order_routed(\@romfields, $origTime, $OrderID);
#					my $roid = $romfields[1];
#					&create_order_modify(\@romfields, $roid);
#					&create_order_routed(\@romfields, &getModifyTime($romfields[1], $romfields[2]), $roid);
# 20220520: changed if($romfields[0] eq "Open" ) to if($romfields[0] eq "New" ) for MONO/MOOR events
# 20220524: changed from $canceltimes{$lroms->[1]} to #&create_time_str($lroms->[2])for #10 eventTimestamp
# 20220808: changed the initiator to a default value "F" for MOOM and MOOC from using a hashmap by account.
# 20220914: add "Market" in the condition to determine the price. if($type eq "1" or "Market") 
# 20220922: in the sub getSymbol, changed %08d to %08s when formating the optionID. format %08d drops 0.001 from the strik value causing invalid optionId.
# 20221010: made change in the sub getSymbol to use only the first letter of field 23 Put or Call
# 20230201: updated sub setHandlingInstructions: no DIR/RAR