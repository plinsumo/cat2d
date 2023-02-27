#!/usr/bmn/perl -w
use strict;
use warnings FATAL => 'all';
use Time::Local;
use Net::SMTP;

my $input_day = shift;
my $title_date = substr($input_day,0,4) . "-" . substr($input_day,4,2) . "-" . substr($input_day,6,2);

my $CATSubmitterID = "146310";

my %non_reports = (
);

#accountHolderType. 
my %accountHolderType = (
 	'3KJ11209' => 'O'
);

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
my %orderid;
my %replaced;
my %replacerej;
my %canceled;
my %outs;
my %rejects;
my %orig_times;
my %reptimes;
my %cancelreqtimes;
my %replacereqtimes;
my $sequence = 1;

my $CATactionType = "NEW";
my $CATerrorROEID = "";
my $CATfirmROEID;
my @CATtype = ("MENO","MEOA","MEOR","MEOC","MEOM","MONO","MOOA","MOOR","MOOC","MOOM","MLOR","MLNO","MLOA","MLOM","MLOC");
my $CATReporterIMID= "SUMZ";
my $CATorderKeyDate;
my $CATorderID;
my $CAToptionID;
my $CATeventTimestamp;
my $CATmanualFlag="false";
my $CATmanualOrderKeyDate="";
my $CATmanualOrderID="";
my $CATelectronicDupFlag="false";
my $CATelectronicTimestamp="";
my $CATdeptType="T";
my $CATside;
my $CATprice;
my $CATquantity;
my $CATminQty="";
my $CATorderType;
my $CATtimeInForce;
my $CATtradingSession;
my $CAThandlingInstructions;
my $CATfirmDesignatedID;
my $CATaccountHolderType;
my @CATaffiliateFlag = ("TRUE","FALSE");
my $CATreservedForFutureUse="";
my $CATaggregatedOrders="";
my $CATsolicitationFlag="false";
my $CATopenCloseIndicator;
my $CATrepresentativeInd="N";
my $CATretiredFieldPosition="";
my $CATRFQID="";
my $CATnetPrice="";

my $CAToriginatingIMID="";
my $CATsenderIMID;
my $CATdestination;
my $CATdestinationType;
my $CATroutedOrderID;
my $CATsession="";
my $CATrouteRejectedFlag;
my $CATexchOriginCode="";
my $CATmultiLegInd="false";
my $CATpairedOrderID = "";

my $CATpriorOrderKeyDate="";
my $CATpriorOrderID="";
my $CATreceiverIMID="";
my $CATsenderType="";
my $CATinitiator="F";
my $CATleavesQty;
my $CATrequestTimestamp;
my $CATcancelQty;


# my %reserved_size;
# my %alg;
# 
# my $trd = "SUMOGSEC-" . $input_day . "trd.csv";
# if (-e $trd) {
# 	open(IN, "<$trd") or die "cannot open $trd\n";
# 	while(<IN>){
# 		chomp;
# 		my @msgfields = split(/,/);
# 		if($msgfields[15] eq " Confirmed"){
# 			if(defined $msgfields[64] and $msgfields[64] ne "\"\""){
# 				my $v=$msgfields[64];
# 				$v=~s/\"//g;
# 				$reserved_size{$msgfields[33]}=$v;
# 			};
# 
# 			if(defined $msgfields[43] and $msgfields[43] eq "\"VWAP\""){
# 				$alg{$msgfields[33]}="ALG"
# 			}
# 		}
# 	}
# }

# foreach my $key (sort keys %reserved_size) {
#     print "$key => $reserved_size{$key}\n";
# }

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



my @files = <*out*$title_date.csv>;
my @sfiles =  sort {
    ($a =~ /_(\d+)/)[0] <=> ($b =~ /_(\d+)/)[0]
} @files;

# foreach my $exch (sort keys %exchid) {
#     print "$exch => $exchid{$exch}\n";
# }

my $source="Redi";

my $file_h = &set_file($CATSubmitterID,$source);

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
			if ($lroms[15] eq "OPTION" and ($lroms[30] eq "SingleSecurity" or $lroms[30] eq ""))  {
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
				if($lroms[0] eq "ReplaceRejected") { #not a status for 35=8 in the fix log
						$replacerej{$lroms[1]} = "true";
				}
				if($lroms[0] eq "CancelPending" or $lroms[0] eq "CancelRequested") {
					$cancelreqtimes{$lroms[1]} = &create_time_str($lroms[2]);
				}
				if($lroms[0] eq "ReplaceRequested" or $lroms[0] eq "ReplacePending") {
					$replacereqtimes{$lroms[36]} = &create_time_str($lroms[2]);
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
my $instruction="";

foreach my $file (@sfiles) {
	open(IN, "<$file") or die "cannot open $file\n";

	while (<IN>) {
		chomp;
		my @romfields = split(/,/);
		my $sym = $romfields[13];
        if($sym eq "ZVZZT" or defined $skipAcounts{$romfields[3]} or defined $skipAcounts{$romfields[28]}) {
			#print "Test order: $sym, $romfields[28], $romfields[13], $romfields[55] \n";
		} elsif($romfields[0] ne "Execution" and defined $romfields[37]) {
			if ($romfields[15] eq "OPTION" and $romfields[30] eq "SingleSecurity" and defined $romfields[37])  {
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
					&create_order_routed(\@romfields, $origTime, $OrderID,  $orderdest{$OrderID});
				}  
				if($romfields[0] eq "Cancelled") {
					&create_order_cancel(\@romfields);
				}
				if($romfields[0] eq "Replaced") {
					my $OrderID=$romfields[37];
					#my $origTime=$orig_times{$romfields[37]};
					my $origTime=$replacereqtimes{$romfields[36]};
					&create_order_modify(\@romfields, $OrderID);
					&create_order_routed(\@romfields, $origTime, $OrderID,  $orderdest{$OrderID});

				}
			}
		}
	}
	close(IN);
}

sub create_new_order {
	my $lroms = shift;
	my $output = sprintf("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n",
		$CATactionType,                                                                                #1
		$CATerrorROEID ,                                                                               #2
		$CATfirmROEID=&create_fore_id($lroms->[3], $lroms->[37], &create_time_str($lroms->[2]), $lroms->[51], $CATtype[5]),           #3
		$CATtype[5],                                                                                   #4
		$CATReporterIMID,                                                                              #5
		$CATorderKeyDate=&create_time_str($lroms->[2]),						                           #6
		$CATorderID=$lroms->[37],                                                                      #7
		$CAToptionID=&getSymbol($lroms->[24], &get_ulsymbol($lroms->[13],$lroms->[14],$lroms->[50]),$lroms->[16],$lroms->[17],$lroms->[18],$lroms->[20],$lroms->[23],$lroms->[50]), #8
		$CATeventTimestamp=&create_time_str($lroms->[2]),                                              #9
		$CATmanualFlag,                                                                                #10 
		$CATmanualOrderKeyDate,                                                                        #11
		$CATmanualOrderID,                                                                             #12
		$CATelectronicDupFlag,                                                                         #13
		$CATelectronicTimestamp,                                                                       #14
		$CATdeptType,                                                                                  #15
		$CATside=&convert_side($lroms->[6]),                                                           #16
		$CATprice=&checkPrice($lroms->[8], $lroms->[4]),                                               #17
		$CATquantity=$lroms->[7],                                                                      #18
		$CATminQty,                                                                                    #19
		$CATorderType=&convert_type($lroms->[4]),                                                      #20
		$CATtimeInForce=&checkTif($lroms->[5], $lroms->[2], $lroms->[47]),                                           #21
		$CATtradingSession=&checkSessions(&create_time_str($lroms->[2]),$lroms->[5]),                                    #22
		$CAThandlingInstructions=&setHandlingInstructions($CATtype[5],$lroms->[53]),				   #23
		$CATfirmDesignatedID=&get_clear_account($lroms->[3],$lroms->[28]),                             #24
		$CATaccountHolderType=&getAccountHolderType(&get_clear_account($lroms->[3],$lroms->[28])),     #25
		$CATaffiliateFlag[1],                                                                          #26
		$CATaggregatedOrders,                                                                          #27
		$CATsolicitationFlag,                                                                          #28
		$CATopenCloseIndicator=&getOpenClose($lroms->[43]),                                            #29
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
	my $dest = shift;
	my $output = sprintf("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n",
		$CATactionType,                                                                                            #1
		$CATerrorROEID,                                                                                            #2
		$CATfirmROEID=&create_fore_id($lroms->[3], $lroms->[37], &create_time_str($lroms->[2]), $lroms->[51], $CATtype[7]),          #3
		$CATtype[7],                                                                                               #4
		$CATReporterIMID,                                                                                          #5
		$CATorderKeyDate=&getOriginalTime($lroms->[37], $lroms->[2]),						                       #6
		$CATorderID=$lroms->[37],                                                                                  #7
		$CAToptionID=&getSymbol($lroms->[24], &get_ulsymbol($lroms->[13],$lroms->[14],$lroms->[50]),$lroms->[16],$lroms->[17],$lroms->[18],$lroms->[20],$lroms->[23],$lroms->[50]), #8
		$CAToriginatingIMID,                                                                                       #9 
		$CATeventTimestamp=$sentTime, #&create_time_str($lroms->[2]),                                                          #10
		$CATmanualFlag,                                                                                            #11
		$CATelectronicDupFlag,                                                                                     #12
		$CATelectronicTimestamp,                                                                                   #13
		$CATsenderIMID="146310:SUMZ",                                                    						   #14
		$CATdestination=&get_destination($dest),                                                            #15
		$CATdestinationType=&get_dest_type(&get_destination($dest)),				                 		                                               #16
		$CATroutedOrderID=$lroms->[1],								                                 			   #17
		$CATsession=&session_id($CATdestinationType,$CATdestination),				             				   #18
		$CATside=&convert_side($lroms->[6]),                                                                       #19
		$CATprice=&checkPrice($lroms->[8], $lroms->[4]),                                                           #20
		$CATquantity=$lroms->[7],                                                                                  #21
		$CATminQty,                                                                                                #22
		$CATorderType=&convert_type($lroms->[4]),                                                                  #23
		$CATtimeInForce=&checkTif($lroms->[5], $lroms->[2], $lroms->[47]),                                                       #24
		$CATtradingSession=&checkSessions(&create_time_str($lroms->[2]),$lroms->[5]),                                                #25
		$CAThandlingInstructions=&setHandlingInstructions($CATtype[7],$lroms->[53]),							                   #26
		$CATrouteRejectedFlag=&checkReject($lroms->[1]),                                                           #27
		$CATexchOriginCode,	                                                        							   #28
		$CATaffiliateFlag[1],                                                                                      #29
		$CATmultiLegInd,                                                                                           #30
		$CATopenCloseIndicator=&getOpenClose($lroms->[43]),                                                        #31
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
		$CATfirmROEID=&create_fore_id($lroms->[3], $lroms->[37], &create_time_str($lroms->[2]), $lroms->[51], $CATtype[9]),    #3
		$CATtype[9],                                                                                         #4
		$CATReporterIMID,                                                                                    #5
		$CATorderKeyDate=&getOriginalTime($lroms->[37], $lroms->[2]),			                 			 #6
		$CATorderID=$lroms->[37],                                                                            #7 
		$CAToptionID=&getSymbol($lroms->[24], &get_ulsymbol($lroms->[13],$lroms->[14],$lroms->[50]),$lroms->[16],$lroms->[17],$lroms->[18],$lroms->[20],$lroms->[23],$lroms->[50]), #8 optionID
		$CATpriorOrderKeyDate,                                                                               #9
		$CATpriorOrderID,                                                                                    #10
		$CAToriginatingIMID,                                                                                 #11
		$CATeventTimestamp=&create_time_str($lroms->[2]), #&getModifyTime($lroms->[1], $lroms->[2]),                                         #12
		$CATmanualOrderKeyDate,                                                                              #13
		$CATmanualOrderID,                                                                                   #14
		$CATmanualFlag,                                                                                      #15
		$CATelectronicDupFlag,                                                                               #16
		$CATelectronicTimestamp,                                                                             #17
		$CATreceiverIMID,                                                									 #18
		$CATsenderIMID="",                      		                                      				 #19
		$CATsenderType,                                                    								 	 #20
		$CATroutedOrderID="", 																			     #21 
		$CATinitiator,                                                                                       #22
		$CATside=&convert_side($lroms->[6]),                                                                 #23
		$CATprice=&checkPrice($lroms->[8], $lroms->[4]),                                                     #24
		$CATquantity=$lroms->[7],                                                                            #25
		$CATminQty,                                                                                          #26
		$CATleavesQty=$lroms->[12],                                                                          #27
		$CATorderType=&convert_type($lroms->[4]),                                                            #28
		$CATtimeInForce=&checkTif($lroms->[5], $lroms->[2], $lroms->[47]),                                                 #29
		$CATtradingSession=&checkSessions(&create_time_str($lroms->[2]),$lroms->[5]),                                          #30
		$CAThandlingInstructions=&setHandlingInstructions($CATtype[9],$lroms->[53]),                         #31
		$CATopenCloseIndicator=&getOpenClose($lroms->[43]),                                                  #32 
		$CATrequestTimestamp=&getModifyTime($lroms->[1],$replacereqtimes{$lroms->[36]}),                     #33
		$CATreservedForFutureUse,                                                                            #34
		$CATaggregatedOrders,                                                                                #35
		$CATrepresentativeInd,                                                                               #36
		$CATretiredFieldPosition,                                                                            #37
		$CATretiredFieldPosition,                                                                            #38
		$CATnetPrice                                                                                         #39
	);
	my $lf = $file_h->{"file"};
	print $lf $output;
}

sub create_order_cancel {
	my $lroms = shift;
	my $output = sprintf("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n",
		$CATactionType,                                                                                 #1
		$CATerrorROEID ,                                                                                #2
		$CATfirmROEID=&create_fore_id($lroms->[3], $lroms->[37], &create_time_str($lroms->[2]), $lroms->[51], $CATtype[8]),            #3
		$CATtype[8],                                                                                    #4
		$CATReporterIMID,                                                                               #5
		$CATorderKeyDate=&getOriginalTime($lroms->[37], $lroms->[2]),						            #6 
		$CATorderID=$lroms->[37],                                                                       #7 
		$CAToptionID=&getSymbol($lroms->[24], &get_ulsymbol($lroms->[13],$lroms->[14],$lroms->[50]),$lroms->[16],$lroms->[17],$lroms->[18],$lroms->[20],$lroms->[23],$lroms->[50]), #8 
		$CAToriginatingIMID,                                                                            #9
		$CATeventTimestamp=&create_time_str($lroms->[2]),     											#10
		$CATmanualFlag,                                                                                 #11 
		$CATelectronicTimestamp,                                                                        #12
		$CATcancelQty=&determine_cancelled_qty($lroms->[7],$lroms->[11]),                               #13
		$CATleavesQty=$lroms->[12],					                                                    #14
		$CATinitiator,														                            #15
		$CATretiredFieldPosition,                                                                       #16
		$CATrequestTimestamp=&get_req_time($cancelreqtimes{$lroms->[1]})                				#17
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
	my $vendor=shift;
	if(defined $input_day){
		sprintf("%s_SUMZ_%d_%sOption_OrderEvents_%06d.csv", $who, $input_day, $vendor, $sequence +8);
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
		sprintf("%s_SUMZ_%04d%02d%02d_%sOption_OrderEvents_%06d.csv", $who, $year + 1900, $mon + 1, $mday, $vendor, $sequence +8);
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
 
sub getOpenClose {
	my $oc = shift;
	if($oc eq "Open" or $oc eq "open") {
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
	if($account ne "" and substr($account,0,1) eq "3") {
		"O";
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

# sub checkTif {
# 	my $tif = shift;
# 	my $time = shift;
# 	if (uc($tif) eq "DAY") {
# 		my $rtif = "DAY=" . substr($time,0,8);
# 		$rtif;
# 	}else{
# 		my $rtif=$tif
# 	}
# }

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
	else {
		sprintf("%s %s",
			substr($cwa,0,8), substr($cwa,9,length($cwa)-9));
	}
}

# sub getSymbol {
# 	my $baseSym = shift;      #5 13
# 	my $yy = substr(shift,2,2); #16 year
# 	my $mm = shift;  # month 17
# 	my $day = shift;          # 18
# 	my $dstrike = shift;      # 20
# 	my $putCall = substr(shift,0,1);      # 23
# 	my $strike = ($dstrike * 1000);
# 	my$output =sprintf("%-6s%s%02s%02s%s%08d", $baseSym, $yy, $mm, $day,$putCall,$strike);
# 	$output;
# 
# }

sub getSymbol {
	my $optionid = shift; 
	my $baseSym = shift;      #5 13
	my $yy = substr(shift,2,2); #16 year
	my $mm = shift;  # month 17
	my $day = shift;          # 18
	my $dstrike = shift;      # 20
	my $putCall = substr(shift,0,1);      # 23
	my $strike = ($dstrike * 1000);
	my $futsym = substr(shift,0,4);
	my $output;
	
	if($baseSym eq "SPX" and $futsym eq "SPXW"){
		$baseSym="SPXW"
	}
	if(not defined $optionid or $optionid eq ""){
		$output =sprintf("%-6s%s%02s%02s%s%08d", $baseSym, $yy, $mm, $day,$putCall,$strike);
	}else{
		$output = $optionid
	}
	$output;

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

sub get_req_time {
	my $request_time=shift;
	if(not defined $request_time){
		"" #&create_time_str($cancel_time)
	}else{
		$request_time
	}
}

sub get_cancel_initiator {
	my $request_time=shift;
	if(defined $request_time){
		my $initiator="C"
	}else{
		my $initiator="F"
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

sub get_ulsymbol {
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

# sub get_imid_for_dest {
#     my $dest = shift;
#     my $exch = $exchid{$dest};
#     if(defined $exch) {
#         $exch;
#     } else {
#         print "Failed to find exchange id for $dest \n";
#         "";
#     }
# }

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

