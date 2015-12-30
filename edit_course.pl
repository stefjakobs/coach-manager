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
use lib '.';
use functions;

my $error;
my $sth;
my ($course_name, $course_number, $start_date, $end_date, $start_time, $end_time, $id);
my $cgi = CGI->new;

my %config = read_config();

## Gleiches Formular wie in create_course.pl, aber mit ID-Feld
sub print_formular() {
   print <<"EOF"; 
   <body>
   <h3> Kurs bearbeiten </h3>
   <p>F&uuml;lle das Formular aus und best&auml;tige die &Auml;nderungen mit dem Button</p>
   <div id="edit-form">
   <form action="$config{'S_EDIT_COURSE'}" name="edit_course" method="post">
   <input type="hidden" name="id" value="$id"></td>
   <table>
      <tr>
         <td class="create_td">Kursname:</td>
         <td class="create_td"><input class="input_form" type="text" name="course_name" value="$course_name"></td>
      </tr><tr>
         <td class="create_td">Kursnummer:</td>
         <td class="create_td"><input class="input_form" type="text" name="course_number" value="$course_number"></td>
      </tr><tr>
         <td class="create_td">Startdatum:</td>
         <td class="td_info">$start_date: Dies kann nicht nachtr&auml;glich ver&auml;ndert werden!!
                             <input type="hidden" name="start_date" value="$start_date"></td>
      </tr><tr>
         <td class="create_td">Enddatum:</td>
         <td class="create_td"><input class="input_form" type="text" name="end_date" value="$end_date"></td>
      </tr><tr>
         <td class="create_td">Kurs beginnt um:</td>
         <td class="create_td"><input class="input_form" type="text" name="start_time" value="$start_time"></td>
      </tr><tr>
         <td class="create_td">Kurs endet um:</td>
         <td class="create_td"><input class="input_form" type="text" name="end_time" value="$end_time"></td>
      </tr><tr>
         <td class="create_td"></td>
         <td class="create_td"><input class="button" type="submit" name="submit" value="Kurs bearbeiten"></td>
      </tr>
   </table>
   </form>
   </div>
   </body>
EOF
}

sub untaint_input() {
   ## untaint input
   if ( defined($cgi->param('course_name')) and $cgi->param('course_name') =~ /^[a-zA-Z0-9_-]+$/i ) {
      $course_name = $cgi->param('course_name');
   } else {
      $error .= "Kursname darf nur aus Zahlen und Buchstaben bestehen!<br>";
   }
   if ( defined($cgi->param('course_number')) and $cgi->param('course_number') =~ /^\d{1,10}$/ ) {
      $course_number = $cgi->param('course_number');
   } else {
      $error .= "Kursnummer muss eine Zahl sein!<br>";
   }
   if ( defined($cgi->param('start_date')) and $cgi->param('start_date') =~ /^\d{4}-\d{2}-\d{2}$/) {
      $start_date = $cgi->param('start_date');
   } else {
      $error .= "Startdatum muss das Format JJJJ-MM-DD haben!<br>";
   }
   if ( defined($cgi->param('end_date')) and $cgi->param('end_date') =~ /^\d{4}-\d{2}-\d{2}$/) {
      $end_date = $cgi->param('end_date');
   } else {
      $error .= "Enddatum muss das Format JJJJ-MM-DD haben!<br>";
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
   $id = $cgi->param('id');
}

# Connect to the database.
my $dbh = init_db(\%config);


# Read in text
if (defined($ENV{'REQUEST_METHOD'}) and uc($ENV{'REQUEST_METHOD'}) eq "POST") {
   print_start_html($cgi, 'Kurs bearbeitet');
   print_link_list($config{'S_LIST_COURSE'});
   untaint_input();

   ## get old course dates
   my $sth = $dbh->prepare( "SELECT enddate FROM $config{'T_COURSE'} WHERE id=\"$id\"" );
      $sth->execute();
   ## ATTENTION: We use only the first result row (but there should be only one row as result)
   ##            but we don't check it.
   my $old_end_date   = $sth->fetchrow_hashref()->{'enddate'};

   ## Update Course
   if (! defined($error)) {
      eval { $dbh->do("UPDATE $config{'T_COURSE'} SET name=\"$course_name\",
                       number=\"$course_number\",
                       enddate=\"$end_date\",  starttime=\"$start_time\", endtime=\"$end_time\"
                       WHERE id = $id " )
      };
      $error .= "Alter failed: $@\n" if $@;
   }

   ## check if the dates have changed
   ## create recuring event list of difference between old and new end_date
   my $event = new Date::Manip::Recur;
   $event->config("Language","de");
   my $date_cmp = Date_Cmp(ParseDate($old_end_date), ParseDate($end_date));

   if ($date_cmp == -1) {
      # $old_end_date is earlied than $end_date : ADD EVENTS
      my $err = $event->parse("0:0:0:7*:0:0", "$start_date", "$old_end_date", "$end_date");
      $error .= "Parsing event failed: " . $event->err() if $err;
      my @dates = $event->dates();
      foreach my $date (@dates) {
         if ($config{'debug'}) { print_debug("ADD: " . $date->printf("%a: %Y-%m-%d")); };
         my $next = $date->printf("%Y-%m-%d");
         ## check if event already exists
         my $sth = $dbh->prepare("SELECT id FROM $config{'T_EVENT'}
                                  WHERE course_id = \"$id\" AND date = \"$next\"
                                 ");
         $sth->execute();
         if ( $sth->rows == 0) {
            ## event doesn't exist create it
            eval { $dbh->do( "INSERT INTO $config{'T_EVENT'} ( date, course_id)
                              VALUES (\"$next\", $id)" )
            };
            $error .= "Insert failed: $@\n" if $@;
         }
      }
   } elsif ($date_cmp == 1) {
      # $old_end_date is later than $end_date : DELETE EVENTS
      my $err = $event->parse("0:0:0:7*:0:0", "$start_date", "$end_date", "$old_end_date");
      $error .= "Parsing event failed: " . $event->err() if $err;
      my @dates = $event->dates();
      foreach my $date (@dates) {
         if ($config{'debug'}) { print_debug("DELETE: " . $date->printf("%a: %Y-%m-%d")); };
         my $next = $date->printf("%Y-%m-%d");
         eval { $dbh->do( "DELETE FROM $config{'T_EVENT'}
                           WHERE date = \"$next\" AND course_id = $id" )
         };
         $error .= "Insert failed: $@\n" if $@;
      }
   } else { 
      # $date_cmp == 0: dates are equal
      # NOTHING TO DO
   }

   print_formular();
   if (defined($error)) {
      print "<p class=\"error\">$error</p>";
   } else {
      print "<p class=\"notice\">Kurs $course_name wurde ge&auml;ndert.</p>";
   }
} else {
   if (defined($cgi->param('id')) and $cgi->param('id') =~ /^\d+$/) {
      $sth = $dbh->prepare("SELECT * FROM $config{'T_COURSE'} WHERE id = " . $cgi->param('id'));
      if (!$sth) { 
         $error .= "select failed: " . $dbh->errstr . "\n";
      } else {
         $sth->execute();
         my $ref = $sth->fetchrow_hashref(); 
         $course_name   = $ref->{'name'};
         $course_number = $ref->{'number'};
         $start_date    = $ref->{'startdate'};
         $end_date      = $ref->{'enddate'};
         $start_time    = $ref->{'starttime'};
         $end_time      = $ref->{'endtime'};
         $id            = $cgi->param('id');
         $sth->finish();
      }
      print_start_html($cgi, 'Kurs bearbeiten');
      print_link_list($config{'S_LIST_COURSE'});
      print_formular();

      if (defined($error)) {
         print "<p class=\"error\">$error</p>";
      }
   } else {
      print_start_html($cgi, 'Fehler: falscher Modus!');
   }
}
print_end_html($cgi);

