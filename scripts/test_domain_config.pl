#!/usr/bin/env perl
#
# test_domain_config.pl
# Test domain configuration parsing and validation

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use DomainConfig;

my @domains = qw(taxation procurement sovereignty vendor-lock security);

print "Testing Domain Configurations\n";
print "=" x 50, "\n\n";

my $passed = 0;
my $failed = 0;

for my $domain (@domains) {
    my $config_file = "$FindBin::Bin/../domains/${domain}.conf";
    
    print "Testing: $domain\n";
    print "  File: $config_file\n";
    
    unless (-f $config_file) {
        print "  ✗ FAILED: File not found\n\n";
        $failed++;
        next;
    }
    
    my $config = DomainConfig::parse_config($config_file);
    
    unless ($config) {
        print "  ✗ FAILED: Could not parse configuration\n\n";
        $failed++;
        next;
    }
    
    # Validate domain section
    unless ($config->{domain}) {
        print "  ✗ FAILED: Missing [domain] section\n\n";
        $failed++;
        next;
    }
    
    # Validate required fields
    my @required = qw(name description);
    my $valid = 1;
    
    for my $field (@required) {
        unless ($config->{domain}{$field}) {
            print "  ✗ FAILED: Missing required field: $field\n";
            $valid = 0;
        }
    }
    
    # Validate keywords
    unless ($config->{keywords} && @{$config->{keywords}} > 0) {
        print "  ✗ FAILED: No keywords defined\n";
        $valid = 0;
    }
    
    # Validate keyphrases
    unless ($config->{keyphrases} && @{$config->{keyphrases}} > 0) {
        print "  ✗ FAILED: No keyphrases defined\n";
        $valid = 0;
    }
    
    if ($valid) {
        print "  ✓ PASSED\n";
        print "    Keywords: " . scalar(@{$config->{keywords}}) . "\n";
        print "    Keyphrases: " . scalar(@{$config->{keyphrases}}) . "\n";
        $passed++;
    } else {
        $failed++;
    }
    
    print "\n";
}

print "=" x 50, "\n";
print "Results: $passed passed, $failed failed\n";

exit($failed > 0 ? 1 : 0);
