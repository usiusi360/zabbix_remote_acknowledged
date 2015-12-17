#!/usr/bin/perl

use FindBin qw($Bin);
use lib $Bin. "/lib";
use File::Basename;

use strict;
use warnings;
use utf8;

use ZabbixAPI;
use SlackAPI;
use Data::Dumper;
use Net::SMTP;
use Jcode;
use Sys::Syslog;

###################################################
### for zabbix ###
my $url = 'http://XXX.XXX.XXX.XXX/zabbix/';
my $user      = 'admin';
my $pass      = 'Your_Password';
my $threshold = 300;

### for smtp   ###
my $from        = 'zabbix@your_domain.com';
my $subject_str = '[Zabbix] There are non-acceptance events';

my $smtp_server = 'Your_SMTP_Server';
my $RetryTimes_smtp = 2;
my $interval_smtp   = 5;

#////
my $script_dir = $FindBin::Bin;
my $seq_file   = "$script_dir/zabbix_event_check.seq";

#/// escalation list
my $mailtoFile = "$script_dir/zabbix_event_check.list";
open( FH, $mailtoFile );
my @mailtoList = <FH>;

chomp(@mailtoList);

###################################################


my $count = &zabbix_UnAckTrigger_search( $url, $user, $pass, $threshold );

if ( $count != 0 ) {
        &log_write( "info", "[INFO] UnAckEvent is found.[Number=$count]" );
}
else {
        &seq_write(0);
        exit 0;
}


&log_write( "info", "[INFO] send main start.[Number=$count]" );

my $old_seq = seq_read();
my $mailto  = $mailtoList[$old_seq];


my $message_str = << "__HERE__" ;
There are not yet acceptance of the event.( number:$count )
Please check it.
__HERE__
my $message = jcode( $message_str, 'utf8' )->jis;

my $subject = jcode($subject_str)->mime_encode();
my $header  = << "MAILHEADER";
From: $from
To: $mailto
Subject: $subject
Mime-Version: 1.0
Content-Type: text/plain; charset = "ISO-2022-JP"
Content-Transfer-Encoding: 7bit
MAILHEADER

my $count_smtp = 0;
my $smtp = Net::SMTP->new( $smtp_server, Timeout => 10 );
while ( $count_smtp <= $RetryTimes_smtp ) {
        eval { $smtp->mail($from); };

        if ($@) {
                ### Retry over
                if ( $count_smtp == $RetryTimes_smtp ) {
                        &log_write( "err", "[ERROR] mail server connect error.[$@]" );
                        exit 1;
                }

                ### Retry
                &log_write( "info", "[INFO] Retry mail server connect.[$@]" );
                $count_smtp++;
                sleep $interval_smtp;

        }
        else {
                last;
        }

}

$smtp->to($mailto);
$smtp->data();
$smtp->datasend("$header\n");
$smtp->datasend("$message\n");
$smtp->dataend();
$smtp->quit;

### for Slack
my $slack_ret = SlackAPI->message_send(
"There are not yet acceptance of the event.( number:$count )\nI was notified.\n[SendTo=$mailto]"
);

if ( $slack_ret == 0 ) {
        &log_write( "info", "[INFO] slack write finish." );
}
else {
        &log_write( "err", "[ERROR] slack write error." );
        exit 1;
}

my $mailtoListLength = @mailtoList - 1;
my $next_seq;
if ( $old_seq >= $mailtoListLength ) {
        $next_seq = 0;
}
else {
        $next_seq = $old_seq + 1;
}
&seq_write($next_seq);

&log_write( "info", "[INFO] UnAckEvent sendto finish.[SendTo=$mailto]" );
exit 0;

#/////////////////////////
sub log_write {
        my $level  = "";
        my $sysMes = "";
        ( $level, $sysMes ) = @_;
        my $scriptName = basename( $0, '' );

        openlog( $scriptName, 'pid', $scriptName );
        syslog( "$level", "$sysMes" );
        closelog();
}

sub seq_read {
        if ( !-e $seq_file ) {
                return 0;
        }

        open( IN, $seq_file );
        my $seq_num = <IN>;
        close(IN);
        return $seq_num;
}

sub seq_write {
        my $seq_num = "";
        ($seq_num) = @_;
        open( OUT, ">$seq_file" );
        print OUT $seq_num;
        close(OUT);
}

sub zabbix_UnAckTrigger_search {
        my ( $url, $user, $pass, $threshold ) = @_;

        my $za = ZabbixAPI->new("$url");
        eval { $za->auth( "$user", "$pass" ); };
        if ($@) {
                &log_write( "err", "[ERROR] zabbix connection error.[$@]" );
                exit 1;
        }

        my $za_temp = $za->trigger_get(
                {
                        output                   => "extend",
                        withUnacknowledgedEvents => "0",
                        maintenance              => "0",
                        skipDependent            => "0",
                }
        );

        my $count = 0;
        for my $za_temp (@$za_temp) {
                my $diff = time() - $za_temp->{lastchange};
                if ( $diff > $threshold ) {
                        $count = $count + 1;
                }
        }

        return $count;
}
