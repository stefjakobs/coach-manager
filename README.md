coach-manager
=============

Perl Webapplication - Manages the time table for different courses and coaches.

Datenbankanbindung
------------------

Diese Webanwendung verwendet folgendes Datenbanklayout:

+----------+
|  config  |
| -------- |
| * id     |
| * string |
| * value  |
+----------+

+---------+ 1    * +-------+ *   1 +----------+ 1   * +-----------+
| course  | -----> | event | <---- | schedule | ----> | coachlist |
+ --------+        +-------+       +----------+       +-----------+

Die Basis für alles sind Kurse. Ein Kurs besteht aus mehreren Trainingstagen,
hier events genannt. Einem Traingstag können mehrere Trainer zugeordnet sein.
Umgekehrt kann ein Trainer aber mehreren Trainingstagen zugeordnet sein.
Diese n:m Zuordnung wird über die zusätzliche Tabelle schedule realisiert.

Nachfolgend die Auszüge über die Einrichtung der Datenbank:

mysql> show tables;
+-------------------+
| Tables_in_trainer |
+-------------------+
| coachlist         |
| config            |
| course            |
| event             |
| schedule          |
+-------------------+

mysql> describe coachlist;
+------------+-----------------------+------+-----+---------+----------------+
| Field      | Type                  | Null | Key | Default | Extra          |
+------------+-----------------------+------+-----+---------+----------------+
| id         | int(11)               | NO   | PRI | NULL    | auto_increment |
| lastname   | varbinary(64)         | NO   |     | NULL    |                |
| firstname  | varbinary(64)         | NO   |     | NULL    |                |
| birthday   | date                  | YES  |     | NULL    |                |
| email      | varbinary(256)        | YES  |     | NULL    |                |
| telephone  | varchar(20)           | YES  |     | NULL    |                |
| password   | varchar(64)           | YES  |     | NULL    |                |
| priviledge | tinyint(4)            | NO   |     | 0       |                |
| license    | enum('A','B','C','D') | YES  |     | NULL    |                |
| active     | tinyint(1)            | NO   |     | 1       |                |
+------------+-----------------------+------+-----+---------+----------------+

Die Tabelle coachlist enthält die Angaben zu den Personen. Der Zugriff auf
eine Person erfolgt immer über die die ID.

mysql> describe config;
+--------+---------------+------+-----+---------+----------------+
| Field  | Type          | Null | Key | Default | Extra          |
+--------+---------------+------+-----+---------+----------------+
| id     | int(11)       | NO   | PRI | NULL    | auto_increment |
| string | varchar(64)   | NO   | UNI | NULL    |                |
| value  | varbinary(64) | NO   |     | NULL    |                |
+--------+---------------+------+-----+---------+----------------+

Die Tabelle config dient zur Versionsverwaltung des Datenbankschemas. Dort
wird der String 'version' mit der aktuellen Versionsnummer als value
gespeichert. Bei einem Update des Schemas kann der aktuelle Wert ausgelesen
werden und daraus die nötigen Änderungen ermittelt werden.

mysql> describe course;
+-----------+-------------+------+-----+---------+----------------+
| Field     | Type        | Null | Key | Default | Extra          |
+-----------+-------------+------+-----+---------+----------------+
| id        | int(11)     | NO   | PRI | NULL    | auto_increment |
| name      | varchar(64) | NO   | UNI | NULL    |                |
| number    | int(11)     | NO   |     | 0       |                |
| startdate | date        | NO   |     | NULL    |                |
| enddate   | date        | NO   |     | NULL    |                |
| starttime | time        | NO   |     | NULL    |                |
| endtime   | time        | NO   |     | NULL    |                |
+-----------+-------------+------+-----+---------+----------------+

Die Kurse liegen in der Tabelle course. Das Feld 'name' muss eindeutig sein.

mysql> describe event;
+--------------+------------+------+-----+---------+----------------+
| Field        | Type       | Null | Key | Default | Extra          |
+--------------+------------+------+-----+---------+----------------+
| id           | int(11)    | NO   | PRI | NULL    | auto_increment |
| date         | date       | NO   |     | NULL    |                |
| course_id    | int(11)    | NO   | MUL | NULL    |                |
| omitted      | tinyint(1) | NO   |     | 0       |                |
| participants | tinyint(4) | YES  |     | NULL    |                |
+--------------+------------+------+-----+---------+----------------+

Aus den Daten eines Kurses werden automatisch die Events erzeutgt, welche
in der Tabelle 'event' abgelegt werden. Ein Event ist über die 'course_id'
genau einem Kurs zugeordnet. 'omitted' gibt an, ob der Kurs ausfällt.
'participants' gibt die Anzahl der Teilnehmer an.

mysql> describe schedule;
+----------+-----------------------------------+------+-----+---------+----------------+
| Field    | Type                              | Null | Key | Default | Extra          |
+----------+-----------------------------------+------+-----+---------+----------------+
| id       | int(11)                           | NO   | PRI | NULL    | auto_increment |
| coach_id | int(11)                           | NO   | MUL | NULL    |                |
| event_id | int(11)                           | NO   | MUL | NULL    |                |
| coaching | enum('A','B','C','F','P','X','-') | NO   |     | NULL    |                |
+----------+-----------------------------------+------+-----+---------+----------------+

Die Tabelle schedule ermöglicht die n:m Zuordnung zwischen Trainern und Events. Ein Eintrag
verbindet einen Trainer mit einem Event. Das Feld 'coaching' bezeichnet die Funktion des
Trainers.

Perl-CGI-Skripte
----------------

Es werden die folgenden Module benötigt:
  * CGI
  * DBI
  * DBD::mysql
  * Date::Manip
  * Digest::SHA

Es wird durchgehend UTF-8 verwendet.

Die Perl Skripte sind nach folgendem Schema aufgebaut:
Zuerst wird in einer Funktion ein Template für die Anzeige der Seite erstellt.
Dieses besteht hauptsächlich aus HTML-Code mit einigen Perl-Variablen.
Anschließend wird eine Funktion für die Überprüfung der per POST und/oder
GET übergebenen Parameter erstellt.

Der Hauptteil überprüft dann, ob die Seite mit ihrem Aufruf über POST Daten
übermittelt hat. Ist dies der Fall, dann werden die per POST übergebenen Daten
verarbeitet, sprich in die Datenbank eingetragen. Ist dies nicht der Fall, dann
wird nur das Formular aufgerufen. Dies besteht aus:
  * Dem HTML-Kopf
  * Der Linkliste auf dem Kopf der Seite
  * Dem Formular
  * Dem Footer der Seite
  * Dem HTML-Ende

Wo möglich wurden Funktionalitäten in Funktionen ausgegliedert, die über das 
Paket 'functions' zur Verfügung gestellt werden. Dies Paket stellt vor allem
die Funktion zum Einlesen der Konfigurationsdatei zur Verfügung, sowie die 
Funktion 'init_db' zum Zugriff auf die Datenbank.

Cookies
-------

Die Anwendung setzt zwei Cookies:

  * SessionID
  * schedule_hash

SessionID enthält ein geteiltes (nicht so geheimes) Geheimnis mit einer
Gültigkeitsdauer von 10 Minuten. Dies bewirkt, dass Änderungen nur
durchgeführt werden können, solange der Cookie gültig ist.

schedule_hash enthält den Inhalt der Tabelle auf der Hauptseite (trainer.pl)
als SHA256 kodierten String. Bevor Änderungen an der Hauptseite passieren,
wird geprüft, ob der String noch aktuell ist. Dadurch wird verhindert, dass
eine Seite geschrieben wurde, obwohl während dessen schon andere Änderungen
passiert sind.

###################################################################
# Copyright (c) 2013-2019 Stefan Jakobs
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
###################################################################
# This was written by:
#       Stefan Jakobs <projects@localside.net>
#
# Please send all comments, suggestion, bug reports, etc
#       to projects@localside.net
#
###################################################################
