#!/usr/bin/perl 

#
#---- set a directory
#

$main_dir      = '/data/mta/Script/Trending/';
$mp_dir        = '/data/mta/Script/Trending/house_keeping/Input/';
$script_dir    = "$main_dir/Trending_Script/";
$house_keeping = "$script_dir/house_keeping/";
$data_dir      = "$main_dir/Test_out/";

system("mkdir $main_dir/Test_out");
system("cp $house_keeping/Test_prep/Trend_data/* $data_dir/.");
