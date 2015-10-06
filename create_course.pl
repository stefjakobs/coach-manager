#!/usr/bin/perl -wT

######
# Copyright (c) 2013-2015 Stefan Jakobs
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
use lib '.';
use functions;


my $error;
my $sth;
my ($course_name, $start_date, $end_date, $start_time, $end_time, $id) = ( '', '', '', '', '', '');
my $course_number = '';
my $cgi = CGI->new;

my %config = read_config();

## Gleiches Formular wie in edit_course.pl, aber ohne ID-Feld
sub print_formular() {
   print <<"EOF"; 
   <h3> Kurs anlegen </h3>
   <p>F&uuml;lle das Formular aus und lege den Kurs mit einem Klick auf dem Button an</p>
   <div id="edit-form">
   <form action="$config{'S_CREATE_COURSE'}" name="add_course" method="post">
   <table>
      <tr>
         <td class="create_td">Kursname:</td>
         <td class="create_td"><input class="input_form" type="text" name="course_name" value="$course_name"></td>
      </tr><tr>
         <td class="create_td">Kursnummer:</td>
         <td class="create_td"><input class="input_form" type="text" name="course_number" value="$course_number"></td>
      </tr><tr>
         <td class="create_td">Startdatum:</td>
         <td class="create_td"><input class="input_form" type="text" name="start_date" value="$start_date"></td>
      </tr><tr>
         <td class="create_td">Enddatum:</td>
         <td class="create_td"><input class="input_form" type="text" name="end_date" value="$end_date"></td>
      </tr><tr>
         <td class="create_td">Kurs startet um:</td>
         <td class="create_td"><input class="input_form" type="text" name="start_time" value="$start_time"></td>
      </tr><tr>
         <td class="create_td">Kurs endet um:</td>
         <td class="create_td"><input class="input_form" type="text" name="end_time" value="$end_time"></td>
      </tr><tr>
         <td class="create_td"></td>
         <td class="create_td"><input class="button" type="submit" name="submit" value="Kurs anlegen"></td>
      </tr>
   </table>
   </form>
   </div>
EOF
}

sub untaint_input() {
   ## untaint input
   if ( defined($cgi->param('course_name')) and $cgi->param('course_name') =~ /^[a-zA-Z0-9_-]+$/i ) {
      $course_name = $cgi->param('course_name');
   } else {
      $error .= "Kursname darf nur aus Buchstaben und Zahlen bestehen!<br>";
   }
   if ( defined($cgi->param('course_number')) and $cgi->param('course_number') =~ /^\d{1,10}$/) {
      $course_number = $cgi->param('course_number');
   } else {
      $error .= "Kursnummer muss eine Zahl sein!<br>";
   }
   if ( defined($cgi->param('start_date')) and $cgi->param('start_date') =~ /^\d{4}-\d{2}-\d{2}$/) {
      $start_date = $cgi->param('start_date');
   } else {
      $error .= "Datum muss das Format JJJJ-MM-DD haben!<br>";
   }
   if ( defined($cgi->param('end_date')) and $cgi->param('end_date') =~ /^\d{4}-\d{2}-\d{2}$/) {
      $end_date = $cgi->param('end_date');
   } else {
      $error .= "Datum muss das Format JJJJ-MM-DD haben!<br>";
   }
   if ( defined($cgi->param('start_time')) and $cgi->param('start_time') =~ /^\d{1,2}:\d{2}(?:\:00)?$/) {
      if ( $cgi->param('start_time') =~ /^\d{1,2}:\d{2}:00$/) {
         $start_time = $cgi->param('start_time');
      } else {
         $start_time = $cgi->param('start_time') .':00';
      }
   } else {
      $error .= 'Startzeit muss das Format SS:MM haben!<br>';
   }
   if ( defined($cgi->param('end_time')) and $cgi->param('end_time') =~ /^\d{1,2}:\d{2}(?:\:00)?$/) {
      if ( $cgi->param('end_time') =~ /^\d{1,2}:\d{2}:00$/) {
         $end_time = $cgi->param('end_time');
      } else {
         $end_time = $cgi->param('end_time') .':00';
      }
   } else {
      $error .= 'Endzeit muss das Format SS:MM haben!<br>';
   }
}

# Connect to the database.
my $dbh = init_db(\%config);


# Read in text
if (defined($ENV{'REQUEST_METHOD'}) and uc($ENV{'REQUEST_METHOD'}) eq "POST") {
   untaint_input();

   if (! defined($error)) {
      eval { $dbh->do( "INSERT INTO $config{'T_COURSE'} ( name, number, startdate, enddate, starttime, endtime )
                        VALUES (\"$course_name\", \"$course_number\", \"$start_date\", \"$end_date\", \"$start_time\", \"$end_time\")" )
      };
      if ($@) {
         $error .= "Insert failed: $@\n";
      } else {
         ## Get course ID
         my $sth = $dbh->prepare( "SELECT id FROM $config{'T_COURSE'} WHERE name=\"$course_name\"" );
            $sth->execute();
         #my $ref = $sth->fetchrow_hashref();
         ## ATTENTION: We use only the first result row (but there should be only one row as result)
         ##            but we don't check it.
         my $course_id = $sth->fetchrow_hashref()->{'id'};

         ## create recuring event
         my $event = new Date::Manip::Recur;
         $event->config("Language","de");
         my $err = $event->parse("0:0:0:7*:0:0", "$start_date", "$start_date", "$end_date");
         $error .= "Parsing event failed: " . $event->err() if $err;

         ## insert dates of recuring event into mysql table
         my @dates = $event->dates();
         foreach my $date (@dates) {
            #print $date->printf("%a") .": " . $date->printf("%Y-%m-%d") ."\n";
            my $next = $date->printf("%Y-%m-%d");
            eval { $dbh->do( "INSERT INTO $config{'T_EVENT'} ( date, course_id)
                              VALUES (\"$next\", $course_id)" )
            };
            $error .= "Insert failed: $@\n" if $@;
         }
      }
   }


   print_start_html($cgi, "Kurs angelegt");
   print_link_list($config{'S_CREATE_COURSE'});
   print_formular();
   if (defined($error)) {
      print "<p class=\"error\">$error</p>";
   } else {
      print "<p class=\"notice\">Kurs $course_name wurde angelegt.</p>";
   }
} else {
   $cgi->header('multipart/form-data');
   print_start_html($cgi, 'Kurs anlegen');
   print_link_list($config{'S_CREATE_COURSE'});
   print_formular();
}
print_end_html($cgi);

1;
