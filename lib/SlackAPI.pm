package SlackAPI;

use FindBin qw($Bin);
use File::Basename;

use strict;
use warnings;
use utf8;

use JSON;
use LWP::UserAgent;
#use HTTP::Request::Common qw(POST);
use Data::Dumper;

sub message_send() {
        ###################################################
        ### for slack ###
        my $channel  = "#alert_high";
        my $emoji    = ":bangbang:";
        my $username = "Zabbix";
        my $Slack_hooks_URL ="https://hooks.slack.com/services/YourURL";
        ###################################################

        my $class    = shift;
        my $message  = shift;
 
        my %pay_hash = (
                "channel"    => "$channel",
                "username"   => "$username",
                "text"       => "$message",
                "icon_emoji" => "$emoji"
        );

        my $payload = encode_json( \%pay_hash );
        my $ua = LWP::UserAgent->new;
        $ua->timeout(30);
        my $response = $ua->post( $Slack_hooks_URL, Content => "payload=$payload" );
       

        #for Debug
        #print Dumper $response;

        if ( $response->is_success ) {
                return 0;
        }
        else {
                return 1;
        }

}

1;