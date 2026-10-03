##############################################
# $Id: 99_ReglerFuBoHeUtils.pm 7570 2015-01-14 18:31:44Z rudolfkoenig $
#
# Save this file as 99_myUtils.pm, and create your own functions in the new
# file. They are then available in every Perl expression.

package main;

use strict;
use warnings;
use POSIX;

sub
ReglerFuBoHeUtils_Initialize($$)
{
  my ($hash) = @_;
}

# Enter you functions below _this_ line.
my $state_Fussbodenheizung;
my $min_on_time = 60;
my $max_on_time = 1800;
my $min_temperatur = 10;



sub Regler_Fussbodenheizung_old($$) {
  my ( $therm_device, $pump_device) = @_;
  my $desired_temperature = ReadingsVal($therm_device,,'desiredTemperature','20');
  my $curent_temperature = ReadingsVal($therm_device,'temperature','20');
  my $on_time = $min_on_time;
  
  #Steigung berechnen
  my $m = ($max_on_time-$min_on_time) / ($desired_temperature-$min_temperatur);
  #Verschiebeung berechnen
  my $t = $min_on_time - ($m * 10);
  $on_time = ($m * $curent_temperature) + $t;
  
  if($curent_temperature >= $desired_temperature) {
  	$on_time = $min_on_time;
  }
  
  if($curent_temperature <= $desired_temperature) {
  	$on_time = $max_on_time;
  }
  
  Log3 "Regler_Fussbodenheizung", 3, "Device=$therm_device DesiredTemp=$desired_temperature CurrentTemp=$curent_temperature OnTime=$on_time";
  
  fhem( "set $pump_device on-for-timer $on_time" );
}

sub Regler_Fussbodenheizung_PWM($$) {
  my ( $pid_device, $pump_device) = @_;
  my $duty_cycle = ReadingsVal($pid_device,,'actuation','50');
  my $on_time = 0 ;
  my $PulseTime = 0 ;
  
  $on_time = (($duty_cycle / 10)) * 360;
  
  Log3 "Regler_Fussbodenheizung", 3, "Device=$pid_device DutyCycle=$duty_cycle OnTime=$on_time";
  
  if($duty_cycle < 10)
  {
  	fhem( "set $pump_device off" );
  }
  elsif($duty_cycle > 90) 
  {
  	fhem( "set $pump_device on" );
  }
  else
  {
  	$PulseTime = 100 + $on_time;
	#fhem( "set $pump_device PulseTime $PulseTime" );
  	fhem( "set $pump_device on-for-timer $PulseTime");
  }
  
}

sub Regler_Fussbodenheizung($$) {
  my ( $therm_device, $pump_device) = @_;
  my $desired_temperature = ReadingsVal($therm_device,,'desiredTemperature','20');
  my $curent_temperature = ReadingsVal($therm_device,'temperature','20');

  my $hyst_upper = $desired_temperature - '1.0';
  my $hyst_lower = $desired_temperature + '1.0';

  if($curent_temperature < $hyst_upper) 
  {
  	Log3 "Regler_Fussbodenheizung", 2, "Pump=on Device=$therm_device DesiredTemp=$desired_temperature CurrentTemp=$curent_temperature $hyst_upper $hyst_lower";
  	fhem( "set $pump_device on" );
  } 
  elsif($curent_temperature > $hyst_lower) 
  {
  	Log3 "Regler_Fussbodenheizung", 2, "Pump=off Device=$therm_device DesiredTemp=$desired_temperature CurrentTemp=$curent_temperature $hyst_upper $hyst_lower";
  	fhem( "set $pump_device off" );
  }
  
}


1;
