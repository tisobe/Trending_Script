#!/usr/bin/perl 

$file = $ARGV[0];
$line = `cat $file`;
@input = split(/\s+/, $line);
$cnt = 0; 
foreach $ent (@input){
	print "$ent\n";
	$cnt++;
}
print "\n\n$cnt\n";
