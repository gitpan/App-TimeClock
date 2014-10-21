package App::TimeClock::DailyReport;

use POSIX qw(difftime strftime);
use Time::Local;
use Time::Piece;

=head1 NAME

App::TimeClock::DailyReport

=head1 DESCRIPTION

Can parse the timelog and generate a report using an instance of a
L<App::TimeClock::PrinterInterface>.

=head2 METHODS

=over

=item new($timelog, $printer)

Initializes a new L<App::TimeClock::DailyReport> object.

Two parameters are required:

=over

=item B<$timelog>

Must point to a timelog file. Will die if not.

=item B<$printer>

An object derived from L<App::TimeClock::PrinterInterface>. Will die if not.

=back

=cut
sub new {
    my $class = shift;
    my $self = {
        timelog => shift,
        printer => shift,
    };
    die "timelog ($self->{timelog}) does not exist" unless -f $self->{timelog} and -r $self->{timelog};
    die "printer is not a PrinterInterface" unless $self->{printer}->isa("App::TimeClock::PrinterInterface");
    bless $self, $class;
};


=item _timelocal() 

Returns a time (seconds since epoch) from a date and time.

=cut
sub _timelocal {
    my ($self, $date, $time) = @_;
    my ($year, $mon, $mday) = split(/\//, $date);
    my ($hours, $min, $sec ) = split(/:/, $time);

    return timelocal($sec, $min, $hours, $mday, $mon-1, $year);
};

=item _get_report_time()

Returns the time when the report was executed.

=cut
sub _get_report_time { $_[0]->{_report_time} || time }

=item _set_report_time()

Sets the time when the report is executed.

=cut
sub _set_report_time { $_[0]->{_report_time} = $_[0]->_timelocal($_[1], $_[2]) }

=item execute()

Opens the timelog file starts parsing it, looping over each day and
calling print_day() for each.

=cut
sub execute {
    my $self = shift;

    open FILE, '<', $self->{timelog} or die "$!\n";
    binmode FILE, ':utf8';

    my %projects;
    my ($current_project, $current_date, $work, $work_total);
    my ($start_time, $end_time);
    my ($work_year_to_date, $day_count) = (0,0);

    $current_date = "";
    $work_total = 0;

    $self->{printer}->print_header;

    while (not eof(FILE)) {
        chomp(my $iline = <FILE>);
        die "Expected check in in line $." unless $iline =~ /^i /;
        
        my $oline = undef;
        if (not eof(FILE)) {
            chomp($oline = <FILE>);
            die "Excepted check out in line $." unless $oline =~ /^o /;
        }

        # Split the line, it should contain:
        #
        # - state is either 'i' - check in or 'o' - check out.
        # - date is formatted as YYYY/MM//DD
        # - time is formatted as HH:MM:SS
        # - project is then name of the project/task and is only required when checking in.
        #
        my ($idate, $itime, $iproject) = (split(/ /, $iline, 4))[1..3];
        my ($odate, $otime, $oproject) = (defined $oline) ? (split(/ /, $oline, 4))[1..3] :
          (strftime("%Y/%m/%d", localtime($self->_get_report_time)),
           strftime("%H:%M:%S", localtime($self->_get_report_time)), "DANGLING");

        if (!length($current_date)) {
            # First check in, set the current date and start time
            $current_date = $idate;
            $start_time = $itime;
        } elsif ($current_date ne $idate) {
            # It's a new day, print the current day, update totals and reset variables
            $self->{printer}->print_day($current_date, $start_time, $end_time, $work_total, %projects);

            $work_year_to_date += $work_total;
            $day_count++;

            $work_total = 0;
            $current_date = $idate;
            $start_time = $itime;
            %projects = ();
            $end_time = "";
        }

        $current_project = $iproject;
        $work = difftime($self->_timelocal($odate, $otime), $self->_timelocal($idate, $itime)) / 60 / 60;
        $work_total += $work;
        $end_time = $otime;
        $projects{$current_project} += $work;

        if (defined $oproject && $oproject eq "DANGLING") {
            $projects{"$current_project (NOT checked out)"} = $projects{$current_project};
            delete $projects{$current_project};
        }
    }

    # Print the last day (in the loop we're only printing when date changes)
    if (length($current_date)) {
	$self->{printer}->print_day($current_date, $start_time, $end_time, $work_total, %projects);
	$work_year_to_date += $work_total;
	$day_count++;
    }

    $self->{printer}->print_footer($work_year_to_date, $day_count);
};
1;

=back

=for text
=encoding utf-8
=end

=head1 AUTHOR

Søren Lund, C<< <soren at lund.org> >>

=head1 SEE ALSO

L<timeclock.pl>

=head1 COPYRIGHT

Copyright (C) 2012 Søren Lund

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; version 2 dated June, 1991 or at your option
any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

A copy of the GNU General Public License is available in the source tree;
if not, write to the Free Software Foundation, Inc.,
59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
