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
use lib '.';
use functions;

## global variables
my $error;
my $sth;
my $course_id = '';
my @coach_types = [];
my @course_ids = [];
my $start_date = '';
my $end_date = '';
my $submit_type = '';
my (%course_list, %coach_list, %event_list);
my $cgi = CGI->new;

my %config = read_config();

# Connect to the database.
my $dbh = init_db(\%config);

## Subroutines

sub uniq {
   my %seen;
   grep !$seen{$_}++, @_;
}

sub print_formular() {
   print <<"EOF"; 
   <h3> Report erstellen </h3>
   <p>F&uuml;lle das Formular aus und best&auml;tige mit dem Button</p>
   <div id="edit-form-reporting">
   <form action="$config{'S_CREATE_REPORT'}" name="create_report" method="post" class="input_form_simple">
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
   <input type="hidden" name="type_report" value="1">
   <input class="button" type="submit" name="submit_report" value="Report anzeigen">
   </form>
   </div>
EOF

   print <<"EOF";
   <h3> Abrechnung erstellen</h3>
   <p>F&uuml;lle das Formular aus und best&auml;tige mit dem Button</p>
   <div id="edit-form-accounting">
   <form action="$config{'S_CREATE_REPORT'}" name="create_accounting" method="post" class="input_form_simple">
   <table>
EOF
   print "      <tr>\n";
   print "         <td class=\"create_td\"> </td>\n";
   print "         <td class=\"create_td\">Kursname</td>\n";
   print "         <td class=\"create_td\">Lizenz</td>\n";
   print "      </tr>\n";
   for(my $i=0; $i<$config{'V_PAYED_COACHES'}; $i++) {
      print "      <tr>\n";
      print "         <td class=\"create_td\">Trainerstelle " .($i+1) .":</td>\n";
      print "         <td class=\"create_td\"><select class=\"flat\" name=\"course_id_$i\">\n";
      foreach (sort {$course_list{$a} cmp $course_list{$b}} keys %course_list) {
         print "             <option value=\"$_\"> $course_list{$_} </option>\n";
      }
      print "         </select></td>\n";
      print "         <td class=\"create_td\"><select class=\"flat\" name=\"coach_type_$i\">\n";
      foreach (sort {$a cmp $b} keys %{$config{'V_COACH_TYPES'}}) {
         print "             <option value=\"$_\">$_</option>\n";
      }
      print "         </select></td>\n";
      print "      </tr>\n";
   }
   print <<"EOF";
      <tr>
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
   <input type="hidden" name="type_accounting" value="1">
   <input class="button" type="submit" name="submit_accounting" value="Abrechnung anzeigen">
   </form>
   </div>
EOF
}

sub get_payed_hours($$$) {
   my $course_id = shift;
   my $start = shift;
   my $end = shift;

   my $course_duration = get_course_duration($dbh, $config{'T_COURSE'}, $course_id);

   my $start_query = "";
   my $end_query = "";
   my $std_query = "SELECT COUNT(id) AS sum FROM $config{'T_EVENT'} WHERE
                    course_id = $course_id AND omitted = 0
                   ";
   if ($start ne 'none') {
      $start_query = "AND date >= \"$start\" ";
   }
   if ($end ne 'none') {
      $end_query = "AND date <= \"$end\" ";
   }

   my $sth = $dbh->prepare("$std_query $start_query $end_query");
   if ($config{'debug'}) { print_debug("query: $std_query $start_query $end_query"); }
   $sth->execute();
   ## We use only the first result; there shouldn't be more than one result
   my $ref = $sth->fetchrow_hashref();

   # return payed hours
   return ($ref->{'sum'} * $course_duration);
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
   foreach my $coach_id (sort{$coach_list{$a} cmp $coach_list{$b}} keys %coach_list) {
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
      if ($course_id eq 'all') {
         $output .= "         <td>Abrechnung nicht m&ouml;glich</a></td>\n";
      } else {
         $output .= "         <td><a href=\"$config{'S_CREATE_BILL'}?coach_id=$coach_id&course_id=$course_id\">Zur Abrechnung</a></td>\n";
      }
      $output .= "      </tr>\n";
      if ($skip_output == 0) {
         print "$output";
      }
   }

   print "   </table>\n";
}

# Abrechnung:
# Voraussetzung: 3 Trainerstellen = 2*A + 1*P
# A soll besser bewertet sein als P: 3 = 2*1,15*A + 1*0,7*P
# Damit die Gewichtung nicht vom tatsächlichen Verhältnis der geleisteten
# Stunden abhängt, muss sich die Gewichtung am Ende herauskürzen:
#   Gewichteter Stundenlohn = h_lohn = Ges_Summe/(1,15*A_ges + 0,7*P_ges)
# Bezahlung eines Trainers x:
#   Bezahlung_x = h_lohn * 1,15 * A_x + h_lohn * 0,7 * P_x
# Bezahlung aller Trainer:
#   Bezahlung = h_lohn * Summe(1,15*A_i + 0,7*P_i)
#                       [i=1..x]
#             = Ges_Summe/(1,15*A_ges + 0,7*P_ges) * (1,15*Summe(A_i) + 0,7*Summe(P_i))
#             = Ges_Summe/(1,15*A_ges + 0,7*P_ges) * (1,15*A_ges + 0,7*P_ges)
#             = Ges_Summe
#
sub print_accounting() {
   my %sum_coaching_hours;  # hours worked per coaching in this time slot.
   my $sum_payment = 0;
   my $pay_per_hour = 0;
   my %coach_working_hours;

   ## calculate overall working hours.
   ## calculate working hours per coach per coaching (A, P, ..)
   foreach my $coach_id (sort{$coach_list{$a} cmp $coach_list{$b}} keys %coach_list) {
      foreach (@{$config{'V_COACHING'}}) {
         # calculate hours only for coaching time which will be payed for
         if ( $config{'V_BILL_FACTOR'}{$_} > 0 ) {
            my $coaching_sum = 0;
            foreach my $course_id (uniq(@course_ids)) {
               # Get course duration
               my $course_duration   = get_course_duration($dbh, $config{'T_COURSE'}, $course_id);
               my $events_per_course = get_coaching_sum($coach_id, $course_id, $_, $start_date, $end_date);
               $coaching_sum = $coaching_sum + $events_per_course * $course_duration;
            }
            $sum_coaching_hours{$_} = $sum_coaching_hours{$_} + $coaching_sum;
            $coach_working_hours{$coach_id}{$_} = $coaching_sum;
         }
      }
   }

   print "<h3>Abrechnung</h3>\n";
   print "   <table class=\"report_table\">\n";
   print "      <tr>\n";
   print "         <th>Kurs</th>\n";
   print "         <th>bezahlte Stunden</th>\n";
   print "         <th>EUR/Std</th>\n";
   print "         <th>Summe</th>\n";
   print "      </tr>\n";
   ## get payed hours and calculate payment per course
   for (my $i=0; $i<$config{'V_PAYED_COACHES'}; $i++) {
      my $payed_hours = get_payed_hours($course_ids[$i], $start_date, $end_date);
      print "      <tr>\n";
      print "        <td class=\"td_content\">$course_ids[$i]</td>\n";
      print "        <td class=\"td_content\">$payed_hours</td>\n";
      print "        <td class=\"td_content\">$config{'V_COACH_TYPES'}{$coach_types[$i]}</td>\n";
      printf "        <td class=\"td_content\">%.2f EUR</td>\n", ($payed_hours * $config{'V_COACH_TYPES'}{$coach_types[$i]});
      print "      </tr>\n";
      $sum_payment += $payed_hours * $config{'V_COACH_TYPES'}{$coach_types[$i]};
   }
   printf "      <tr><td colspan=3></td><td class=\"td_content\"><b>%.2f EUR</b></td></tr>\n", $sum_payment;
   print "</table>\n";

   ## calculate average payment per hour.
   my $weighted_sum_coaching_hours = 0;
   my $straight_sum_coaching_hours = 0;
   foreach (keys %sum_coaching_hours) {
      $weighted_sum_coaching_hours += $config{'V_BILL_FACTOR'}{$_} * $sum_coaching_hours{$_};
      $straight_sum_coaching_hours += $sum_coaching_hours{$_};
   }
   $pay_per_hour = $sum_payment/$weighted_sum_coaching_hours;
   printf "<p>Summe geleisteter Stunden: <b>%.1f Std</b></p>\n", $straight_sum_coaching_hours;
   printf "<p>Summe geleisteter Stunden (gewichtet): <b>%.1f Std</b></p>\n", $weighted_sum_coaching_hours;
   printf "<p>Geld pro Stunde (gewichtet): <b>%.2f EUR/Std</b></p>", $pay_per_hour;

   print '   <table class="report_table">' ."\n";
   print '      <tr><th>Trainer</th>' ."\n";

   # show only coaching times which will be payed for
   foreach (@{$config{'V_COACHING'}}) {
      if ( $config{'V_BILL_FACTOR'}{$_} > 0 ) {
         print "         <th>$_</th>\n";
         print "         <th>$_ * $config{'V_BILL_FACTOR'}{$_}</th>\n";
      }
   }
   print "         <th>Geld</th>\n";
   print "      </tr>\n";
   foreach my $coach_id (sort{$coach_list{$a} cmp $coach_list{$b}} keys %coach_list) {
      my $payment = 0;
      my $skip_output = 1;
      my $output = "      <tr>\n";
      $output   .= "         <td>$coach_list{$coach_id}</td>\n";
      foreach (@{$config{'V_COACHING'}}) {
         # show hours only for coaching time which will be payed for
         if ( $config{'V_BILL_FACTOR'}{$_} > 0 ) {
            if ($coach_working_hours{$coach_id}{$_} > 0) {
               $skip_output = 0;
            }
            $output .= "         <td class=\"td_content\">" .$coach_working_hours{$coach_id}{$_} ."</td>\n";
            $output .= "         <td class=\"td_content\">" .$coach_working_hours{$coach_id}{$_} * $config{'V_BILL_FACTOR'}{$_} ."</td>\n";
            $payment += $coach_working_hours{$coach_id}{$_} * $config{'V_BILL_FACTOR'}{$_} * $pay_per_hour;
         }
      }
      $output .= sprintf("         <td class=\"td_content\">%.2f</td>\n", $payment);
      $output .= "      </tr>\n";
      if ($skip_output == 0) {
         print "$output";
      }
   }
}

sub untaint_input() {
   ## untaint input
   if ( defined($cgi->param('type_report')) and $cgi->param('type_report') eq '1' ) {
      $submit_type = 'report';
      if ( defined($cgi->param('course_id')) and $cgi->param('course_id') =~ /^(?:[0-9]+|all)$/i ) {
         $course_id = $cgi->param('course_id');
      } else {
         $error .= "Kurs-ID darf nur aus Zahlen bestehen!<br>";
      }
   } elsif ( defined($cgi->param('type_accounting')) and $cgi->param('type_accounting') eq '1' ) {
      $submit_type = 'accounting';
      for (my $i=0; $i<$config{'V_PAYED_COACHES'}; $i++) {
         if ( defined($cgi->param("course_id_$i")) and $cgi->param("course_id_$i") =~ /^(?:[0-9]+)$/ ) {
            if ( defined($cgi->param("coach_type_$i")) and $cgi->param("coach_type_$i") =~ /^(?:[ABCD])$/ ) {
               $course_ids[$i] = $cgi->param("course_id_$i");
               $coach_types[$i] = $cgi->param("coach_type_$i");
            } else {
               $error .= "Trainertyp (Nr. $i) muss A, B, C oder D sein!<br>";
            }
         } else {
            $error .= "Kurs-ID (Nr. $i) darf nur aus Zahlen bestehen!<br>";
         }
      }
   } else {
      $error .= "Unbekannter Type!<br>";
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

   if ($submit_type eq 'report') {
      if ($config{'debug'}) {
         print "<p>course: $course_id<br>start: $start_date<br>ende: $end_date</p>\n";
      }
      print_report();
   } elsif ($submit_type eq 'accounting') {
      if ($config{'debug'}) {
         print "<p>\n";
         foreach (@course_ids) {
            print "course: $_<br>\n";
         }
         print "start: $start_date<br>ende: $end_date</p>\n";
      }
      print_accounting();
   } else {
      print "<p class=\"error\">Unknown submit type!</p>\n";
   }
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

