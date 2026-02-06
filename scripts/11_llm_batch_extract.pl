#!/usr/bin/env perl
#
# 11_llm_batch_extract.pl
# Batch LLM position extraction across all policy domains
#
# Usage:
#   perl scripts/11_llm_batch_extract.pl
#   perl scripts/11_llm_batch_extract.pl --retry-failed
#
# Calls 10_llm_extract_positions.py for each domain sequentially

use strict;
use warnings;
use DBI;
use Time::HiRes qw(time);

# Configuration
my @domains = qw(taxation procurement sovereignty vendor-lock security);
my $retry_mode = grep { $_ eq '--retry-failed' } @ARGV;

# Database connection
my $dbh = DBI->connect(
    "dbi:Pg:dbname=documented_insights;host=postgres",
    "sysadmin", "changeme",
    { RaiseError => 1, AutoCommit => 1 }
) or die "Cannot connect to database: $DBI::errstr";

# Logging
sub log_msg {
    my ($msg) = @_;
    my ($sec, $min, $hour, $mday, $mon, $year) = localtime();
    printf "[%04d-%02d-%02d %02d:%02d:%02d] %s\n",
        $year + 1900, $mon + 1, $mday, $hour, $min, $sec, $msg;
}

# Get statistics for a domain
sub get_domain_stats {
    my ($domain) = @_;
    
    my $sth = $dbh->prepare(q{
        SELECT 
            COUNT(DISTINCT CASE WHEN p.domain = ? THEN r.id END) as processed,
            COUNT(DISTINCT CASE WHEN r.llm_extraction_failed = TRUE THEN r.id END) as failed,
            COUNT(DISTINCT p.id) as positions
        FROM responses r
        LEFT JOIN position_analysis p ON r.id = p.response_id
    });
    
    $sth->execute($domain);
    my ($processed, $failed, $positions) = $sth->fetchrow_array();
    
    return {
        processed => $processed || 0,
        failed => $failed || 0,
        positions => $positions || 0
    };
}

# Main processing
log_msg("=" x 60);
log_msg("Batch LLM Position Extraction");
log_msg("Started: " . scalar(localtime));
log_msg("Domains: " . join(", ", @domains));
log_msg("Retry mode: " . ($retry_mode ? "enabled" : "disabled"));
log_msg("=" x 60);
print "\n";

my $total_processed = 0;
my $total_failed = 0;
my $total_positions = 0;
my $start_time = time();

# Process each domain
for my $domain (@domains) {
    log_msg("=" x 60);
    log_msg("Processing domain: $domain");
    log_msg("=" x 60);
    
    # Get initial statistics
    my $stats_before = get_domain_stats($domain);
    log_msg(sprintf("Before: %d processed, %d failed, %d positions",
        $stats_before->{processed},
        $stats_before->{failed},
        $stats_before->{positions}
    ));
    
    # Build Python command
    my $cmd = "python /app/scripts/10_llm_extract_positions.py --domain $domain";
    $cmd .= " --retry-failed" if $retry_mode;
    
    # Execute extraction
    log_msg("Starting extraction...");
    my $domain_start = time();
    
    my $exit_code = system($cmd);
    
    my $domain_duration = time() - $domain_start;
    
    # Get final statistics
    my $stats_after = get_domain_stats($domain);
    
    my $processed_change = $stats_after->{processed} - $stats_before->{processed};
    my $failed_change = $stats_after->{failed} - $stats_before->{failed};
    my $positions_change = $stats_after->{positions} - $stats_before->{positions};
    
    log_msg(sprintf("After:  %d processed, %d failed, %d positions",
        $stats_after->{processed},
        $stats_after->{failed},
        $stats_after->{positions}
    ));
    
    log_msg(sprintf("Change: +%d processed, +%d failed, +%d positions",
        $processed_change,
        $failed_change,
        $positions_change
    ));
    
    log_msg(sprintf("Duration: %.1f minutes", $domain_duration / 60));
    
    if ($exit_code == 0) {
        log_msg("✓ Domain $domain completed successfully");
    } else {
        log_msg("⚠ Domain $domain completed with errors (exit code: $exit_code)");
    }
    
    # Update totals
    $total_processed += $processed_change;
    $total_failed += $failed_change;
    $total_positions += $positions_change;
    
    print "\n";
}

# Retry pass if failures occurred and not in retry mode
if (!$retry_mode && $total_failed > 0) {
    log_msg("=" x 60);
    log_msg("Retry Pass - Processing Failed Extractions");
    log_msg("Total failures to retry: $total_failed");
    log_msg("=" x 60);
    print "\n";
    
    for my $domain (@domains) {
        log_msg("Retrying failed extractions for: $domain");
        
        my $cmd = "python /app/scripts/10_llm_extract_positions.py --domain $domain --retry-failed";
        my $exit_code = system($cmd);
        
        if ($exit_code == 0) {
            log_msg("✓ Retry for $domain completed");
        } else {
            log_msg("⚠ Retry for $domain completed with errors");
        }
        
        print "\n";
    }
}

# Final summary
my $total_duration = time() - $start_time;

log_msg("=" x 60);
log_msg("Batch Extraction Complete");
log_msg("Finished: " . scalar(localtime));
log_msg("=" x 60);
print "\n";

log_msg("Summary:");
log_msg(sprintf("  Responses processed: %d", $total_processed));
log_msg(sprintf("  New failures: %d", $total_failed));
log_msg(sprintf("  Positions extracted: %d", $total_positions));
log_msg(sprintf("  Total duration: %.1f minutes", $total_duration / 60));
print "\n";

# Per-domain breakdown
log_msg("Per-Domain Results:");
for my $domain (@domains) {
    my $stats = get_domain_stats($domain);
    log_msg(sprintf("  %s: %d processed, %d failed, %d positions",
        $domain,
        $stats->{processed},
        $stats->{failed},
        $stats->{positions}
    ));
}

print "\n";
log_msg("Next steps:");
log_msg("  1. Check results: make llm-status");
log_msg("  2. Review positions: make llm-positions DOMAIN=taxation");
log_msg("  3. Generate reports: make llm-reports-all");

$dbh->disconnect();
