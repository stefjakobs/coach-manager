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

package functions;

use strict;
use warnings;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
use CGI ':standard';

$VERSION = '0.3';
@ISA     = qw(Exporter);
@EXPORT  = qw( init_db close_db read_config
               get_table_list get_courses get_schedule get_state get_participants
               get_coach_list get_event_list get_event_state get_course_list 
               get_coach_name
               print_start_html print_end_html print_link_list
               print_formular_edit_coach
               print_debug
             );
@EXPORT_OK = qw(init_db close_db read_config
                get_table_list get_courses get_schedule get_state get_participants
                get_coach_list get_event_list get_event_state get_course_list
                get_coach_name
                print_start_html print_end_html print_link_list
                print_formular_edit_coach
                print_debug
               );
%EXPORT_TAGS = ( DEFAULT => [qw(&get_table_list &get_courses),],
                 HTML    => [qw(&print_start_html &print_end_html &print_link_list)],
               );

my $configfile = "./config.cf";

### read configuration file and make its parameters accessable via hash, e.g.:
### %config = read_config(); print $config{'T_COACH'}
### Returns the config file hash
sub read_config() {
# check and read config file
   my %config;
   if ( -r $configfile ) {
      %config = do $configfile;
   } else {
      die("can not read $configfile");
   }
   return %config
}

### open a connection to the database
### requires a reference to the configfile hash a parameter
### if set in the config file, the database will be initial filled
### with the needed tables.
### Returns the database handle
sub init_db($) {
   my %config = %{shift()};

   # Connect to the database.
   my $dbh = DBI->connect("DBI:mysql:database=$config{'DATABASE'};host=$config{'HOST'}",
                          "$config{'USER'}", "$config{'PASSWD'}",
                         {'RaiseError' => 1, mysql_enable_utf8 => 1});

   if ($config{'setup'} == 1) {
      # Create needed tables if they do not exist.
      # This must not fail, thus we don't catch errors.
      # password: TODO: use SHA2: INSERT INTO t_coach values ('max', SHA2('secret', 512));
      $dbh->do("CREATE TABLE IF NOT EXISTS 
                   $config{'T_COACH'} (id         INT NOT NULL AUTO_INCREMENT PRIMARY KEY, 
                                       lastname   VARBINARY(64) NOT NULL,
                                       firstname  VARBINARY(64) NOT NULL,
                                       birthday   DATE,
                                       email      VARBINARY(256),
                                       telephone  VARCHAR(20),
                                       password   VARCHAR(64),
                                       priviledge TINYINT NOT NULL DEFAULT 0,
                                       license    ENUM('A', 'B', 'C', 'D'),
                                       active     BOOLEAN NOT NULL DEFAULT TRUE )"
              );
   
      $dbh->do("CREATE TABLE IF NOT EXISTS 
                   $config{'T_COURSE'} (id        INT NOT NULL AUTO_INCREMENT PRIMARY KEY, 
                                        name      VARCHAR(64) NOT NULL UNIQUE KEY,
                                        startdate DATE NOT NULL,
                                        enddate   DATE NOT NULL,
                                        starttime TIME NOT NULL,
                                        endtime   TIME NOT NULL )"
              );
      
      $dbh->do("CREATE TABLE IF NOT EXISTS 
                    $config{'T_EVENT'} (id           INT NOT NULL AUTO_INCREMENT PRIMARY KEY, 
                                        date         DATE NOT NULL,
                                        course_id    INT NOT NULL,
                                        omitted      BOOLEAN NOT NULL DEFAULT FALSE,
                                        participants TINYINT DEFAULT NULL,
                                        FOREIGN KEY (course_id) REFERENCES $config{'T_COURSE'}(id)
                                        ON UPDATE CASCADE ON DELETE CASCADE )"
              );
      
      $dbh->do("CREATE TABLE IF NOT EXISTS 
                    $config{'T_SCHED'} (id        INT NOT NULL AUTO_INCREMENT PRIMARY KEY, 
                                        coach_id  INT NOT NULL,
                                        event_id  INT NOT NULL,
                                        coaching  ENUM('A', 'B', 'C', 'F', 'P', 'X', '-') NOT NULL,
                                        UNIQUE KEY `coach_event` (coach_id, event_id),
                                        FOREIGN KEY (coach_id) REFERENCES $config{'T_COACH'}(id)
                                        ON DELETE CASCADE,
                                        FOREIGN KEY (event_id) REFERENCES $config{'T_EVENT'}(id)
                                        ON DELETE CASCADE )"
              );

      $dbh->do("CREATE TABLE IF NOT EXISTS 
                    $config{'T_CONFIG'} (id       INT NOT NULL AUTO_INCREMENT PRIMARY KEY, 
                                         string   VARCHAR(64) NOT NULL UNIQUE KEY,
                                         value    VARBINARY(64) NOT NULL )"
              );
      my $sth = $dbh->prepare("SELECT value FROM $config{'T_CONFIG'} WHERE string = 'version'");
      $sth->execute();
      my $ref = $sth->fetchrow_hashref();
      if (! defined($ref->{'value'})) {
         $dbh->do("INSERT INTO $config{'T_CONFIG'} (string, value) VALUES ('version', '1')");
      }
   }
   return $dbh;
}

### close the connection to the database
### Requires the database handle as parameter
sub close_db($) {
   my $dbh = shift; 
   $dbh->disconnect();
}

### print a debug message formated as HTML
### Requires the message as parameter
sub print_debug($) {
   my $debug_msg = shift;

   print "<p>" .$debug_msg ."</p>\n";
}

### print a list of all items in a table
### Requires the database handle and the table name as parameters
### returns a hash with the names as keys and an other hash as values
sub get_table_list($$) {
   my $dbh = shift;
   my $table = shift;

   my %hash_list;
   my $sth = $dbh->prepare("SELECT * FROM $table ORDER BY id");
   $sth->execute();
   my $names = $sth->{'NAME'};
   my $numFields = $sth->{'NUM_OF_FIELDS'};
   while (my $ref = $sth->fetchrow_hashref()) {
      for (my $i = 0;  $i < $numFields;  $i++) {
         $hash_list{"$ref->{'id'}"}{$$names[$i]} = $ref->{$$names[$i]}; #$$ref[$i];
      }
   }
   $sth->finish();
   return %hash_list;
}

### get a list of all events or the events in a specific month
### Requires the database handle, the event table name and
###   optionally the month and year (this might be emtpy)
### Returns a hash with the ids as keys and the dates as values
sub get_event_list($$$$) {
   # get only events in a specific month and year or
   # get all events
   my $dbh = shift;
   my $t_event = shift;
   my $cur_month = shift;
   my $cur_year  = shift;
   
   my $sth;
   my %event_list;
   if (! $cur_month or ! $cur_year) {
      $sth = $dbh->prepare("SELECT id, date FROM $t_event ORDER BY DATE");
   } else {
      $sth = $dbh->prepare("SELECT id, date FROM $t_event WHERE MONTH(date) = $cur_month
                               AND YEAR(date) = $cur_year ORDER BY date
                              ");
   }
   $sth->execute();
   while (my $ref = $sth->fetchrow_hashref()) {
      $event_list{"$ref->{'id'}"} = $ref->{'date'};
   }
   $sth->finish();
   return %event_list;
}

### get the state (obmitted or not) of the events in a specific month
### Requires: the database handle, event table name, month, year
### Returns: hash with the ids as keys and omitted state as values
sub get_event_state($$$$) {
   my $dbh = shift;
   my $t_event = shift;
   my $cur_month = shift;
   my $cur_year  = shift;

   my %event_list;
   my $sth = $dbh->prepare("SELECT id, omitted FROM $t_event WHERE MONTH(date) = $cur_month
                            AND YEAR(date) = $cur_year ORDER BY date
                           ");
   $sth->execute();
   while (my $ref = $sth->fetchrow_hashref()) {
      $event_list{"$ref->{'id'}"} = $ref->{'omitted'};
   }
   $sth->finish();
   return %event_list;
}

### get a list of all coaches
### Requires: database handle, coach table name
### Returns: a hash with the ids as keys and the firstname lastname as values
sub get_coach_list($$) {
   my $dbh = shift;
   my $t_coach = shift;

   # create a array of coaches
   my %coaches;
   my $sth = $dbh->prepare("SELECT id, firstname, lastname FROM $t_coach 
                            WHERE active = true ORDER BY id");
   $sth->execute();
   while (my $ref = $sth->fetchrow_hashref()) {
      $coaches{$ref->{'id'}} = "$ref->{'firstname'} $ref->{'lastname'}";
   }
   return %coaches;
}

### get a list of all courses
### Requires: database handle, course table name
### Returns: a hash with the ids as keys and the course names as values
sub get_course_list($$) {
   my $dbh = shift;
   my $t_course = shift;

   my %courses;
   my $sth = $dbh->prepare("SELECT id, name FROM $t_course ORDER BY name");
   $sth->execute();
   while (my $ref = $sth->fetchrow_hashref()) {
      $courses{$ref->{'id'}} = "$ref->{'name'}";
   }
   return %courses;
}

### get the first and last name of a coach
### Requires: database handle, coach table name, coach id
### Returns: Array with the firstname in element 0; lastname in element 1
###   and licese in element 2
sub get_coach_name($$$) {
   my $dbh = shift;
   my $t_coach = shift;
   my $coach_id = shift;

   my $sth = $dbh->prepare("SELECT firstname, lastname, license FROM $t_coach 
                            WHERE id = \"$coach_id\"
                           ");
   $sth->execute();
   my $ref = $sth->fetchrow_hashref();
   my %coach;
   $coach{'first_name'} = $ref->{'firstname'};
   $coach{'last_name'}  = $ref->{'lastname'};
   $coach{'license'}    = $ref->{'license'};

   $sth->finish();
   return %coach;
}

### get the schedule state of a coache on a specific date
### Requires: database handle, schedule table name, event table name
###   coach id, date
### Returns: the schedule state
sub get_schedule($$$$$) {
   my $dbh = shift;
   my $t_sched = shift;
   my $t_event = shift;
   my $coach_id = shift;
   my $date = shift;
   
   my $schedule;
   my $sth = $dbh->prepare("SELECT coaching FROM $t_sched
                            JOIN $t_event ON ${t_sched}.event_id = ${t_event}.id
                            WHERE coach_id = \"$coach_id\" AND date = \"$date\"
                           ");
   
   $sth->execute();
   my $numRows = $sth->rows;
   my $ref = $sth->fetchrow_hashref();
   $schedule = $ref->{'coaching'} ? $ref->{'coaching'} : '';
   
   $sth->finish();
   return $schedule;
}  


### get the omitted state from a specific event
### Requires: database handle, event table name, event id
### Returns: omitted state of that event
sub get_state($$$) {
   my $dbh = shift;
   my $t_event = shift;
   my $id = shift;

   my $state;
   my $sth = $dbh->prepare("SELECT omitted FROM $t_event WHERE id = \"$id\"");

   $sth->execute();
   my $ref = $sth->fetchrow_hashref();
   $state = $ref->{'omitted'};

   $sth->finish();
   return $state;
}

### get the number of participants at an specific event
### Requires: database handle, event table name, event id
### Returns: the number of participants at that event
sub get_participants($$$) {
   my $dbh = shift;
   my $t_event = shift;
   my $id = shift;

   my $state;
   my $sth = $dbh->prepare("SELECT participants FROM $t_event WHERE id = \"$id\"");

   $sth->execute();
   my $ref = $sth->fetchrow_hashref();
   $state = $ref->{'participants'} // '';

   $sth->finish();
   return $state;
}

### DO THE HTML STUFF ###

### print the HTML header of a site
sub print_start_html {
   my $cgi = shift;
   my $title = shift;
   my $style = shift;
   if ( ! defined($style)) { $style = 'style.css'; }

   my $cookie = cookie( -name    =>'sessionID',
                        -value   =>'trainer',
                        -expires =>'+10m',
                        -path    =>'/',
                      );
   print $cgi->header(-cookie => $cookie);
   print $cgi->start_html(
           -title    => "$title",
           -author   => 'stefan@localside.net',
           -meta     => {'keywords'=>'create Coach', 'copyright'=>'copyright Stefan Jakobs (2013)'},
           -style    => {'src'=>$style},
           -encoding => 'UTF-8',
           #-BGCOLOR  => 'lightyellow',
   );
}

### print the footer and close the HTML site
sub print_end_html($) {
   my $cgi = shift;
   print '<table class="footer_table">' . "\n";
   print '   <tr>' ."\n";
   print "      <td class=\"footer_td\">Version: $VERSION</td>" ."\n";
   print "      <td class=\"footer_td\"> </td>" ."\n";
   print "      <td class=\"footer_td\">Copyright: Stefan Jakobs</td>" ."\n";
   print '   </tr>' ."\n";
   print '</table>' ."\n";
   print $cgi->end_html();
}

### print the link list at the top a page
sub print_link_list($) {
   my %config = read_config();
   my $active = shift;
   print '<table class="header_table">' ."\n";
   print '   <tr>' ."\n";
   if ($active eq $config{'S_MAIN'}) {
      print "      <td class=\"header_td_active\"><a href=\"$config{'S_MAIN'}\">&Uuml;bersicht</a></td>" ."\n";
   } else {
      print "      <td class=\"header_td\"><a href=\"$config{'S_MAIN'}\">&Uuml;bersicht</a></td>" ."\n";
   }
   if ($active eq $config{'S_LIST_COACH'}) {
      print "      <td class=\"header_td_active\"><a href=\"$config{'S_LIST_COACH'}\">Trainer anzeigen</a></td>" ."\n";
   } else {
      print "      <td class=\"header_td\"><a href=\"$config{'S_LIST_COACH'}\">Trainer anzeigen</a></td>" ."\n";
   }
   if ($active eq $config{'S_CREATE_COACH'}) { 
      print "      <td class=\"header_td_active\"><a href=\"$config{'S_CREATE_COACH'}\">Trainer anlegen</a></td>" ."\n";
   } else {
      print "      <td class=\"header_td\"><a href=\"$config{'S_CREATE_COACH'}\">Trainer anlegen</a></td>" ."\n";
   }
   if ($active eq $config{'S_LIST_COURSE'}) {
      print "      <td class=\"header_td_active\"><a href=\"$config{'S_LIST_COURSE'}\">Kurse anzeigen</a></td>" ."\n";
   } else {
      print "      <td class=\"header_td\"><a href=\"$config{'S_LIST_COURSE'}\">Kurse anzeigen</a></td>" ."\n";
   }
   if ($active eq $config{'S_CREATE_COURSE'}) {
      print "      <td class=\"header_td_active\"><a href=\"$config{'S_CREATE_COURSE'}\">Kurse anlegen</a></td>" ."\n";
   } else {
      print "      <td class=\"header_td\"><a href=\"$config{'S_CREATE_COURSE'}\">Kurse anlegen</a></td>" ."\n";
   }
   if ($active eq $config{'S_CREATE_REPORT'}) {
      print "      <td class=\"header_td_active\"><a href=\"$config{'S_CREATE_REPORT'}\">Report erstellen</a></td>" ."\n";
   } else {
      print "      <td class=\"header_td\"><a href=\"$config{'S_CREATE_REPORT'}\">Report erstellen</a></td>" ."\n";
   }
   print '   </tr>' ."\n";
   print '</table>' ."\n";
   print '<table class="header_table_low">' ."\n";
   print '   <tr>' ."\n";
   print "         <td class=\"small_td_l\"><a href=\"$config{'S_HELP'}\">Hilfe</a>" ."\n";
   print "         <td class=\"small_td_r\"><a href=\"$config{'S_ADMIN'}\">Admin</a>" ."\n";
   print '   </tr>' ."\n";
   print '</table>' ."\n";
}

1;
