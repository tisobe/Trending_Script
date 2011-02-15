#!/usr/bin/perl 

$file = $ARGV[0];

$input =`cat $file`;
@line  = split(/\n/, $input);
OUTER:
foreach $ent (@line){
	if($ent =~ /ROW/){
		@atemp = split(/\s+/, $ent);
		$cnt = 0; 
		foreach $ent (@atemp){
			print "$ent\n";
			$cnt++;
		}
		print "\n\n $cnt\n";
		last OUTER;
	}
	
}
