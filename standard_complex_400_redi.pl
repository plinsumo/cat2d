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

my %skipAcounts = (
	'AVTT1209' => 'AVTT1209',
	'3NM71209' => '3NM71209'
);

my %accountHolderType = (
 	'3NM71209' => 'O',
 	'3KJ11209' => 'O',
 	'3KY01209' => 'O'
);

my %sessionids = (
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

my %desttypes = (
	"ARCA"=>"E",
	"7"=>"F"
);

my $iscentral = 0;
my %orderid;
my %openid;
my %replaceid;
my %cancelid;
my %cancelledid;
my %outs;
my %rejects;
my %orig_times;
my %reptimes;
my %cancelreqtimes;
my $sequence = 1;
my %replacereqtimes;

my $CATactionType = "NEW";
my $CATerrorROEID = "";
my $CATfirmROEID;
my @CATtype = ("MENO","MEOA","MEOR","MEOC","MEOM","MONO","MOOA","MOOR","MOOC","MOOM","MLOR","MLNO","MLOA","MLOM","MLOC");
my $CATReporterIMID= "SUMZ";
my $CATorderKeyDate;
my $CATorderID;
my $CATunderlying = "";
my $CATeventTimestamp;
my $CATmanualFlag="false";
my $CATelectronicDupFlag="false";
my $CATelectronicTimestamp="";
my $CATmanualOrderKeyDate="";
my $CATmanualOrderID="";
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
my $CATaggregatedOrders="";
my $CATrepresentativeInd="N";
my $CATsolicitationFlag="false";
my $CATRFQID = "";
my $CATnumberOfLegs;
#my @CATpriceType = ("PU", "TC", "TS");
my $CATpriceType;
my $CATlegDetails;

my $CATsenderIMID;
my $CATdestination;
my $CATdestinationType;
my $CATroutedOrderID;
my $CATsession="";
my $CATrouteRejectedFlag;
my $CATexchOriginCode="";
my $CATpairedOrderID = "";

my $CATpriorOrderKeyDate="";
my $CATpriorOrderID="";
my $CATreceiverIMID="";
my $CATsenderType = "";
my $CATinitiator="F";
my $CATreservedForFutureUse="";
my $CATleavesQty;

my $CATcancelQty;
my $CATrequestTimestamp="";

my %leg5_details;
my $leg;
my $legs;
my $nleg;
my $symbol="";
my $optid ="";
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

my %exchid;

my @files = <*out*$title_date.csv>;
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

my $file_h = &set_file($CATSubmitterID,$source);

my %parents;

# get the parent of legs
foreach my $file (@files) {
	open(IN, "<$file") or die "cannot open $file\n";
	while(<IN>) {
		chomp;
		my @lroms = split(/,/);
		if ($lroms[15] eq "MLEG" and ($lroms[0] eq "Open" or $lroms[0] eq "Replaced")) {
			$parents{$lroms[1]}=$lroms[1]; #tag 37 and tag 55 are leg id's. should use tag1 for the parent.
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
my $side;
# build the legs
foreach my $file (@files) {
	open(IN, "<$file") or die "cannot open $file\n";
	while(<IN>) {
		chomp;
		my @lroms = split(/,/);
		if(($lroms[0] eq "Open" or $lroms[0] eq "Replaced") and $lroms[30] eq "IndividualLeg") {
				if($lroms[15] eq "EQUITY" ) {
					$symbol=&get_ulsymbol($lroms[13],$lroms[14],$lroms[50]);
					$optid ="";
					$OpenClose="";
					$side=&convert_side_e($lroms[6])
				} elsif($lroms[15] eq "OPTION" ) {
					#$optid = &getSymbol(&get_ulsymbol($lroms[13],$lroms[14],$lroms[50]),$lroms[16], $lroms[17], $lroms[18], $lroms[20], $lroms[23]);
					$optid = &getSymbol($lroms[24], &get_ulsymbol($lroms[13],$lroms[14],$lroms[50]),$lroms[16],$lroms[17],$lroms[18],$lroms[20],$lroms[23],$lroms[50]);
					$symbol="";
					$OpenClose=$lroms[43];
					$side=&convert_side_o($lroms[6]);
				}else{#determin the secType
					if($lroms[20] eq "") {
						$symbol=&get_ulsymbol($lroms[13],$lroms[14],$lroms[50]);
					}else{
					#$optid = &getSymbol(&get_ulsymbol($lroms[13],$lroms[14],$lroms[50]),$lroms[16], $lroms[17], $lroms[18], $lroms[20], $lroms[23]);
					$optid = &getSymbol($lroms[24], &get_ulsymbol($lroms[13],$lroms[14],$lroms[50]),$lroms[16],$lroms[17],$lroms[18],$lroms[20],$lroms[23],$lroms[50]);
					$symbol="";
					$OpenClose=$lroms[43];
					}
				}
				if ($lroms[1] ne $same_parent) {
					$same_parent=$lroms[1]; 
					$legs = "";
					$i = 1; #$i +1;
					$leg = sprintf("%s@%s@%s@%s@%s@%s|",
						$lroms[31],
						$symbol,
						$optid,
						$OpenClose, 
						$side, #&convert_side($lroms[6]),
						$lroms[7]);
					$legs = sprintf("%s%s",$legs,$leg);
					$leg_details{$parents{$lroms[1]}} = $legs
				} else {
					$leg = sprintf("%s@%s@%s@%s@%s@%s|",
						$lroms[31],	
						$symbol,
						$optid,
						$OpenClose, 
						$side, #&convert_side($lroms[6]),
						$lroms[7]);
						$i = $i +1;
					$legs = sprintf("%s%s",$legs,$leg);
					$leg_details{$parents{$lroms[1]}} = $legs;
					$leg_count{$parents{$lroms[1]}} = $i; #$lroms[31];
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
my %opentime;
foreach my $file (@sfiles) {
	open(IN, "<$file") or die "cannot open $file\n";
	while(<IN>) {
		chomp;
		my @lroms = split(/,/);
		my $sym = $lroms[13];
        if($sym eq "ZVZZT") {
			#print "Test order: $sym, $lroms[28], $lroms[13], $lroms[37] \n";
			#print "Test order: \n";
		} else {
			if ($lroms[15] eq "MLEG" or $lroms[30] eq "MultiLeg"){	
					if( $lroms[0] eq "New") {
						$openid{$lroms[37]}=$lroms[1];
						$opentime{$lroms[37]} = &create_time_str($lroms[2]);
					}
					if($lroms[0] eq "Replaced") {
						$replaceid{$lroms[37]}=$lroms[1];
						#$reptimes{$lroms[1]} = &create_time_str($lroms[2]);
						$replacedid{$lroms[36]} = $lroms[36];
					}
					if($lroms[0] eq "Rejected") {
						$rejects{$lroms[1]} = "true";
						$outs{$lroms[1]} = $lroms[1];
					}
					if($lroms[0] eq "ReplaceRejected") {
							$replacerej{$lroms[1]} = "true";
					}
					if($lroms[0] eq "CancelPending" or $lroms[0] eq "CancelRequested") {
						#$cancelid{$lroms[37]}=$lroms[1];
						$cancelreqtimes{$lroms[1]} = &create_time_str($lroms[2]);
						#$cancelledid{$lroms[1]} = $lroms[36];
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


# foreach my $id (sort keys %opentime) {
#     print "$id => $opentime{$id}\n";
# };

my %orderdest;
my $poid="";
my %cancelled;
foreach my $file (@sfiles) {
	open(IN, "<$file") or die "cannot open $file\n";
	while (<IN>) {
		chomp;
		my @romfields = split(/,/);
		my $sym = $romfields[13];
        if($sym eq "ZVZZT" or defined $skipAcounts{$romfields[3]} or defined $skipAcounts{$romfields[28]}) {
			#print "Test order: $sym, $romfields[28], $romfields[13], $romfields[37] \n";
			#print "Test order: \n";
		} elsif(defined $romfields[1] and $romfields[1] ne $poid and $romfields[0] ne "Open" ) { #and ($romfields[15] eq "MLEG" or $romfields[30] eq "MultiLeg") and $romfields[0] eq "Open" ) {
			my $imid = "146310:SUMZ";
			if(($romfields[15] eq "MLEG" or $romfields[30] eq "MultiLeg") and $romfields[0] eq "New" and defined $leg_details{$romfields[1]}) {
				$leg = substr($leg_details{$romfields[1]},0,length($leg_details{$romfields[1]})-1);	
				#print($leg,"\n");
				$nleg = $leg_count{$romfields[1]};
				my $roid = $romfields[1];
				&create_complex_new_order(\@romfields,$leg,$nleg);
				my $origTime=$opentime{$romfields[37]};
				$orderdest{$roid}=$romfields[29];				
				&create_complex_order_routed(\@romfields, $origTime, $leg,$nleg,$roid,$orderdest{$roid});
			}
			if($romfields[15] eq "MLEG" and $romfields[0] eq "Cancelled" and not defined $cancelled{$romfields[1]}) {
				my $oriorid=$openid{$romfields[37]};
				my $origTime=$opentime{$romfields[37]};
				&create_complex_order_cancel(\@romfields,$oriorid,$origTime);
				$cancelled{$romfields[1]}=$romfields[1];
			}
			if($romfields[15] eq "MLEG" and $romfields[0] eq "Replaced" and defined $leg_details{$romfields[1]}) {
				#my $roid = $romfields[1];
				my $oriorid=$openid{$romfields[37]};
				my $origTime=$opentime{$romfields[37]};
				$leg = substr($leg_details{$romfields[1]},0,length($leg_details{$romfields[1]})-1);	
				#print($leg,"\n");
				$nleg = $leg_count{$romfields[1]};
				&create_complex_order_modify(\@romfields,$leg,$nleg,$oriorid,$origTime);
				&create_complex_order_routed(\@romfields, $origTime,$leg,$nleg,$oriorid,$orderdest{$oriorid})
			}
					$poid=$romfields[1];
		}
		#$poid=$romfields[1];
	}
	close(IN);
};


sub create_complex_new_order {
	my $lroms = shift;
	my $leg = shift;
	my $nleg = shift;
	my $output = sprintf("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n",
		$CATactionType,                                                                                #1
		$CATerrorROEID ,                                                                               #2
		$CATfirmROEID=&create_fore_id($lroms->[3], $lroms->[1], &create_time_str($lroms->[2]), $lroms->[51], $CATtype[11]),            #3
		$CATtype[11],                                                                                  #4
		$CATReporterIMID,                                                                              #5
		$CATorderKeyDate=&create_time_str($lroms->[2]),                          					   #6
		$CATorderID=$lroms->[1],                                                                       #7
		$CATunderlying=$lroms->[14],  																   #8 
		$CATeventTimestamp=&create_time_str($lroms->[2]),                                              #9
		$CATmanualFlag,                                                                                #10 
		$CATmanualOrderKeyDate,                                                                        #11
		$CATmanualOrderID,                                                                             #12
		$CATelectronicDupFlag,                                                                         #13
		$CATelectronicTimestamp,                                                                       #14
		$CATdeptType,                                                                                  #15
		$CATprice=&checkPrice($lroms->[8], $lroms->[4]),                                               #16
		$CATquantity="1", 											                           		   #17
		$CATminQty,                                                                                    #18
		$CATorderType=&convert_type($lroms->[4]),                                                      #19
		$CATtimeInForce=&checkTif($lroms->[5], $lroms->[2], $lroms->[47]),                                           #20
		$CATtradingSession=&checkSessions(&create_time_str($lroms->[2]),$lroms->[5]),                                    #21
		$CAThandlingInstructions=&setHandlingInstructions($CATtype[11],$lroms->[53]),                  #22
		$CATfirmDesignatedID=&get_clear_account($lroms->[3],$lroms->[28]),						       #23
		$CATaccountHolderType=&getAccountHolderType(&get_clear_account($lroms->[3],$lroms->[28])),     #24
		$CATaffiliateFlag[1],                                                                          #25
		$CATaggregatedOrders,                                                                          #26
		$CATrepresentativeInd,                                                                    	   #27
		$CATsolicitationFlag,                                                                   	   #28
		$CATRFQID,                                                                                     #29
		$CATnumberOfLegs=$nleg,                                                                        #30
		$CATpriceType=&leg_pricetype($lroms->[4]),                                                     #31
		$CATlegDetails=$leg																			   #32
	);
	my $lf = $file_h->{"file"}; 
	print $lf $output;

}

sub create_complex_order_routed {
	my $lroms = shift;
	my $sentTime = shift;		
	my $leg = shift;
	my $nleg = shift;
	my $fixed_roid = shift;	
	my $dest = shift;
	my $output = sprintf("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n",
		$CATactionType,                                                                                            #1
		$CATerrorROEID,                                                                                            #2
		$CATfirmROEID=&create_fore_id($lroms->[3], $lroms->[1], &create_time_str($lroms->[2]), $lroms->[51], $CATtype[10]),          #3
		$CATtype[10],                                                                                              #4
		$CATReporterIMID,                                                                                          #5
		$CATorderKeyDate=$sentTime, 																			   #6
		$CATorderID=$fixed_roid,				                                                                   #7
		$CATunderlying,  																						   #8
		$CATeventTimestamp=&create_time_str($lroms->[2]),											   			   #9
		$CATmanualFlag,                                                                                            #10
		$CATelectronicDupFlag,                                                                                     #11
		$CATelectronicTimestamp,                                                                                   #12
		$CATsenderIMID="146310:SUMZ",                                                    						   #13 
		$CATdestination=&get_destination($dest),                                                            #14
		$CATdestinationType=&get_dest_type(&get_destination($dest)),                 		                                   #15
		$CATroutedOrderID=$lroms->[1],                          									   			   #16
		$CATsession=&session_id($CATdestinationType,$CATdestination),              				                   #17
		$CATprice=&checkPrice($lroms->[8], $lroms->[4]),                                                           #18
		$CATquantity="1", 							                                                       		   #19
		$CATminQty,                                                                                                #20
		$CATorderType=&convert_type($lroms->[4]),                                                                  #21
		$CATtimeInForce=&checkTif($lroms->[5], $lroms->[2], $lroms->[47]),                                                       #22
		$CATtradingSession=&checkSessions(&create_time_str($lroms->[2]),$lroms->[5]),                                                #23
		$CAThandlingInstructions=&setHandlingInstructions($CATtype[10],$lroms->[53]),                              #24
		$CATaffiliateFlag[1],                                                                                      #25
		$CATrouteRejectedFlag=&checkReject($lroms->[1]),                                                           #26
		$CATexchOriginCode,	                                                        							   #27
		$CATpairedOrderID,                                                                                         #28
		$CATnumberOfLegs=$nleg,                                                                      			   #29
		$CATpriceType=&leg_pricetype($lroms->[4]),                                                                 #30
		$CATlegDetails=$leg																						   #31
	);
	my $lf = $file_h->{"file"};
	print $lf $output;
}

sub create_complex_order_modify {
	my $lroms = shift;
	my $leg = shift;
	my $nleg = shift;
	my $fixed_roid = shift;
	my $origtime = shift;
	my $output = sprintf("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n",
		$CATactionType,                                                                                      #1
		$CATerrorROEID,                                                                                      #2
		$CATfirmROEID=&create_fore_id($lroms->[3], $lroms->[1], &create_time_str($lroms->[2]), $lroms->[51], $CATtype[13]),    #3
		$CATtype[13],                                                                                        #4
		$CATReporterIMID,                                                                                    #5
		$CATorderKeyDate=$origtime, 												                         #6
		$CATorderID=$fixed_roid,				                                                             #7
		$CATpriorOrderKeyDate,                                                                               #8
		$CATpriorOrderID,                                                                                    #9
		$CATunderlying,																						 #10
		$CATeventTimestamp=&create_time_str($lroms->[2]), #&getModifyTime($lroms->[1], $lroms->[2]),         #11
		$CATmanualOrderKeyDate,                                                                              #12
		$CATmanualOrderID,                                                                                   #13
		$CATmanualFlag,                                                                                   	 #14
		$CATelectronicDupFlag,                                                                               #15
		$CATelectronicTimestamp,                                                                             #16
		$CATreceiverIMID,                                                                                    #17 
		$CATsenderIMID="",                      		                                      				 #18
		$CATsenderType,                                                                                      #19
		$CATroutedOrderID=$lroms->[1], 																		 #20
		$CATinitiator,                                                                          			 #21
		$CATprice=&checkPrice($lroms->[8], $lroms->[4]),                                                     #22
		$CATquantity="1", 							                                                 		 #23
		$CATminQty,                                                                                          #24
		$CATleavesQty="1",                                                                          		 #25
		$CATorderType=&convert_type($lroms->[4]),                                                            #26
		$CATtimeInForce=&checkTif($lroms->[5], $lroms->[2], $lroms->[47]),                                                 #27
		$CATtradingSession=&checkSessions(&create_time_str($lroms->[2]),$lroms->[5]),                                          #28
		$CAThandlingInstructions=&setHandlingInstructions($CATtype[13],$lroms->[53]),                        #29
		$CATreservedForFutureUse,                                                                            #30
		$CATaggregatedOrders,                                                                                #31
		$CATrepresentativeInd,                                                                               #32
		$CATrequestTimestamp=&getModifyTime($lroms->[1],$replacereqtimes{$lroms->[36]}),																				 #33 
		$CATnumberOfLegs=$nleg,                                                                      		 #34
		$CATpriceType=&leg_pricetype($lroms->[4]),                                                           #35
		$CATlegDetails=$leg							 														 #36
	);
	my $lf = $file_h->{"file"};
	print $lf $output;
}

sub create_complex_order_cancel {
	my $lroms = shift;
	my $fixed_roid = shift;
	my $origtime = shift;
	my $output = sprintf("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n",
		$CATactionType,                                                                                 #1
		$CATerrorROEID ,                                                                                #2
		$CATfirmROEID=&create_fore_id($lroms->[3], $lroms->[1], &create_time_str($lroms->[2]), $lroms->[51], $CATtype[14]),             #3
		$CATtype[14],                                                                                   #4
		$CATReporterIMID,                                                                               #5
		$CATorderKeyDate=$origtime, 											                        #6
		$CATorderID=$fixed_roid, 																		#7 
		$CATunderlying,   																				#8
		$CATeventTimestamp=&create_time_str($lroms->[2]),												#9		
		$CATmanualFlag,                                                                             	#10 
		$CATelectronicTimestamp,                                                                        #11
		$CATcancelQty="1",							                         							#12
		$CATleavesQty="0",                                                                     			#13
		$CATinitiator,										             								#14
		$CATrequestTimestamp=&get_req_time($cancelreqtimes{$lroms->[1]},$lroms->[2]),               	#15
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
		sprintf("%s_SUMZ_%d_%sComplex_OrderEvents_%06d.csv", $who, $input_day, $vendor, $sequence +33);
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
		sprintf("%s_SUMZ_%04d%02d%02d_%sComplex_OrderEvents_%06d.csv", $who, $year + 1900, $mon + 1, $mday, $vendor, $sequence +33);
	}
}

sub set_file {
	my $mpid = shift;
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

sub convert_side_o
{
	my $side = shift;
	if(defined $side) {
		if($side eq "Buy") {
			"B";
		} elsif($side eq "Sell") {
			"S";
		} elsif($side eq "SellShort") {
			"BAD";
		} elsif($side eq "BuyLong") {
			"BAD";
		}
	}
}

sub convert_side_e
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
	my $time = $opentime{$id};
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
}

# sub getSymbol {
# 	my $baseSym = shift;      #5 13
# 	my $yy = substr(shift,2,2); #16 year
# 	my $mm = shift;  # month 17
# 	my $day = shift;          # 18
# 	my $dstrike = shift;      # 20
# 	my $putCall = substr(shift,0,1);      # 23
# 
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
    if(($event eq "MLNO" or $event eq "MLOM" or $event eq "MLOR") and defined $instr and $instr ne ""){
    	$instr
#     }elsif(($event eq "MLNO" or $event eq "MLOM") and not defined $instr) {
#         "DIR|RAR";
#     } elsif ($event eq "MLOR") {
#         "RAR";
    } else {""}
}

# sub checkSessions {
#     my $dest = shift;
#     if($dest eq "ARCA") {
#         "ALL";
#     } else {
#         "REG";
#     }
# }
# 
sub get_req_time {
	my $request_time=shift;
	my $cancel_time=shift;
	if(not defined $request_time){
		"" #&create_time_str($cancel_time)
	}else{
		$request_time
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

sub complex_qty {
	my $roletype=shift;
	my $quantity=shift;
	if($roletype eq "IndividualLeg"){
		"1"
	}elsif($roletype eq "Multileg"){
		$quantity
	}else{
		print("Something is wrong with security type of this order!\n")
	}
}

sub leg_pricetype {
	my $ordtype=shift;
	if ($ordtype eq "Market"){
		""
	}else{
		"PU"
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

# sub getSessionID {
#     my $dest = shift;
#     my $exch = $sessionids{$dest};
#     if(defined $exch) {
#         $exch;
#     } else {
#         "";
#    }
# }

# sub get_cancel_initiator {
# 	my $request_time=shift;
# 	if(not defined $request_time){
# 		my $initiator="F"
# 	}else{
# 		my $initiator="C"
# 	}
# }

# sub get_cancel_initiator {
# 	my $desc=shift; #field 25 Description
# 	if(not defined $desc and $desc eq "Normal - Leg Cancel"){
# 		my $initiator="C"
# 	}else{
# 		my $initiator="F"
# 	}
# }

