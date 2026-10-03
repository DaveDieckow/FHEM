##############################################
# $Id: 99_myUtils.pm 7570 2015-01-14 18:31:44Z rudolfkoenig $
#
# Save this file as 99_myUtils.pm, and create your own functions in the new
# file. They are then available in every Perl expression.

package main;

use strict;
use warnings;
use POSIX;


sub
myUtils_Initialize($$)
{
  my ($hash) = @_;
}

sub MaxFakeWallThermostat($$)
{
 my ($heizung, $aktTemp)    = @_;
 my $CULMAX     = $defs{$heizung}{LASTInputDev};
 my $desiredTemp   = ReadingsVal($heizung, "desiredTemperature", undef);
 my $windowOpenTemp = ReadingsVal($heizung, "windowOpenTemperature", undef);
 my $lastTemp    = ReadingsVal($heizung, "LastExtTemperature", 0);
 my $lastSet     = ReadingsTimestamp($heizung, "LastExtTemperature", 0);
 if($desiredTemp && $windowOpenTemp &&
 $desiredTemp != $windowOpenTemp &&
 (time()-time_str2num($lastSet) >= 300 || abs($aktTemp-$lastTemp)>=0.2 )) {
  Log 3, "set $CULMAX fakeWT $heizung $desiredTemp $aktTemp";
  readingsSingleUpdate($defs{$heizung}, "LastExtTemperature", $aktTemp, 0);
  fhem("set $CULMAX fakeWT $heizung $desiredTemp $aktTemp");
 }
}

sub 
dewpoint_absFeuchte ($$)
{
    my ($T, $Hr) = @_;

    # 110 ?
    if (($Hr < 0) || ($Hr > 110)) {
        Log(1, "Error dewpoint: humidity invalid: $Hr");
        return "";
    }
    my $DD = dewpoint_vp($T, $Hr);
    my $AF  = 1.0E6 * (18.016 / 8314.3) * ($DD / (273.15 + $T));
    return round($AF, 1);
}


###############################################################################
#
#  Moving average 
#
#  Aufruf: movingAverage(devicename,readingname,zeitspanne in s)
#
###############################################################################

sub movingAverage($$$){
   my ($name,$reading,$avtime) = @_;
   my $hash = $defs{$name};
   my @new = my ($val,$time) = ($hash->{READINGS}{$reading}{VAL},$hash->{READINGS}{$reading}{TIME});
   my ($cyear, $cmonth, $cday, $chour, $cmin, $csec) = $time =~ /(\d+)-(\d+)-(\d+)\s(\d+):(\d+):(\d+)/;
   my $ctime = $csec+60*$cmin+3600*$chour;
   my $num;
   my $arr;
   #-- initialize if requested
   if( ($avtime eq "-1") ){
     $hash->{READINGS}{$reading}{"history"}=undef;
   }
   #-- test for existence
   if( !$hash->{READINGS}{$reading}{"history"}){
      #Log 1,"ARRAY CREATED";
      push(@{$hash->{READINGS}{$reading}{"history"}},\@new);
      $num = 1;
      $arr=\@{$hash->{READINGS}{$reading}{"history"}};
   } else {
      $num = int(@{$hash->{READINGS}{$reading}{"history"}});
      $arr=\@{$hash->{READINGS}{$reading}{"history"}};
      my $starttime = $arr->[0][1];
      my ($syear, $smonth, $sday, $shour, $smin, $ssec) = $starttime =~ /(\d+)-(\d+)-(\d+)\s(\d+):(\d+):(\d+)/;
      my $stime = $ssec+60*$smin+3600*$shour;
      #-- correct for daybreak
      $stime-=86400 
        if( $stime > $ctime);
      if( ($num < 25)&&( ($ctime-$stime)<$avtime) ){
        #Log 1,"ARRAY has $num elements, adding another one";
        push(@{$hash->{READINGS}{$reading}{"history"}},\@new);
      }else{
        shift(@{$hash->{READINGS}{$reading}{"history"}});
        push(@{$hash->{READINGS}{$reading}{"history"}},\@new);
      }
    }
    #-- output and average
    my $average = 0;
    for(my $i=0;$i<$num;$i++){
      $average+=$arr->[$i][0];
      Log 4,"[$name moving average] Value = ".$arr->[$i][0]." Time = ".$arr->[$i][1]; 
    }
    $average=sprintf( "%5.3f", $average/$num);
    #--average
    Log 4,"[$name moving average] calculated over $num values is $average";  
    return $average;
 }

##########################################################
# myAverage
# berechnet den Mittelwert aus LogFiles über einen beliebigen Zeitraum
sub
myAverage($$$)
{
 my ($offset,$logfile,$cspec) = @_;
 my $period_s = strftime "%Y-%m-%d\x5f%H:%M:%S", localtime(time-$offset);
 my $period_e = strftime "%Y-%m-%d\x5f%H:%M:%S", localtime;
 my $oll = $attr{global}{verbose};
 $attr{global}{verbose} = 0; 
 my @logdata = split("\n", fhem("get $logfile - - $period_s $period_e $cspec"));
 $attr{global}{verbose} = $oll; 
 my ($cnt, $cum, $avg) = (0)x3;
 foreach (@logdata){
  my @line = split(" ", $_);
  if(defined $line[1] && "$line[1]" ne ""){
   $cnt += 1;
   $cum += $line[1];
  }
 }
 if("$cnt" > 0){$avg = sprintf("%0.1f", $cum/$cnt)};
 Log 4, ("myAverage: File: $logfile, Field: $cspec, Period: $period_s bis $period_e, Count: $cnt, Cum: $cum, Average: $avg");
 return $avg;
}
##########################################################

sub 
tendencyGet($$$)
{
 my ($geraet, $wert, $hour)    = @_;
 my @val = split(/ /, ReadingsVal($geraet, $wert, 0) );
 #Log 4, ("tendencyGet:  wert: $wert, geraet: $geraet");
 if($hour eq "1h") {
 	return ($val[1] + 0);
 }
 elsif($hour eq "2h") {
 	return ($val[3] + 0);
 }
 elsif($hour eq "3h") {
 	return ($val[5] + 0);
 }
 elsif($hour eq "6h") {
 	return ($val[7] + 0);
 }
 else {
 	return (-1);
 }
}
##########################################################

sub
plotStatDay($$)
{
  my($devspec,$array) = @_; 
  
  #Log 2, ("plotStatDay: from: $from, to: $to, device: $device ");
  my $strp = DateTime::Format::Strptime->new(
    pattern => '%Y-%m-%d',
    time_zone => 'local',
  );

  foreach my $point ( @{$array} ) { 
  	my $ts = localtime($point->[0])->strftime('%F');
	my $dt = $strp->parse_datetime($ts);
	$point->[0] = $dt->epoch;
    Log 2, ("plotStatDay: $dt, $point->[1]");
  }    

  return $array;
}
##########################################################
sub    
negFn($$)
{      
  my($devspec,$array) = @_; 
      
  foreach my $point ( @{$array} ) { 
    $point->[1] *= -1;
  }    

  return $array;
}
##########################################################
sub Reg_Heizung_Lueftung($$) {
  my ( $valve_device, $fan_device) = @_;
  my $valve_position = ReadingsVal($valve_device,,'valveposition','50');

  
  Log3 "Reg_Heizung_Lueftung", 3, "Device=$valve_device DutyCycle=$fan_device Valve=$valve_position";
  
  if($valve_position < 10)
  {
  	fhem( "set $fan_device off" );
  }
  else
  {
  	fhem( "set $fan_device on" );
  }
  
}

#
# (c) mumpitzstuff 19.12.2018
#
# see https://forum.fhem.de/index.php/topic,83097.msg874150.html#msg874150
#
sub logProxy_dwd2Plot($$$$;$$$)
{
  my ($device, $fcValue, $from, $to, $fcHour, $expMode, $shiftTime) = @_;
  my $regex;
  my @rl;

  return undef if(!$device);

  if ($fcValue =~ s/_$//)
  {
    $regex = "^fc[\\d]+_[\\d]+_".$fcValue."\$";
  }
  else
  {
    $regex = "^fc[\\d]+_".$fcValue."\$";
  }

  $fcHour = 12 if(!defined($fcHour));
  $expMode = "point" if(!defined($expMode));
  #Log3 undef,2, "Regex: ".$regex;

  # ermitteln aller relevanten Readings
  if ( defined($defs{$device}) )
  {
    if ( $defs{$device}{TYPE} eq "DWD_OpenData" )
    {
      @rl = sort
      {
        my ($an) = ($a =~ m/fc(\d+)_.*/);
        my ($bn) = ($b =~ m/fc(\d+)_.*/);
        my ($ao) = ($a =~ m/fc\d+_(\d+).*/);
        my ($bo) = ($b =~ m/fc\d+_(\d+).*/);
        $an <=> $bn or $ao <=> $bo or $a cmp $b;
      } ( grep /${regex}/,keys %{$defs{$device}{READINGS}} );
      return undef if ( !@rl );
    }
    else
    {
      Log3 undef, 2, "logProxy_dwd2Plot: $device is not a DWD_OpenData device";
      return undef;
    }
  }

  my $fromsec = SVG_time_to_sec($from);
  my $tosec   = SVG_time_to_sec($to);
  my $sec = $fromsec;
  my ($h, $hp, $fcDay, $mday, $mon, $year);
  my $timestamp;

  my $reading;
  my $value;
  my $prev_value;
  my $min = 999999;
  my $max = -999999;
  my $ret = "";

  # while not end of plot range reached
  while (($sec < $tosec) && @rl)
  {
    #remember previous value for start of plot range
    $prev_value = $value;

    $reading = shift @rl;
    ($fcDay) = $reading =~ m/^fc(\d+).*/;
    ($hp) = $reading =~ m/^fc\d+_(\d+).*/;
    #Log 1, "hp: ".$hp;

    if ($hp)
    {
      $h = ReadingsVal($device, "fc".$fcDay."_".$hp."_time", $fcHour);
      if ($h =~ m/^(\d+):\d+/)
      {
        $h = $1;
      }
    }
    else
    {
      $h = $fcHour;
    }

    $value = ReadingsVal($device, $reading, undef);

    # calculate minutes of sunshine per hour
    if ($fcValue =~ /^SunD(\d+)/)
    {
      if (defined($1))
      {
        $value = $value / ($1 * 36);
      }
      else
      {
        $value = $value / (12 * 36);
      }
    }

    # calculate amount of rain per hour
    if ($fcValue =~ /^RR(\d+)c$/)
    {
      if (defined($1))
      {
        $value /= $1;
      }
    }

    ($year, $mon, $mday) = split('\-',ReadingsVal($device, "fc".$fcDay."_date",undef));
    $timestamp = sprintf("%04d-%02d-%02d_%02d:%02d:%02d", $year, $mon, $mday, $h, 0, 0);
    $sec = SVG_time_to_sec($timestamp);
    if (defined($shiftTime))
    {
      $sec += $shiftTime;
      $timestamp = logProxy_shiftTime($timestamp, $shiftTime);
    }

    # skip all values before start of plot range
    next if ( $sec < $fromsec );

    # add first value at start of plot range
    if ( !$ret && $prev_value )
    {
      $min = $prev_value if ( $prev_value < $min );
      $max = $prev_value if ( $prev_value > $max );
      $ret .= "$from $prev_value\n";
    }

    # done if after end of plot range
    last if ($sec > $tosec);

    $min = $value if ( $value < $min );
    $max = $value if ( $value > $max );

    # add actual control point
    $ret .= "$timestamp $value\n";
  }

  if (($sec < $tosec) && !@rl && ($expMode eq "day"))
  {
    $timestamp = sprintf("%04d-%02d-%02d_%02d:%02d:%02d", $year, $mon, $mday, 23, 59, 59);
    $_ = SVG_time_to_sec($timestamp);
    if (defined($shiftTime))
    {
      $_ += $shiftTime;
      $timestamp = logProxy_shiftTime($timestamp, $shiftTime);
    }

    if ($_ < $tosec)
    {
      $ret .= "$timestamp $value\n";
    }
    else
    {
      $ret .= "$to $value\n";
    }
  }
  elsif (($sec > $tosec) && ($expMode eq "day"))
  {
    $value = $prev_value + ($value - $prev_value) * (86400 + ($tosec - $sec)) / 86400;
    $ret .= "$to $value\n";
  }

  return ($ret, $min, $max, $prev_value);
} 

1;
