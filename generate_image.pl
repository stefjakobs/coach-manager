#!/usr/bin/perl -wT

######
# Copyright (c) 2015 Stefan Jakobs
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
use CGI ':standard';
use GD::Graph::lines;
use lib '.';
use functions;

## global variables
my $error;
my $sth;
my $cgi = CGI->new;

my %config = read_config();
my @course_ids;

# Connect to the database.
my $dbh = init_db(\%config);

sub untaint_input() {
   ## untaint input
   if ( defined($cgi->param('course_id')) and $cgi->param('course_id') =~ /^[0-9]+$/i ) {
      push(@course_ids, $cgi->param('course_id'));
   } else {
      $error .= "Kurs-ID darf nur aus Zahlen bestehen!<br>";
   }
}

sub generate_image() {
   my @dates;
   my @course_names;
   my @data;
   my $query;

   if (@course_ids) {
      $query = "SELECT name from $config{'T_COURSE'} WHERE FIND_IN_SET(id, '" .join( ',', @course_ids) ."') >0";
   } else {
      $query = "SELECT id,name from $config{'T_COURSE'}";
   }
   my $sth = $dbh->prepare($query);
   if ($config{'debug'}) { print_debug("query: $query"); }
   $sth->execute();
   while (my $ref = $sth->fetchrow_hashref()) {
      if (defined($ref->{'id'})) { push(@course_ids, $ref->{'id'}); };
      push(@course_names, $ref->{'name'});
   }

   # @dates will contain the max. number of course occurences
   # we can push now into @data because, we push the reference.
   push(@data, \@dates);
   foreach my $id (@course_ids) {
      my @participants;
      $query = "SELECT date,participants from $config{'T_EVENT'} where course_id = $id";
      $sth = $dbh->prepare($query);
      if ($config{'debug'}) { print_debug("query: $query"); }
      $sth->execute();

      my $i = 1;
      while (my $ref = $sth->fetchrow_hashref()) {
         push(@dates, $i) unless $i < scalar(@dates);
         if ( defined($ref->{'participants'}) ) {
            push(@participants, $ref->{'participants'});
         } else { push(@participants, '0'); }
         $i++;
      }
      $sth->finish();
      # push the list of participants for that course to the @data array
      push(@data, \@participants);
   }

   my $mygraph = GD::Graph::lines->new(800, 400);
   $mygraph->set(
      x_label          => 'Kursnummer',
      x_label_position => '0.5',
      y_label          => 'Teilnehmer',
      title            => 'Kursbelegung',
      bgclr            => 'white',
      transparent      => '0',
      line_width       => '3',
      legend_placement => 'RC',

   ) or warn $mygraph->error;
   $mygraph->set_legend(@course_names);
   $mygraph->set_legend_font(GD::Font->Large);
   $mygraph->set_y_axis_font(GD::Font->Small);
   $mygraph->set_x_axis_font(GD::Font->Small);

   my $myimage = $mygraph->plot(\@data) or die $mygraph->error;

   print "Content-type: image/png\n\n";
   print $myimage->png;
}

untaint_input();
generate_image();
