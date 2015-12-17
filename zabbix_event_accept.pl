#!/usr/bin/perl

use FindBin qw($Bin);
use lib $Bin. "/lib";
use File::Basename;

use strict;
use warnings;
use utf8;

use ZabbixAPI;
use SlackAPI;
use Encode;
use MIME::Parser;
use JSON;
use Sys::Syslog;

###################################################
### for zabbix ###
my $url      = 'http://XXX.XXX.XXX.XXX/zabbix/';
my $user = 'admin';
my $pass = 'Your_Password';

### for smtp   ###
my $mailpath = '/var/spool/mail/zabbix';

###################################################

### Mail Check
my ( $returnPath, $subject, $body ) = mail_head_check($mailpath);

### Mail Subject Check

        # for Zabbix
        my $zbx_ret = zabbix_ack_message( $url, $user, $pass, $returnPath );
        if ( $zbx_ret == 0 ) {
                &log_write( "info", "[INFO] zabbix event ack finish." );
        }
        else {
                &log_write( "err", "[ERROR] zabbix event ack error." );
        }

        # for Slack
        my $slack_ret = SlackAPI->message_send(
                "It has accepted.\n[By=$returnPath]");
        if ( $slack_ret == 0 ) {
                &log_write( "info", "[INFO] slack write finish." );
        }
        else {
                &log_write( "err", "[ERROR] slack write error." );
        }

if ( unlink($mailpath) == 0 ) {
       &log_write( "err", "[ERROR] mail delete error.[$!]" );
}

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

sub zabbix_ack_message {
        my ( $url, $user, $pass, $returnPath ) = @_;

        my $za = ZabbixAPI->new("$url");
        eval { $za->auth( "$user", "$pass" ); };
        if ($@) {
                &log_write( "err", "[ERROR] zabbix connection error.[$@]" );
                return 1;
        }

        my $za_trigger_list = $za->trigger_get(
                {
                        output                   => "extend",
                        withUnacknowledgedEvents => "0",
                        maintenance              => "0",
                        skipDependent            => "0",
                }
        );

        my @za_triggers;
        for my $za_trigger_temp (@$za_trigger_list) {
                push @za_triggers, $za_trigger_temp->{triggerid};
        }
        if ( @za_triggers == 0 ) {
                return 0;
        }

        my $events = $za->event_get(
                {
                        output       => "eventID",
                        acknowledged => "0",
                        value        => "1",
                        source       => 0,
                        objectids    => \@za_triggers
                }
        );
        if ( @$events == 0 ) {
                return 0;
        }

        for my $temp (@$events) {
                for my $key ( keys %$temp ) {
                        my $value  = $temp->{$key};
                        my $result = $za->event_acknowledge(
                                { eventids => $value, message => $returnPath } );

                        ### Debug
                        #print Dumper $result;
                }
        }
        return 0;
}

sub mail_head_check {

        my $mailpath = $_[0];
        if ( !-e $mailpath ) {
                exit 0;
        }

        my $parser = MIME::Parser->new;
        $parser->output_to_core(1);
        $parser->tmp_to_core(1);
        $parser->tmp_recycling(1);
        $parser->use_inner_files(1);
        my $entity = $parser->parse_open($mailpath);

        my $returnPath = $entity->head->decode->get('Return-Path');
        my $charset    = $entity->head->mime_attr('Content-Type.charset');

        my $subject_mime =
          Encode::decode( 'MIME-Header', $entity->head->get('Subject') );
        $subject = Encode::decode( $charset, $subject_mime );

        $subject =~ s/\A \s+ | \s+ \z//gxms;

        my $first_part = $entity->is_multipart ? $entity->parts(0) : $entity;

        my $encoded_body = $first_part->bodyhandle->as_string;
        my $body = Encode::decode( $charset, $encoded_body );

        chomp($returnPath);
        chomp($subject);

        return ( $returnPath, $subject, $body );
}

