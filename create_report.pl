#!/usr/bin/perl -wT

######
# Copyright (c) 2013 Stefan Jakobs
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
use DBI;
use CGI;
use lib '.';
use functions;

## global variables
my $error;
my $sth;
my $course_id = '';
my $start_date = '';
my $end_date = '';
my (%course_list, %coach_list, %event_list);
my $cgi = CGI->new;

my %config = read_config();

# Connect to the database.
my $dbh = init_db(\%config);

## Subroutines

sub print_formular() {
   print <<"EOF"; 
   <h3> Report erstellen </h3>
   <p>F&uuml;lle das Formular aus und best&auml;tige mit dem Button</p>
   <div id="edit-form">
   <form action="$config{'S_CREATE_REPORT'}" name="create_report" method="post" class="input_form">
   <table>
      <tr>
         <td class=\"create_td\">Kursname:</td>
         <td class=\"create_td\"><select class="flat" name="course_id">
             <option value="all" selected>ALLE</option>
EOF
   foreach (sort {$course_list{$a} cmp $course_list{$b}} keys %course_list) {
      print "             <option value=\"$_\"> $course_list{$_} </option>\n";
   }
   print <<"EOF";
         </select></td>
      </tr><tr>
         <td class=\"create_td\">Startdatum (optional):</td>
         <td class=\"create_td\"><select class="flat" name="start_date">
             <option value="none" selected></option>
EOF
   foreach (sort {$event_list{$a} cmp $event_list{$b}} keys %event_list) {
      print "             <option value=\"$event_list{$_}\"> $event_list{$_} </option>\n";
   }
   print <<"EOF";
         </select></td>
      </tr><tr>
         <td class=\"create_td\">Enddatum (optional):</td>
         <td class=\"create_td\"><select class="flat" name="end_date">
             <option value="none" selected></option>
EOF
   foreach (sort {$event_list{$a} cmp $event_list{$b}} keys %event_list) {
      print "             <option value=\"$event_list{$_}\"> $event_list{$_} </option>\n";
   }
   print <<"EOF";
         </select></td>
      </tr>
   </table>
   <input class="button" type="submit" name="submit" value="Report anzeigen">
   </form>
   </div>
EOF
}

sub get_coaching_sum($$$$$) {
   my $coach_id = shift;
   my $course_id = shift;
   my $coaching = shift;
   my $start = shift;
   my $end = shift;

   my $start_query = "";
   my $end_query = "";
   my $course_query = "";

   if ($start ne 'none') {
      $start_query = "AND $config{'T_EVENT'}.date >= \"$start\" ";
   }
   if ($end ne 'none') {
      $end_query = "AND $config{'T_EVENT'}.date <= \"$end\" ";
   }
   if ($course_id ne 'all') {
      $course_query = "AND course_id = \"$course_id\" ";
   }
   my $std_query = "SELECT COUNT($config{'T_SCHED'}.id) AS sum FROM $config{'T_SCHED'} JOIN
                    $config{'T_EVENT'} ON $config{'T_SCHED'}.event_id = $config{'T_EVENT'}.id WHERE
                    coach_id = $coach_id AND coaching = \"$coaching\" AND $config{'T_EVENT'}.omitted = 0
                   ";
   my $sth = $dbh->prepare("$std_query $course_query $start_query $end_query");
   if ($config{'debug'}) { print_debug("query: $std_query $course_query $start_query $end_query"); }
   $sth->execute();
   ## We use only the first result; there shouldn't be more than one result
   my $ref = $sth->fetchrow_hashref();
   return "$ref->{'sum'}";
}

sub print_report() {
   print "<h3>Report zum Kurs: ";
   if ($course_id eq 'all') {
      print '**ALLE**';
   } else {
      print "$course_list{$course_id}";
   }
   print "</h3>\n";
   
   print <<"EOF";
   <table class="report_table">
      <tr><th>Trainer</th>
EOF
   foreach (@{$config{'V_COACHING'}}) {
      print "         <th>$_</th>\n";
   }
   print "         <th>Link zur Abrechnung</th>\n";
   print "      </tr>\n";
   foreach my $coach_id (keys %coach_list) {
      my $skip_output = 1;
      my $output = "      <tr>\n";
      $output .= "         <td>$coach_list{$coach_id}</td>\n";
      foreach (@{$config{'V_COACHING'}}) {
         my $coaching_sum = get_coaching_sum($coach_id, $course_id, $_, $start_date, $end_date);
         if ($coaching_sum > 0) {
            $skip_output = 0;
         }
         $output .= "         <td class=\"td_content\">" .$coaching_sum ."</td>\n";
      }
      $output .= "         <td><a href=\"$config{'S_CREATE_BILL'}?coach_id=$coach_id&course_id=$course_id\">Zur Abrechnung</a></td>\n";
      $output .= "      </tr>\n";
      if ($skip_output == 0) {
         print "$output";
      }
   }

   print "   </table>\n";
}

sub untaint_input() {
   ## untaint input
   if ( defined($cgi->param('course_id')) and $cgi->param('course_id') =~ /^(?:[0-9]+|all)$/i ) {
      $course_id = $cgi->param('course_id');
   } else {
      $error .= "Kurs-ID darf nur aus Zahlen bestehen!<br>";
   }
   if ( defined($cgi->param('start_date')) and $cgi->param('start_date') =~ /^(?:\d{4}-\d{2}-\d{2}|none)$/) {
      $start_date = $cgi->param('start_date');
   } else {
      $error .= "Startdatum muss das Format JJJJ-MM-DD haben!<br>";
   }
   if ( defined($cgi->param('end_date')) and $cgi->param('end_date') =~ /^(?:\d{4}-\d{2}-\d{2}|none)$/) {
      $end_date = $cgi->param('end_date');
   } else {
      $error .= "Enddatum muss das Format JJJJ-MM-DD haben!<br>";
   }
}

## MAIN ##

## Get all course names
%course_list = get_course_list($dbh, $config{'T_COURSE'});


# Read in text
if (defined($ENV{'REQUEST_METHOD'}) and uc($ENV{'REQUEST_METHOD'}) eq "POST") {
   untaint_input();

   print_start_html($cgi, "Report");
   print_link_list($config{'S_CREATE_REPORT'});

   ## get a list of all coaches
   %coach_list = get_coach_list($dbh, $config{'T_COACH'}, 'all');

   print "<p>course: $course_id<br>start: $start_date<br>ende: $end_date</p>\n";
   print_report();
   if (defined($error)) {
      print "<p class=\"error\">$error</p>";
   }
} else {
   ## then get a list of all course dates
   %event_list = get_event_list($dbh, $config{'T_EVENT'}, "", "");

   $cgi->header('multipart/form-data');
   print_start_html($cgi, 'Report erstellen');
   print_link_list($config{'S_CREATE_REPORT'});
   print_formular();
}
print_end_html($cgi);

