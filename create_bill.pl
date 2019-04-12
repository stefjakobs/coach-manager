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
use utf8;
use lib '.';
use functions;

my $sth;
my $error;
my ($street, $zipcode, $city, $scale, $iban) = ('', '', '', '', '', '');
my ($license, $coach_id, $course_id, $course_name, $timerange);
my $first_name;
my $last_name;
my $cgi = CGI->new;

my @coach;
my %config = read_config();

# Connect to the database.
my $dbh = init_db(\%config);

sub print_formular() {
   print <<"EOF"; 
   <h3> Abrechnung erstellen </h3>
   <p>F&uuml;lle das Formular aus und erstelle die Abrechnung durch klicken des Buttons:</p>
   <div id="edit-form">
   <form action="$config{'S_CREATE_BILL'}" name="create_bill" method="post">
   <table width=40%>
      <tr>
         <td class="create_td">Name:</td>
         <td class="create_td" colspan="2">$first_name $last_name</td>
      </tr><tr>
         <td class="create_td">Stra&szlig;e:</td>
         <td class="create_td" colspan="2"><input class="input_form" type="text" name="street" value="$street"></td>
      </tr><tr>
         <td class="create_td">Postleitzahl:</td>
         <td class="create_td" colspan="2"><input class="input_form" type="text" name="zipcode" value="$zipcode"></td>
      </tr><tr>
         <td class="create_td">Stadt:</td>
         <td class="create_td" colspan="2"><input class="input_form" type="text" name="city" value="$city"></td>
      </tr><tr>
         <td class="create_td">Tarif (in EUR) je:</td>
         <td class="create_td"><input class="input_form" type="text" name="scale" value="$scale"></td>
         <td class="create_td"><select class="flat" name="timerange">
            <option value="60">60 Min</option>
            <option value="45">45 Min</option>
         </select>
      </tr><tr>
         <td class="create_td">IBAN:</td>
         <td class="create_td" colspan="2"><input class="input_form" type="text" name="iban" value="$iban"></td>
      </tr>
      <input type="hidden" name="coach_id" value="$coach_id">
      <input type="hidden" name="course_id" value="$course_id">
   </table>
   <input class="button" type="submit" name="submit" value="Abrechnung anzeigen">
   </form>
   </div>
EOF
}

sub untaint_input() {
   ## untaint input
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

# get coach name and course dates
if (defined($cgi->param('coach_id')) and $cgi->param('coach_id') =~ /^\d+$/) {
   my %coach = get_coach_name($dbh, $config{'T_COACH'}, $cgi->param('coach_id'));
   $first_name = $coach{'first_name'};
   $last_name  = $coach{'last_name'};
   $license    = $coach{'license'};
   $coach_id   = $cgi->param('coach_id');
} else {
   $error .= 'Die Trainer-ID ist keine Zahl!<br>';
}
if (defined($cgi->param('course_id')) and $cgi->param('course_id') =~ /^\d+$/) {
   $course_id = $cgi->param('course_id');
} else {
   $error .= 'Die Kurs-ID ist keine Zahl!<br>';
}

if (defined($license) and $license =~ /^(?:A|B|C)$/) {
   $scale = '16,00';
} else {
   $scale = '10,00';
}

# Read in text
if (defined($ENV{'REQUEST_METHOD'}) and uc($ENV{'REQUEST_METHOD'}) eq "POST") {
   untaint_input();
   if (defined($error)) {
      print_start_html($cgi, 'Abrechnung erstellen');
      print_link_list($config{'S_CREATE_REPORT'});
      print_formular();
      print "<p class=\"error\">$error</p>";
   } else {
      print $cgi->redirect($config{'S_LIST_BILL'} ."?coach_id=" .$coach_id
                                                 . "&street=" .$street
                                                 . "&zipcode=" .$zipcode
                                                 . "&city=" .$city
                                                 . "&scale=" .$scale
                                                 . "&course_id=" .$course_id
                                                 . "&timerange=" .$timerange
                                                 . "&iban=" .$iban
                                                 );
   }
} else {
   print_start_html($cgi, 'Abrechnung erstellen');
   print_link_list($config{'S_CREATE_REPORT'});
   print_formular();
   if (defined($error)) {
      print "<p class=\"error\">$error</p>";
   }
}
print_end_html($cgi);

1;
