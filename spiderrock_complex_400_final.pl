#!/usr/bmn/perl -w
use strict;
use warnings FATAL => 'all';
use Time::Local;
use Net::SMTP;

my $input_day = shift;

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
my $CATunderlying = "";
my $CATopenCloseIndicator="";
my $CATsetHandlingInstructions="ALG";

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
my @CATpriceType = ("PU", "TC", "TS");


my %leg5_details;
my $leg;
my $legs;
my $nleg;
my $symbol="";
my $optid ="";
#my $OpenClose="OpenClose";
my %parent5;
my $legid;
my %parent_leg;

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

# foreach my $exch (sort keys %exchid) {
#     print "$exch => $exchid{$exch}\n";
# }
# foreach my $type (sort keys %desttypes) {
#     print "$type => $desttypes{$type}\n";
# }

my %parents;
#my $i =0;
# get the parent of legs
foreach my $file (@files) {
	open(IN, "<$file") or die "cannot open $file\n";
	while(<IN>) {
		chomp;
		my @lroms = split(/,/);
		if ($lroms[15] eq "MLEG" and $lroms[0] eq "New") {
			$parents{$lroms[55]}=$lroms[55];
		}
	}
	close(IN);
};

# foreach my $parent (sort keys %parents) {
#     print "$parent => $parents{$parent}\n";
# };


# my @pids;
# @pids = keys %parents;

my $OpenClose;
my %leg_details;
my %leg_count;
my $same_parent="";
my $i=0;
# build the legs
foreach my $file (@files) {
	open(IN, "<$file") or die "cannot open $file\n";
	while(<IN>) {
		chomp;
		my @lroms = split(/,/);
		if($lroms[0] eq "New" and $lroms[30] eq "IndividualLeg") {
				if($lroms[15] eq "EQUITY" ) {
					$symbol=$lroms[13];
					$optid ="";
					$OpenClose="";
				} else {
					$optid = &getSymbol($lroms[13],$lroms[16], $lroms[17], $lroms[18], $lroms[20], $lroms[23]),
					$symbol="";
					$OpenClose="", #&getOpenClose($lroms[43]),
				}
				if ($lroms[55] ne $same_parent) {
					$same_parent=$lroms[55];
					$legs = "";
					$i = 1; #$i +1;
					$leg = sprintf("%s@%s@%s@%s@%s@%s|",
						$lroms[31],
						$symbol,
						$optid,
						$OpenClose, 
						&convert_side($lroms[6]),
						$lroms[7]);
					$legs = sprintf("%s%s",$legs,$leg);
					$leg_details{$parents{$lroms[55]}} = $legs
				} else {
					$leg = sprintf("%s@%s@%s@%s@%s@%s|",
						$lroms[31],	#$parents{$lroms[37]},
						$symbol,
						$optid,
						$OpenClose, 
						&convert_side($lroms[6]),
						$lroms[7]);
						$i = $i +1;
					$legs = sprintf("%s%s",$legs,$leg);
					$leg_details{$parents{$lroms[55]}} = $legs;
					$leg_count{$parents{$lroms[55]}} = $i; #$lroms[31];
				}
		}
	}
	close(IN);
}

# foreach my $n (sort keys %leg_details) {
#     print "$n => $leg_details{$n}\n";
# };
# 
# foreach my $n (sort keys %leg_count) {
#     print "$n => $leg_count{$n}\n";
# };

my %idtoreplace;
my %replacedid;
foreach my $file (@sfiles) {
	open(IN, "<$file") or die "cannot open $file\n";
	while(<IN>) {
		chomp;
		my @lroms = split(/,/);
		if(defined $lroms[55] and $lroms[55] ne "SumoId"){	
			if ($lroms[15] eq "MLEG" and defined $leg_details{$lroms[55]}){	
				if( $lroms[0] eq "New") {
					#$outs{$lroms[1]} = $lroms[49];
					$orig_times{$lroms[55]} = &create_time_str($lroms[2]);
				}
				if($lroms[0] eq "ReplaceRequested") {
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
	}
	close(IN);
}


foreach my $id (sort keys %idtoreplace) {
    print "$id => $idtoreplace{$id}\n";
};
foreach my $id (sort keys %replacedid) {
    print "$id => $replacedid{$id}\n";
};

foreach my $file (@sfiles) {
	open(IN, "<$file") or die "cannot open $file\n";

	while (<IN>) {
		chomp;
		my @romfields = split(/,/);
		my $sym = $romfields[13];
        if($sym eq "ZVZZT") {
			#print "Test order: $sym, $romfields[28], $romfields[13], $romfields[55] \n";
			#print "Test order: \n";
		} elsif(defined $romfields[55]) {
			my $imid = "146310:SUMZ";
			if($romfields[15] eq "MLEG" and $romfields[0] eq "New" and defined $leg_details{$romfields[55]}) {
				$leg = substr($leg_details{$romfields[55]},0,length($leg_details{$romfields[55]})-1);	
				#print($leg,"\n");
				$nleg = $leg_count{$romfields[55]};
				my $roid = $romfields[1];
				&create_leg_new_order(\@romfields,$leg,$nleg);
				my $origTime=$orig_times{$romfields[55]};
				&create_leg_order_routed(\@romfields, $origTime, $leg,$nleg,$roid);
			}
			if($romfields[15] eq "MLEG" and $romfields[0] eq "Cancelled" and defined $leg_details{$romfields[55]}) {
				&create_leg_order_cancel(\@romfields);
			}
			if($romfields[15] eq "MLEG" and $romfields[0] eq "Replaced" and defined $leg_details{$romfields[55]}) {
				my $roid = $romfields[1];
				&create_leg_order_modify(\@romfields,$leg,$nleg,$roid);
				&create_leg_order_routed(\@romfields, &getModifyTime($romfields[1], $romfields[2]),$leg,$nleg,$roid);
			}
		}
	}
	close(IN);
};

sub create_leg_new_order {
	my $lroms = shift;
	my $leg = shift;
	my $nleg = shift;
	my $output = sprintf("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n",
		$CATactionType,                                                                                #1
		$CATerrorROEID ,                                                                               #2
		&create_fore_id($lroms->[3], $lroms->[55], $lroms->[2], $lroms->[51]),                                                   #3 firmROEID
		$CATtype[11],                                                                                  #4
		$CATReporterIMID,                                                                              #5
		&create_time_str($lroms->[2]),                                                                #6 orderKeyDate
		$lroms->[55],                                                                                  #7 orderID
		$lroms->[14],  																			   #8 
		&create_time_str($lroms->[2]),                                                                #9 eventTimeStamp
		$CATmanualFlag,                                                                             #10 
		$CATmanualOrderKeyDate,                                                                        #11
		$CATmanualOrderID,                                                                             #12
		$CATelectronicDupFlag,                                                                         #13
		$CATelectronicTimestamp,                                                                       #14
		$CATdeptType[2],                                                                               #15 &&get_dept_type
		&checkPrice($lroms->[8], $lroms->[4]),                                                         #16 price
		$lroms->[7],                                                                                   #17 quantity
		$CATminQty,                                                                                    #18 &&get_minqty
		&convert_type($lroms->[4]),                                                                    #19 orderType
		&checkTif($lroms->[5], $lroms->[2]),                                                          #20 timeInForce
		$CATtradingSession,                                                                            #21
		$CATsetHandlingInstructions, #&setHandlingInstructions($lroms->[44], $lroms->[44], $CATtype[11]),                             #22 &&handlingInstruction
		$lroms->[28], #&create_firm_id($lroms->[12],$lroms->[46]),                                     #23 firmDesignatedID
		&getAccountHolderType($lroms->[28]),                                                           #24 &&get_account_holder_type
		$CATaffiliateFlag[1],                                                                          #25 &&get_affiliation
		$CATaggregatedOrders,                                                                          #26
		$CATrepresentativeInd,                                                                    	   #27
		$CATsolicitationFlag,                                                                   	   #28
		$CATRFQID,                                                                                     #29
		$nleg,                                                                      	#30 numberofLegs
		$CATpriceType[0],                                                                           	#31 price type
		$leg						#32
	);
	my $lf = $file_h->{"file"}; 
	print $lf $output;

}

sub create_leg_order_routed {
	my $lroms = shift;
	my $sentTime = shift;		
	my $leg = shift;
	my $nleg = shift;
	my $fixed_roid = shift;	
	my $output = sprintf("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n",
		$CATactionType,                                                                                            #1
		$CATerrorROEID,                                                                                            #2
		&create_fore_id($lroms->[3], $lroms->[55], $lroms->[2], $lroms->[51]),                                                               #3 firmROEID
		$CATtype[10],                                                                                              #4
		$CATReporterIMID,                                                                                          #5
		&getOriginalTime($lroms->[55], $lroms->[2]),       #&create_time_str($lroms->[2]),                                                        #6 orderKeyDate
		$lroms->[55],                                                                                              #7 orderID
		$CATunderlying,  																						   #8
		&create_time_str($lroms->[2]),                                                                            					   #9 eventTimeStamp
		$CATmanualFlag,                                                                                         #10
		$CATelectronicDupFlag,                                                                                     #11
		$CATelectronicTimestamp,                                                                                   #12
		$CATsenderIMID,                                                    										   #13 
		"148743:SREX", #&get_imid_for_dest($lroms->[21]),                                                                          				   #14
		"F", #&get_dest_type($lroms->[21]),                 		                                                               #15 'F'
		$lroms->[1],                          									   #16 RoutedOrderID
		"", #&getSessionID($lroms->[21]),              				                                                                   #17 session ""
		&checkPrice($lroms->[8], $lroms->[4]),                                                                     #18 price
		$lroms->[7],                                                                                               #19 quantity
		$CATminQty,                                                                                                #20 &&get_minqty
		&convert_type($lroms->[4]),                                                                                #21 orderType
		&checkTif($lroms->[5], $lroms->[2]),                                                                      #22 timeInForce
		$CATtradingSession="ALL", #&checkSessions($lroms->[21]),                                                                                        #23
		$CATsetHandlingInstructions, #&setHandlingInstructions($lroms->[44], $lroms->[44], $CATtype[10]),                                         #24 &&handlingInstruction
		$CATaffiliateFlag[1],                                                                                      #25 &&get_affiliation
		&checkReject($lroms->[1]),                                                                                #26 routeRejectedFlag
		$CATexchOriginCode,	                                                        							   #27
		$CATpairedOrderID,                                                                                         #28
		$nleg,                                                                      								#29 numberofLegs
		$CATpriceType[0],                                                                           				#30 priceType
		$leg																										#31
	);
	my $lf = $file_h->{"file"};
	print $lf $output;
}

sub create_leg_order_modify {
	my $lroms = shift;
	my $leg = shift;
	my $nleg = shift;
	my $fixed_roid = shift;
	my $output = sprintf("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n",
		$CATactionType,                                                                                      #1
		$CATerrorROEID,                                                                                      #2
		&create_fore_id($lroms->[3], $lroms->[55], $lroms->[2], $lroms->[51]),                                                         #3 firmROEID
		$CATtype[13],                                                                                        #4
		$CATReporterIMID,                                                                                    #5
		&getOriginalTime($lroms->[55], $lroms->[2]),                                                        #6 orderKeyDate
		$lroms->[55],                                                                                        #7 orderID
		$CATpriorOrderKeyDate,                                                                               #8
		$CATpriorOrderID,                                                                                    #9
		$CATunderlying,																						 #10
		&getModifyTime($lroms->[1], $lroms->[2]),                                                           #11 eventTimestamp
		$CATmanualOrderKeyDate,                                                                              #12
		$CATmanualOrderID,                                                                                   #13
		$CATmanualFlag,                                                                                   #14
		$CATelectronicDupFlag,                                                                               #15
		$CATelectronicTimestamp,                                                                             #16
		"",  #$CATreceiverIMID,                                                                                    #17 
		"", #$CATsenderIMID,                      		                                      				#18 senderIMID""
		"", #$CATsenderType[2],                                                                                   #19 "F"
		$lroms->[1], 				#&get_routed_id_for_modify($lroms->[12],$lroms->[3],$lroms->[28]),     #20 routedOrderID "?"
		$CATinitiator,                                                                                       #21 "F"
		&checkPrice($lroms->[8], $lroms->[4]),                                                               #22 price
		$lroms->[7],                                                                                         #23 quantity
		$CATminQty,                                                                                          #24 &&get_minqty
		$lroms->[12],                                                                                        #25 leaveqty
		&convert_type($lroms->[4]),                                                                          #26 orderType
		&checkTif($lroms->[5], $lroms->[2]),                                                                #27 timeInForce
		$CATtradingSession,                                                                                  #28
		$CATsetHandlingInstructions, #&setHandlingInstructions($lroms->[44], $lroms->[44], $CATtype[13]),                                   #29  &&handlingInstruction
		$CATreservedForFutureUse,                                                                            #30
		$CATaggregatedOrders,                                                                                #31
		$CATrepresentativeInd,                                                                               #32
		$CATrequestTimestamp,
		$nleg,                                                                      		 #34 numberofLegs
		$CATpriceType[0],                                                                           		 #35 priceType
		$leg							 #36
	);
	my $lf = $file_h->{"file"};
	print $lf $output;
}
sub create_leg_order_cancel {
	my $lroms = shift;
	my $output = sprintf("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n",
		$CATactionType,                                                                                 #1
		$CATerrorROEID ,                                                                                #2
		&create_fore_id($lroms->[3], $lroms->[55], $lroms->[2], $lroms->[51]),                                                    #3 firmROEID
		$CATtype[14],                                                                                   #4
		$CATReporterIMID,                                                                               #5
		&getOriginalTime($lroms->[55], $lroms->[2]),                                                   #6 orderKeyDate
		$lroms->[55],                                                                                   #7 orderID
		$CATunderlying,   																				#8
		&create_time_str($lroms->[2]),                                                                 #9 eventTimestamp
		$CATmanualFlag,                                                                              #10 
		$CATelectronicTimestamp,                                                                        #11
		&determine_cancelled_qty($lroms->[7],$lroms->[11]),                                             #12 cancelQty
		$CATleavesQty,                                                                                  #13 &&get_leave_qty
		$CATinitiator,                                                                                  #14
		$CATrequestTimestamp,                                                                           #15 &&get_request_time
	);
	my $lf = $file_h->{"file"};
	print $lf $output;
}

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
		sprintf("%s_SUMZ_%d_SRockComplex_OrderEvents_%06d.csv", $who, $input_day, $sequence +33);
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
		sprintf("%s_SUMZ_%04d%02d%02d_SRockComplex_OrderEvents_%06d.csv", $who, $year + 1900, $mon + 1, $mday, $sequence +33);
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
	if($oc eq "1") {
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
		} elsif($side eq "Sell") {
			"S";
		} elsif($side eq "SellShort") {
			"SS";
		} elsif($side eq "BuyLong") {
			"SL";
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
	if($type eq "1") {
		"";
	} else {
		my $decimal = index($price, ".")+1;
	 	$price = substr($price,0,$decimal).substr($price,$decimal,8);
		#$price;
	}
}

sub convert_type {
	my $type = shift;
	if($type eq "1") {
		"MKT";
	} else {
		"LMT";
	}
}


# 57 Execution Instruction, 73 AlgoType S message
sub setHandlingInstructions
{
    my $type = shift;
    my $algoFlag = shift;
    my $event = shift;
    if($event eq "MLNO" or $event eq "MLOA" or $event eq "MLOM") {
        if(defined $algoFlag and $algoFlag ne "0") {
            "ALG";
        } elsif (defined $type) {
            if($type eq "P" or $type eq "M" or $type eq "R") {
            	"PEG";
            } else {
        		"RAR";
            }
        } else {
            "DIR|RAR";
        }
    } elsif ($event eq "MLOR") {
        "RAR";
    } else {""}
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
        "REG";
    }
}

#### change note
# go live om 3/25/2022
# 4/11/20222
# modified to read the parent output as the input raw orders
# fixed the script for issues with legs such as reference and side
# add a hashmap for initiator;
# changed handlinginstruction to "ALG" for all types of events
# changed session = "ALL" from "REG"
# 4/23: blank out $CATreceiverIMID, #$CATsenderIMID and $CATsenderType[3] for modified    #20 senderType should be ""
# 4/26: commented out printing ID's for test orders to address missing SumoID.
# 4/27: changed to use secType="MLEG" instead of multiLetType="multLeg" to indentify complex order
# 5/2: handling different RoutedClOrdId for each replacerequested.
# 20220520: changed if($romfields[0] eq "Open" ) to if($romfields[0] eq "New" ) for MLNO/MLOR events
# 20220524: changed from $canceltimes{$lroms->[1]} to #&create_time_str($lroms->[2])for #10 eventTimestamp
# 20220808: changed the initiator to a default value "F" for MOOM and MOOC from using a hashmap by account.
# 20220922: in the sub getSymbol, changed %08d to %08s when formating the optionID. format %08d drops 0.001 from the strik value causing invalid optionId.
# 20221010: made change in the sub getSymbol to use only the first letter of field 23 Put or Call