#!/usr/bin/perl -wT

######
# Copyright (c) 2013-2016 Stefan Jakobs
#
# This file is part of coach-manager.
#
# coach-manager is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# coach-manager is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with coach-manager.  If not, see <http://www.gnu.org/licenses/>.
#
#####################################################################
# This was written by:
#       Stefan Jakobs <projects@localside.net>
#
# Please send all comments, suggestion, bug reports, etc
#       to projects@localside.net
#
#####################################################################

use strict;
no warnings 'deprecated';
use DBI;
use CGI;
use Date::Manip;
use utf8;
use lib '.';
use functions;
use POSIX qw(locale_h);

setlocale(LC_ALL, "de_DE.UTF-8");

my $error;
my $sth;
#my ($coach_id, $street, $zipcode, $city, $scale, $course_id, $timerange, $iban);
my $coach_id = 'x';
my $street = 'x';
my $zipcode = 'x';
my $city = 'x';
my $scale = 'x';
my $course_id = 'x';
my $timerange = 'x';
my $iban = 'x';

my $cgi = CGI->new;

my %config = read_config();

# Connect to the database.
my $dbh = init_db(\%config);

## Adminportal 
sub print_formular($$$$$$$$$) {
   my $last_name = shift;
   my $first_name = shift;
   my $street = shift;
   my $zipcode = shift;
   my $city = shift;
   my $scale = shift;
   my $course_id  = shift;
   my $timerange = shift;
   my $iban = shift;
   my $course_term = 'x';
   my $course_name = 'x';
   my $course_number = '0';
   my $course_start = 'x';
   my $course_end = 'x';
   my $sum = '0';
   my $sum_coaching = '0';

   # get event list
   my %event_list;
   my $sth = $dbh->prepare("SELECT id, date FROM $config{'T_EVENT'} WHERE course_id = \"$course_id\" AND omitted = \"0\"");
   eval { $sth->execute(); };
   $error .= "SELECT failed: $@<br>\n" if $@;
   while (my $ref = $sth->fetchrow_hashref()) {
      $event_list{"$ref->{'id'}"} = $ref->{'date'};
   }

   # get course details
   $sth = $dbh->prepare("SELECT * FROM $config{'T_COURSE'} WHERE id = \"$course_id\"");
   eval { $sth->execute(); };
   $error .= "SELECT failed: $@<br>\n" if $@;
   my $ref = $sth->fetchrow_hashref();
   $course_name   = $ref->{'name'};
   $course_number = $ref->{'number'};
   $course_start  = $ref->{'starttime'};
   $course_end    = $ref->{'endtime'};
   # set course term to: WS|SS YEAR
   my ($y,$m,$d) = split /-/, $ref->{'startdate'};
   if ($m >= 4 and $m < 10) {
      $course_term  = 'SS ' . $y;
   } else {
      $course_term  = 'WS ' . $y;
   }

   $sth->finish();

   ## calculate course duration and coaching rate
   my $date1 = new Date::Manip::Date;
   my $date2 = new Date::Manip::Date;
   my $err = $date1->parse("$course_start");
   $error .= "Parsing failed: $err<br>\n" if $err;
   $err = $date2->parse($course_end);
   $error .= "Parsing failed: $err<br>\n" if $err;
   my $delta = $date1->calc($date2);
   my $course_diff = $delta->printf('%hv:%02mv');
   # $course_rate = $course_diff / $timerange 
   my $course_rate = $delta->printf('%mhm') / $timerange; 

   print "<p> $error </p>\n" if $error;

   print <<"EOF"; 
   <h3> Rechnung &Uuml;bungsleiter Hochschulsport </h3>
   <table class="names_table">
      <tr>
         <th class="names_name_th">Nachname</th>
         <td class="names_name_td">$last_name</td>
         <th class="names_name_th">Vorname</th>
         <td class="names_name_td">$first_name</td>
      </tr>
   </table >
   <table class="names_table">
      <tr>
         <th class="names_name_th">Stra&szlig;e</th>
         <td colspan="3" width="85%">$street</td>
      </tr>
      <tr>
         <th class="names_name_th">PLZ:</th>
         <td width="25%">$zipcode</td>
         <th width="10%" align="left">Ort:</th>
         <td width="50%">$city</td>
      </tr>
   </table>
   <table class="course_table">
      <tr>
         <th class="course_th">Kursbezeichnung:</th>
         <td class="course_td_50">$course_name</td>
         <th class="course_th"">Semester:</th>
         <td class="course_td_20">$course_term</td>
      </tr>
   </table>
   <table class="timing_table">
      <tr>
         <th class="timing_th">&Uuml;L-Tarif:</th>
         <td class="timing_td">$scale EUR pro $timerange Min</td>
      </tr>
   </table>
   <table class="schedule_table">
      <tr>
         <th width="15%">Datum</th>
         <th width="20%">Kurs-Nr.</th>
         <th width="15%">von</th>
         <th widht="15%">bis</th>
         <th width="15%">Gesamt-<br />zeit</th>
         <th width="20%">Trainings-<br />einheiten</th>
      </tr>
EOF
   foreach my $event_id (sort{$event_list{$a} cmp $event_list{$b}} keys %event_list) {
       print "         <td class=\"schedule_td\">$event_list{$event_id}</td>" ."\n";
       if ($course_number == 0) {
           print "         <td class=\"schedule_td\">$course_name</td>\n";
       } else {
           print "         <td class=\"schedule_td\">$course_number</td>\n";
       }
       print "         <td class=\"schedule_td\">$course_start</td>\n";
       print "         <td class=\"schedule_td\">$course_end</td>\n";
       print "         <td class=\"schedule_td\">$course_diff</td>\n";
       printf "         <td class=\"schedule_td\">%.2f</td>\n", $course_rate;
       print "      </tr><tr>\n";
       $sum_coaching += $course_rate
   }
   print "      </tr>\n";
# TODO: scale causes error because of wrong decimal point (, vs .)
   $sum = sprintf "%.2f EUR", $sum_coaching * $scale;
   print <<"EOF"; 
      <tr>
         <th width="80%" colspan="5" align="right">Summe Trainingseinheiten</th>
         <th width="20%" align="center"> $sum_coaching </th>
      </tr>
   </table>
   <h4>Bankverbindung</h4>
   <table class="banking_table">
      <tr>
         <th class="banking_th" width="15%">Bankleitzahl:</th>
         <td class="banking_td" width="35%"></td>
         <th class="banking_th" width="25%">Gesamt Betrag</th>
         <th class="sum_td" widht="25%">$sum</td>
      </tr>
      <tr>
         <th width="15%" align="right">Konto Nr.</th>
         <td width="60%" colspan="2"></td>
         <td width="25%" border=0></td>
      </tr>
      <tr>
         <th width="15%" align="right">IBAN:</th>
         <td width="60%" colspan="2">$iban</td>
         <td width="25%" border=0></td>
      </tr>
      <tr>
         <th width="15%" align="right">BIC:</th>
         <td width="60%" colspan="2"></td>
         <td width="25%" border=0></td>
      </tr>
   </table>
   <table class="signing_table">
      <tr>
         <td class="signing_td">________________________________________</td>
      </tr>
      <tr>
         <th class="signing_td">Datum und Unterschrift</th>
      </tr>
   </table>
EOF
}

sub untaint_input() {
   ## untaint input
   if (defined($cgi->param('coach_id')) and $cgi->param('coach_id') =~ /^\d+$/ ) {
      $coach_id = $cgi->param('coach_id');
   } else {
      $error .= "Coach-ID ist keine Zahl!<br>";
   }
   if (defined($cgi->param('course_id')) and $cgi->param('course_id') =~ /^\d+$/ ) {
      $course_id  = $cgi->param('course_id');
   } else {
      $error .= "Kurs-ID ist keine Zahl!<br>";
   }
   if ( defined($cgi->param('street')) and $cgi->param('street') =~ /^[\wßäüö 0-9._-]+$/i ) {
      $street = $cgi->param('street');
   } else {
      $error .= "Die Stra&szlig;e darf nur aus Buchstaben, Zahlen, Leerzeichen, _ und - bestehen!<br>";
   }
   if ( defined($cgi->param('zipcode')) and $cgi->param('zipcode') =~ /^[0-9]{5}$/ ) {
      $zipcode = $cgi->param('zipcode');
   } else {
      $error .= "Die Postleitzahl muss aus 5 Zahlen bestehen!<br>";
   }
   if ( defined($cgi->param('city')) and $cgi->param('city') =~ /^[\wßäüö 0-9._-]+$/i ) {
      $city = $cgi->param('city');
   } else {
      $error .= "Die Stadt darf nur aus Buchstaben, Zahlen, Leerzeichen, _ und - bestehen!!<br>";
   }
   if ( defined($cgi->param('scale')) and $cgi->param('scale') =~ /^[0-9]+(?:,[0-9]{2})$/ ) {
      $scale = $cgi->param('scale');
      tr/,/./ for $scale;
   } else {
      $error .= 'Der Tarif muss eine Ganzzahl oder eine Dezimalzahl mit zwei Nachkommastellen sein!<br>';
   }
   if ( defined($cgi->param('iban')) and $cgi->param('iban') =~ /^[A-Z]{2}[0-9]{20}$|^$/ ) {
      $iban = $cgi->param('iban');
   } else {
      $error .= 'Die IBAN hat ein falsches Format! (Bsp: AB12345678901234567890)<br>';
   }
   if ( defined($cgi->param('timerange')) and $cgi->param('timerange') =~ /^60|45$/ ) {
      $timerange = $cgi->param('timerange');
   } else {
      $error .= 'Es kann nur je 45 oder 60 Minuten abgerechnet werden!<br>';
   }
}

print_start_html($cgi, 'Abrechnung', '../print.css');
untaint_input();

# get coach details
my %coach = get_coach_name($dbh, $config{'T_COACH'}, $coach_id);
# lastname, firstname, street, zipcode, city, scale, course_id, timerange, iban
print_formular($coach{'last_name'}, $coach{'first_name'}, $street, $zipcode, $city, $scale, $course_id, $timerange, $iban);


1;
