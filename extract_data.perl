#!/usr/bin/perl 

#################################################################################################################
#														#
#	extract_data.perl: extrad needed data from mp_report, and create a history files for comp and grad data	#
#														#
#		author: t. isobe (tisobe@cfa.harvard.edu)							#
#														#
#		last updata: Feb 27, 2013									#
#														#
#################################################################################################################
#
#--- check whether this is a test case. 
#

$comp_test = $ARGV[0];
chomp $cmop_test;

#
#--- set directories
#

if($comp_test =~ /test/i){
	$main_dir      = '/data/mta/Script/Trending/';
	$script_dir    = "$main_dir/Trending_Script/";
	$house_keeping = "$script_dir/house_keeping/";
	$mp_dir        = "$house_keeping/Test_prep/Input/";
	$data_dir      = "$main_dir/Test_out/";
}else{
	$main_dir      = '/data/mta/Script/Trending/';
	$mp_dir        = '/data/mta/www/mp_reports/';
	$script_dir    = "$main_dir/Trending_Script/";
	$house_keeping = "$script_dir/house_keeping/";
	$data_dir      = "$main_dir/Trend/";
}


#
#--- find out which "date" has actual data
#
if($comp_test =~ /test/i){
	$input     =  "$mp_dir".'compaciscent_summ.fits';
	@list      = ($input);
	@date_list = ('20130227');
}else{
	$input = `ls -rt $mp_dir*/compaciscent/data/compaciscent_summ.fits`;
	@list  = split(/\s+/, $input);
	@date_list = ();
	foreach $ent (@list){
		@atemp = split(/\//, $ent);
		push(@date_list, $atemp[5]);
	}
}

#
#--- read which "date" are already processed
#

if($comp_test =~ /test/i){
	open(FH, "$house_keeping/Test_prep/date_list");
}else{
	open(FH, "$house_keeping/date_list");
}
while(<FH>){
	chomp $_;
	$last_entry = $_;
}
close(FH);

#
#--- pick the date we have not processed.
#

@new_list = ();
$dcnt     = 0;
foreach $ent (@date_list){
	if($ent > $last_entry){
		push(@new, $ent);
		$dcnt++;
	}
}

#
#--- if there is no new data exit.
#
if($dcnt == 0){
	exit 1;
}

#
#-- add the date we are processing to the date_list
#
if($comp_test !~ /test/i){
	open(OUT, ">>$house_keeping/date_list");
}
#
#-- process data fro the all date we have not processed
#
foreach $edate (@new){
#
#-- find date from 1999.1.1.
#
	print OUT "$edate\n";
	@atemp = split(//, $edate);
	$year  = "$atemp[0]$atemp[1]$atemp[2]$atemp[3]";
	$mon   = "$atemp[4]$atemp[5]";
	$day   = "$atemp[6]$atemp[7]";
	$dom   = conv_date_dom($year, $mon, $day);	#--- compute # of day from the mission started
	$dom  += 203;

#	print "DATE: $year/$mon/$day<--->$dom\n";

#
#--- only comp and grad data are processd
#
	foreach $ent (
		'compaciscent', 'compacispwr', 'compephinkeyrates', 'compgradkodak',
		'compsimoffset', 'gradablk', 'gradahet', 'gradaincyl', 'gradcap',
		'gradfap', 'gradfblk', 'gradhcone', 'gradhhflex', 'gradhpflex', 'gradhstrut',
		'gradocyl', 'gradpcolb', 'gradperi', 'gradsstrut', 'gradtfte'){

#		print "\tFILE: $ent\n";
	
#
#--- exctract msid and its daily average and error
#
		$name = "$ent".'_summ.fits';
		if($comp_test =~ /test/i){
			$data = "$mp_dir/$name";
		}else{
			$data = '/data/mta/www/mp_reports/'."$edate".'/'."$ent".'/data/'."$name";
		}
		$line = "$data".'[cols name,average,error]';
	
		system("dmlist \"$line\" opt=data > zout");
		open(FH, "zout");
		@msid  = ();
		@avg   = ();
		$cnt   = 0;
		OUTER:
		while(<FH>){
			chomp $_;
			@atemp = split(/\s+/, $_);
			if($atemp[1] !~ /\d/){
				next OUTER;
			}
			$name  = uc($atemp[2]);
			push(@msid, $atemp[2]);
			%{data.$name} = (val=>["$atemp[3]"]);
			%{err.$name}  = (val=>["$atemp[4]"]);
			$cnt++;
		}
		close(FH);
#
#--- read msid names we need, and create col name list
#
		$file = "$house_keeping/$ent";
		open(FH, "$file");
	
		@name_list = ();
		@cols = ("TIME");
		$cnames = "TIME";
		while(<FH>){
			chomp $_;
			@atemp = split(/\s+/, $_);
			$name  = uc($atemp[0]);
			push(@name_list, $name);
			$dev   = $name;
			$name  = "$name"."_AVG";
			$dev   = "$dev"."_DEV";
			push(@cols, $name);
			push(@cols, $dev);
			$cnames = "$cnames".','."$name".","."$dev";
		}
		close(FH);
	
		$line = "$dom\t";
		foreach $aent (@name_list){
			$line = "$line\t"."${data.$aent}{val}[0]";
			$line = "$line\t"."${err.$aent}{val}[0]";
		}

#
#--- create an ascii data file
#
		open(OUT2, '>zdata');
		print OUT2 "$line\n";
		close(OUT2);
#
#--- convert the ascii data file into a fits file
#	
		system("dmcopy zdata zdata.fits clobber=yes");

#
#--- change column names to appropriate ones (e.g. col1, col2 to HAFTBGRD1_AVG, HAFTBGRD1_DEV)
#
		$j = 1;
		foreach $aent (@cols){
			$col = 'col'."$j";
			system("dmtcalc infile=zdata.fits outfile=temp.fits expression=\"$aent=$col\"");
			system("mv temp.fits zdata.fits");
			$j++;
		}
#
#--- here removing all columns named "col#"
#	
		$pline = 'zdata.fits[cols '."$cnames".']';
		system("dmcopy \"$pline\" outfile=zdata_clean.fits clobber=yes");
#
#--- merge the new data with the past data
#
		$fits = 'avg_'."$ent".'.fits';
print "$data_dir/$fits\n";
		system("dmmerge \"$data_dir/$fits,zdata_clean.fits\" outfile=out.fits clobber=yes");

		system("mv out.fits $data_dir/$fits");

		system("rm zout zdata zdata.fits zdata_clean.fits");
	}
}
close(OUT);




###########################################################################
###      conv_date_dom: modify data/time format                       #####
###########################################################################

sub conv_date_dom {

#############################################################
#       Input:  $year: year in a format of 2004
#               $month: month in a formt of  5 or 05
#               $day:   day in a formant fo 5 05
#
#       Output: acc_date: day of mission returned
#############################################################

        my($year, $month, $day, $chk, $acc_date);

        ($year, $month, $day) = @_;

        $acc_date = ($year - 1999) * 365;

        if($year > 2000 ) {
                $acc_date++;
        }elsif($year >  2004 ) {
                $acc_date += 2;
        }elsif($year > 2008) {
                $acc_date += 3;
        }elsif($year > 2012) {
                $acc_date += 4;
        }elsif($year > 2016) {
                $acc_date += 5;
        }elsif($year > 2020) {
                $acc_date += 6;
        }elsif($year > 2024) {
                $acc_date += 7;
        }

        $acc_date += $day - 1;
        if ($month == 2) {
                $acc_date += 31;
        }elsif ($month == 3) {
                $chk = 4.0 * int(0.25 * $year);
                if($year == $chk) {
                        $acc_date += 59;
                }else{
                        $acc_date += 58;
                }
        }elsif ($month == 4) {
                $acc_date += 90;
        }elsif ($month == 5) {
                $acc_date += 120;
        }elsif ($month == 6) {
                $acc_date += 151;
        }elsif ($month == 7) {
                $acc_date += 181;
        }elsif ($month == 8) {
                $acc_date += 212;
        }elsif ($month == 9) {
                $acc_date += 243;
        }elsif ($month == 10) {
                $acc_date += 273;
        }elsif ($month == 11) {
                $acc_date += 304;
        }elsif ($month == 12) {
                $acc_date += 334;
        }
        $acc_date -= 202;
        return $acc_date;
}


