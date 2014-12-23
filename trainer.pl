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
use POSIX qw(strftime);
use lib '.';
use functions;

## globale Variablen
my $error;
my @month2name = qw( Januar Februar M&auml;rz April Mai Juni Juli August September Oktober November Dezember );
my $cur_month;
my $cur_year;
my @checked = ("", "checked");
my $cgi = CGI->new();
my %new_event_states = ();
my %new_participants = ();

my %config = read_config();

## These are available via url_param() method. 
$cur_month = strftime "%m", localtime unless (defined $cur_month);
$cur_year  = strftime "%Y", localtime unless (defined $cur_year);

# Connect to the database.
my $dbh = init_db(\%config);


sub print_formular($$) {
   my $cur_month = shift;
   my $cur_year = shift;

   my %event_list = get_event_list($dbh, $config{'T_EVENT'}, $cur_month, $cur_year);
   my %coach_list = get_coach_list($dbh, $config{'T_COACH'});

   ## table width: 2*events + 1 column of names
   my $colspan = 2*keys(%event_list) + 2;
   print << "EOF";
<form name="edit_schedule" method="post">
<table cellpadding=5>
   <tr> 
      <td colspan=$colspan><h3>$month2name[$cur_month - 1] $cur_year</h3></td> 
   </tr>
   <tr>
      <td>&nbsp;</td>
EOF
   my $this_month = strftime("%m", localtime);
   my $this_year  = strftime("%Y", localtime);
   my $today      = strftime("%d", localtime);
   my $marked = 0;
   foreach my $event_id (sort{$event_list{$a} cmp $event_list{$b}} keys %event_list) {
      if ( $cur_year == $this_year && $cur_month == $this_month &&
           substr($event_list{$event_id}, 8) >= $today && $marked == 0) {
         print "      <td class=\"td_caption_next\" colspan=\"2\"> " .substr($event_list{$event_id}, 8) ."</td>\n";
         $marked = 1;
      } else {
         print "      <td class=\"td_caption\" colspan=\"2\"> " .substr($event_list{$event_id}, 8) ."</td>\n";
   }
   }
   print "   </tr>\n";

   foreach my $coach_id (sort{$coach_list{$a} cmp $coach_list{$b}} keys %coach_list) {
      print "   <tr>\n";
      print "      <td class=\"td_caption\">$coach_list{$coach_id}</td>\n";
      foreach my $event_id (sort{$event_list{$a} cmp $event_list{$b}} keys %event_list) {
         my $schedule = get_schedule($dbh, $config{'T_SCHED'}, $config{'T_EVENT'}, $coach_id, $event_list{$event_id});
         my $state = get_state($dbh, $config{'T_EVENT'}, $event_id);
         if ($state == 1) {
            print "      <td class=\"td_omitted_1\" colspan=\"2\">f&auml;llt aus\n";
         } else {
            print "      <td class=\"td_${schedule}_left\">$schedule</td><td class=\"td_${schedule}_right\"> <select class=\"flat\" name=\"Sched:${coach_id}:${event_id}\">\n";
            foreach ('', @{$config{'V_COACHING'}}) {
               if ( $schedule eq $_ ) {
                  print "             <option value=\"$_\" selected> $_ </option>\n";
               } else {
                  print "             <option value=\"$_\"> $_ </option>\n";
               }
            }
            print '          </select>' ."\n";
         }
         print "      </td>" ."\n";
      }
      print "   </tr>\n";
   }
   print "   <tr>\n";
   print "      <td class=\"td_caption_separator\">Teilnehmer</td>\n";
   ## List must be sorted by date, otherwise the columns do not match
   foreach my $event_id (sort{$event_list{$a} cmp $event_list{$b}} keys %event_list) {
      my $participants = get_participants($dbh, $config{'T_EVENT'}, $event_id);
      my $state = get_state($dbh, $config{'T_EVENT'}, $event_id);
      if ($state == 1) {
         print "      <td class=\"td_separator_1\" colspan=\"2\"></td>\n";
      } else {
         print "      <td class=\"td_separator_0\" colspan=\"2\"><input class=\"input_table\" type=\"text\" name=\"Participants:$event_id\" value=\"$participants\"></td>\n";
      }
   }
   print "   </tr><tr>\n";
   print "      <td class=\"td_caption\">F&auml;llt aus</td>\n";
   ## List must be sorted by date, otherwise the columns do not match
   foreach my $event_id (sort{$event_list{$a} cmp $event_list{$b}} keys %event_list) {
      my $state = get_state($dbh, $config{'T_EVENT'}, $event_id);
      print "      <td class=\"td_omitted_${state}\" colspan=\"2\"><input type=\"checkbox\" name=\"Omitted:$event_id\" $checked[$state]></td>\n";
   }
   print "   </tr>\n";
   ## Mache dies mit Date::Manip
   ## Beachte auch das Jahr.
   my $prev_month = $cur_month - 1;
   my $prev_year = $cur_year;
   my $next_month = $cur_month + 1;
   my $next_year = $cur_year;
   if ($prev_month == 0) { 
      $prev_month = 12;
      $prev_year = $cur_year - 1;
   }
   if ($next_month == 13) {
      $next_month = 1;
      $next_year = $cur_year + 1;
   }
   print << "EOF";
</table>
<table class="nav_table">
   <tr>
      <td class="nav_td"><a href=$config{'S_MAIN'}?month=$prev_month&year=$prev_year>Vorheriger Monat</a></td>
      <td class="nav_td"><input class="button" type="submit" name="submit" value="&Uuml;bernehmen"></td>
      <td class="nav_td"><a href=$config{'S_MAIN'}?month=$next_month&year=$next_year>N&auml;chster Monat</a></td>
   </tr>
</table>
</form>
EOF
}

### MAIN ###
if (defined($ENV{'REQUEST_METHOD'}) and uc($ENV{'REQUEST_METHOD'}) eq "POST") {
   $cgi->header('multipart/form-data');
   print_start_html($cgi, "Traineranwesenheit");
   print_link_list($config{'S_MAIN'});
 
   if ($config{'debug'}) { print_debug("POST: " . $cgi->param('submit')); };

   ## get the session cookie
   my $query = CGI->new;
   my $sessionID = $query->cookie('sessionID');

   ## check if the session cookie is valid
   if ( defined($sessionID) and $sessionID eq 'trainer' ) {

      ## check if submit botton was pressed
      if ( $cgi->param('submit') and (! defined($error)) ) {
         ## get and untaint current month and year
         if ( defined($cgi->url_param('month')) and $cgi->url_param('month') =~ /^\d{1,2}$/ ) {
            $cur_month = $cgi->url_param('month');
         }
         if ( defined($cgi->url_param('year')) and $cgi->url_param('year') =~ /^\d{4}$/ ) {
            $cur_year = $cgi->url_param('year');
         }
   
         ## get a list of all params
         my @all_params = $cgi->param;
   
         foreach my $param (@all_params) {
            ## process only the flat list parameters
            if ( $param =~ /Sched:\d+:\d+/ ) {
               my ($sched, $coach_id, $event_id) = split(':', $param);
               ## get current schedule
               my $sth = $dbh->prepare("SELECT coaching FROM $config{'T_SCHED'}
                                        WHERE coach_id = \"$coach_id\" AND event_id = \"$event_id\"
                                       ");
               $sth->execute();
               if ( $sth->rows > 1) { $error .= "Select failed: result >1; ignoring rest<br>\n"; }
               my $ref = $sth->fetchrow_hashref();
               if ($config{'debug'}) { 
                  if (defined($ref->{'coaching'})) {
                     print_debug("coach_id=$coach_id, event_id=$event_id : db(coaching): " 
                        .$ref->{'coaching'} ." cgi(coaching): " .$cgi->param($param)); 
                  } else {
                     print_debug("coach_id=$coach_id, event_id=$event_id : no coaching defined!");
                  }
               }
               ## compare results
               if ( ! $ref->{'coaching'} and ! $cgi->param($param) ) {
                  ## nothing to do
               } elsif ( $ref->{'coaching'} and $ref->{'coaching'} eq $cgi->param($param) ) {
                  ## nothing to do
               } elsif ( ! $ref->{'coaching'} and $cgi->param($param) ) {
                  ## There is no event, insert one:
                  eval { $dbh->do("INSERT INTO $config{'T_SCHED'} ( coach_id, event_id, coaching )
                                   VALUES (\"$coach_id\", \"$event_id\", \"" .$cgi->param($param) ."\")
                                  ")
                       };
                  $error .= "Insert failed: $@<br>\n" if $@;
                  if ($config{'debug'}) {
                     print_debug("INSERT INTO $config{'T_SCHED'} ( coach_id, event_id, coaching ) "
                                ."VALUES (\"$coach_id\", \"$event_id\", \"" .$cgi->param($param) ."\")");
                  }
               } elsif ( $ref->{'coaching'} and $cgi->param($param) eq '' ) {
                  ## There is an event: Delete it:
                  eval { $dbh->do("DELETE FROM $config{'T_SCHED'}
                                   WHERE coach_id = $coach_id AND event_id = $event_id
                                  ");
                       };
                  $error .= "Delete failed: $@<br>\n" if $@;
                  if ($config{'debug'}) {
                     print_debug("DELETE FROM $config{'T_SCHED'} WHERE coach_id = $coach_id AND event_id = $event_id");
                  }
               } elsif ( $ref->{'coaching'} and $ref->{'coaching'} ne $cgi->param($param) ) {
                  ## There is already a different event: Update it:
                  eval { $dbh->do("UPDATE $config{'T_SCHED'} SET coaching = \"" .$cgi->param($param) ."\"
                                   WHERE coach_id = \"$coach_id\" AND event_id = \"$event_id\"
                                  ");
                       };
                  $error .= "Update failed: $@<br>\n" if $@;
                  if ($config{'debug'}) {
                     print_debug("UPDATE $config{'T_SCHED'} SET coaching = \"" .$cgi->param($param) ."\""
                       ."WHERE coach_id = \"$coach_id\" AND event_id = \"$event_id\"");
                  }
               } else {
                  $error .= "ERROR: coach_id=$coach_id, event_id=$event_id : Unused case!!<br>\n";
               }
            }
   
            ## process omitted events
            ## only active elements will show up in the params list
            if ( $param =~ /Omitted:\d+/ ) {
               my ($sched, $event_id) = split(':', $param);
               ## store new event state in global variable for later processing
               $new_event_states{$event_id} = 1;
            }
   
            ## process participants at an event
            if ( $param =~ /Participants:\d+/ ) {
               my ($sched, $event_id) = split(':', $param);
               ## store new participants number in global variable for later processing
               $new_participants{$event_id} = $cgi->param($param);
            }
         }
         ## process omitted events and participants
         ## get a list of all events in the current month
         my %event_states = get_event_state($dbh, $config{'T_EVENT'}, $cur_month, $cur_year);
         foreach my $e_id (keys %event_states) {
            if ( $event_states{$e_id} == 0 && defined($new_event_states{$e_id}) ) {
               eval { $dbh->do("UPDATE $config{'T_EVENT'} SET omitted = 1 WHERE id = \"$e_id\" "); };
               $error .= "Update failed: $@<br>\n" if $@;
               if ($config{'debug'}) {
                  print_debug("update event $e_id: not omitted -> omitted");
                  print_debug("UPDATE $config{'T_EVENT'} SET omitted = 1 WHERE id = \"$e_id\" ");
               }
            } elsif ( $event_states{$e_id} == 1 && ! defined($new_event_states{$e_id}) ) {
               eval { $dbh->do("UPDATE $config{'T_EVENT'} SET omitted = 0 WHERE id = \"$e_id\" "); };
               $error .= "Update failed: $@<br>\n" if $@;
               if ($config{'debug'}) {
                  print_debug("update event $e_id: omitted -> not omitted");
                  print_debug("UPDATE $config{'T_EVENT'} SET omitted = 0 WHERE id = \"$e_id\" ");
               }
            }
            if ( defined($new_participants{$e_id}) and $new_participants{$e_id} =~ /^\d+$/ ) {
               eval { $dbh->do("UPDATE $config{'T_EVENT'} SET participants = \"$new_participants{$e_id}\" WHERE id = \"$e_id\" "); };
               $error .= "Update failed: $@<br>\n" if $@;
               if ($config{'debug'}) {
                  print_debug("UPDATE $config{'T_EVENT'} SET participants = $new_participants{$e_id} WHERE id = \"$e_id\" ");
               }
            }
         }
      }
   } else {
      ## coookie is invalied: force a page reload and print a warning
      # ??? 
      $error = "Session abgelaufen! Seite wurde neugeladen ... ";
   }

   print_formular($cur_month, $cur_year);
   print "<p class=\"error\"> $error </p>\n" if $error;

} else {  ## GET
   if ( defined($cgi->param('month')) and $cgi->param('month') =~ /^(?:[0-9]|1[0-2])$/ ) {
      $cur_month = $cgi->param('month');
   } else {
      $error .= "Monat darf nur aus Zahlen bestehen!<br>";
   }
   if ( defined($cgi->param('year')) and $cgi->param('year') =~ /^[0-9]{4}$/ ) {
      $cur_year = $cgi->param('year');
   } else {
      $error .= "Jahr darf nur aus Zahlen bestehen!<br>";
   }
				     
   $cgi->header('multipart/form-data');
   print_start_html($cgi, "Traineranwesenheit");
   print_link_list($config{'S_MAIN'});
   print_formular($cur_month, $cur_year);
   if($config{'debug'}) { print_debug("GET"); };

}
print_end_html($cgi);

# Disconnect from the database.
close_db($dbh);

# INSERT some data into 'foo'. We are using $dbh->quote() for
# quoting the name.
#$dbh->do("INSERT INTO foo VALUES (1, " . $dbh->quote("Tim") . ")");

# Same thing, but using placeholders
#$dbh->do("INSERT INTO foo VALUES (?, ?)", undef, 2, "Jochen");

# Now retrieve data from the table.
#my $sth = $dbh->prepare("SELECT * FROM foo");
#$sth->execute();
#while (my $ref = $sth->fetchrow_hashref()) {
#   print "Found a row: id = $ref->{'id'}, name = $ref->{'name'}\n";
#}
#$sth->finish();

