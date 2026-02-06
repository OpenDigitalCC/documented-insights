#!/usr/bin/perl
# scripts/03_build_word_index.pl

use strict;
use warnings;
use DBI;
use Time::HiRes qw(time);

print "Word Frequency Index Builder\n";
print "=============================\n\n";

# Configuration
my $db_name = $ENV{POSTGRES_DB} || 'documented_insights';
my $db_user = $ENV{POSTGRES_USER} || 'sysadmin';
my $db_pass = $ENV{POSTGRES_PASSWORD} || 'changeme';
my $db_host = $ENV{POSTGRES_HOST} || 'postgres';

my $dbh = DBI->connect(
    "dbi:Pg:dbname=$db_name;host=$db_host",
    $db_user,
    $db_pass,
    { AutoCommit => 0, RaiseError => 1, pg_enable_utf8 => 1 }
) or die "Cannot connect: $DBI::errstr\n";

print "Connected to database.\n";

# Load stopwords
my %stopwords;
my $stop_sth = $dbh->prepare("SELECT word FROM stopwords");
$stop_sth->execute();
while (my ($word) = $stop_sth->fetchrow_array) {
    $stopwords{$word} = 1;
}
print "Loaded " . scalar(keys %stopwords) . " stopwords.\n\n";

# Clear existing indexes
print "Clearing existing word indexes...\n";
$dbh->do("TRUNCATE word_frequency, response_words");
$dbh->commit;

# Get responses
my $response_sth = $dbh->prepare(q{
    SELECT id, full_text 
    FROM responses 
    WHERE full_text IS NOT NULL AND full_text != ''
    ORDER BY id
});

my $insert_response_word = $dbh->prepare(q{
    INSERT INTO response_words (response_id, word, count, position_first)
    VALUES (?, ?, ?, ?)
});

my $update_fts = $dbh->prepare(q{
    UPDATE responses 
    SET fts_vector = to_tsvector('english', ?)
    WHERE id = ?
});

# Global word frequency
my %global_freq;

print "Processing responses...\n";
my $start_time = time();
my $processed = 0;
my $total = $dbh->selectrow_array(
    "SELECT COUNT(*) FROM responses WHERE full_text IS NOT NULL AND full_text != ''"
);

print "Total responses to process: $total\n\n";

$response_sth->execute();

while (my $row = $response_sth->fetchrow_hashref) {
    my $text = $row->{full_text};
    my $id = $row->{id};
    
    # Extract words (3+ chars, alphanumeric + hyphen)
    my @words = $text =~ /\b([a-z][a-z0-9\-]{2,})\b/gi;
    
    my %response_freq;
    my $position = 0;
    
    foreach my $word (@words) {
        $word = lc($word);
        $position++;
        
        # Skip stopwords, numbers, long garbage
        next if $stopwords{$word};
        next if $word =~ /^\d+$/;
        next if length($word) > 30;
        
        unless (exists $response_freq{$word}) {
            $response_freq{$word} = {
                count => 0,
                first_pos => $position
            };
        }
        
        $response_freq{$word}{count}++;
    }
    
    # Store per-response words
    foreach my $word (keys %response_freq) {
        my $count = $response_freq{$word}{count};
        my $first = $response_freq{$word}{first_pos};
        
        $insert_response_word->execute($id, $word, $count, $first);
        
        # Update global
        $global_freq{$word}{count} += $count;
        $global_freq{$word}{docs}++;
    }
    
    # Update FTS
    $update_fts->execute($text, $id);
    
    $processed++;
    
    # Progress
    if ($processed % 50 == 0) {
        my $pct = sprintf("%.1f", 100 * $processed / $total);
        my $elapsed = time() - $start_time;
        my $rate = $processed / $elapsed;
        my $eta = ($total - $processed) / $rate / 60;
        
        printf("Progress: %d/%d (%s%%) - %.1f docs/sec - ETA: %.1f min\n",
            $processed, $total, $pct, $rate, $eta);
        
        $dbh->commit;
    }
}

$dbh->commit;

print "\nBuilding global word frequency table...\n";

my $insert_global = $dbh->prepare(q{
    INSERT INTO word_frequency (word, total_count, document_count, avg_per_document)
    VALUES (?, ?, ?, ?)
});

my $words_inserted = 0;
foreach my $word (keys %global_freq) {
    my $count = $global_freq{$word}{count};
    my $docs = $global_freq{$word}{docs};
    my $avg = sprintf("%.2f", $count / $docs);
    
    $insert_global->execute($word, $count, $docs, $avg);
    $words_inserted++;
    
    if ($words_inserted % 1000 == 0) {
        printf("Inserted %d words...\n", $words_inserted);
        $dbh->commit;
    }
}

$dbh->commit;

my $duration = sprintf("%.1f", (time() - $start_time) / 60);

print "\n";
print "=" x 60;
print "\n";
print "INDEX BUILD COMPLETE\n";
print "=" x 60;
print "\n";
print "Responses processed: $processed\n";
print "Unique words indexed: $words_inserted\n";
print "Duration: $duration minutes\n";
print "\nRun 'make word-stats' to see results\n";

$dbh->disconnect;
