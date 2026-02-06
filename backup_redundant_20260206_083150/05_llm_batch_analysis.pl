#!/usr/bin/perl
use strict;
use warnings;
use DBI;
use LWP::UserAgent;
use JSON;
use Time::HiRes qw(time sleep);
use Encode qw(decode_utf8 encode_utf8);

# Configuration
my $db_name = $ENV{POSTGRES_DB} || 'documented_insights';
my $db_user = $ENV{POSTGRES_USER} || 'sysadmin';
my $db_pass = $ENV{POSTGRES_PASSWORD} || 'changeme';
my $db_host = $ENV{POSTGRES_HOST} || 'postgres';
my $ollama_host = $ENV{OLLAMA_HOST} || 'http://ollama:11434';
my $model = $ENV{OLLAMA_MODEL} || 'llama3.1:8b';

my $batch_size = 30;
my $max_batches = $ENV{MAX_BATCHES} || 0;  # 0 = process all

print "LLM Batch Analysis\n";
print "==================\n";
print "Model: $model\n";
print "Batch size: $batch_size\n";
if ($max_batches > 0) {
    print "Max batches: $max_batches\n";
} else {
    print "Max batches: unlimited\n";
}
print "Database: $db_name\n\n";

# Connect to database
my $dbh = DBI->connect(
    "dbi:Pg:dbname=$db_name;host=$db_host",
    $db_user,
    $db_pass,
    { AutoCommit => 0, RaiseError => 1, PrintError => 0, pg_enable_utf8 => 1 }
) or die "Cannot connect: $DBI::errstr\n";

print "Connected to database.\n";

# Show total work
my $total_unprocessed = $dbh->selectrow_array("SELECT COUNT(*) FROM responses WHERE llm_processed = false");
print "Total unprocessed responses: $total_unprocessed\n";

if ($total_unprocessed > 0) {
    my $est_batches = int(($total_unprocessed + $batch_size - 1) / $batch_size);
    my $est_minutes = int($est_batches * 0.5);  # ~30 sec per batch
    print "Estimated batches: $est_batches\n";
    print "Estimated time: ~$est_minutes minutes\n\n";
}

# HTTP client for Ollama
my $ua = LWP::UserAgent->new(timeout => 600);

# Prepare statements
my $fetch_sql = qq{
    SELECT id, organization, country, feedback, full_text
    FROM responses
    WHERE llm_processed = false
    AND full_text IS NOT NULL
    ORDER BY id
    LIMIT ?
};

my $insert_code_sql = qq{
    INSERT INTO analysis_codes (response_id, code_type, code_value, confidence, notes)
    VALUES (?, ?, ?, ?, ?)
};

my $update_processed_sql = qq{
    UPDATE responses SET llm_processed = true WHERE id = ?
};

my $log_sql = qq{
    INSERT INTO processing_log (response_id, stage, status, error_message, duration_seconds)
    VALUES (?, 'llm_analysis', ?, ?, ?)
};

my $fetch_sth = $dbh->prepare($fetch_sql);
my $insert_code_sth = $dbh->prepare($insert_code_sql);
my $update_sth = $dbh->prepare($update_processed_sql);
my $log_sth = $dbh->prepare($log_sql);

my $batch_num = 0;
my $total_processed = 0;
my $total_codes = 0;

while (1) {
    $batch_num++;
    
    # Check if we should stop
    last if $max_batches > 0 && $batch_num > $max_batches;
    
    # Fetch next batch
    $fetch_sth->execute($batch_size);
    my @batch = @{$fetch_sth->fetchall_arrayref({})};
    
    last if @batch == 0;
    
    print "\n";
    print "=" x 60;
    print "\n";
    print "Batch $batch_num\n";
    print "Processing " . scalar(@batch) . " responses\n";
    
    if ($total_unprocessed > 0) {
        my $pct = int(100 * $total_processed / $total_unprocessed);
        print "Progress: $total_processed/$total_unprocessed ($pct%)\n";
    }
    
    print "=" x 60;
    print "\n";
    
    # Build prompt
    my $prompt = build_analysis_prompt(\@batch);
    
    # Call LLM
    print "Calling LLM (model: $model)...\n";
    my $start_time = time();
    my $result = call_ollama($prompt);
    my $duration = time() - $start_time;
    
    unless ($result) {
        warn "LLM call failed for batch $batch_num\n";
        # Log failures
        foreach my $response (@batch) {
            $log_sth->execute($response->{id}, 'failed', 'LLM call failed', $duration / @batch);
        }
        $dbh->commit;
        next;
    }
    
    my $duration_str = sprintf("%.1f", $duration);
    print "LLM responded in ${duration_str}s\n";
    
    # DEBUG: Save first few batches for inspection
    if ($batch_num <= 2) {
        my $debug_file = "/app/output/llm_debug_batch_${batch_num}.txt";
        open my $debug_fh, '>', $debug_file;
        print $debug_fh "=== PROMPT ===\n$prompt\n\n";
        print $debug_fh "=== RAW LLM OUTPUT ===\n$result\n\n";
        close $debug_fh;
        print "Debug saved to: $debug_file\n";
    }
    
    # Parse response
    my $codes = parse_llm_response($result, \@batch);
    
    # Store codes
    my $stored = 0;
    foreach my $code (@$codes) {
        eval {
            $insert_code_sth->execute(
                $code->{response_id},
                $code->{code_type},
                $code->{code_value},
                $code->{confidence},
                $code->{notes}
            );
            $stored++;
        };
        if ($@) {
            warn "Error storing code: $@\n";
        }
    }
    
    # Mark as processed and log
    foreach my $response (@batch) {
        $update_sth->execute($response->{id});
        $log_sth->execute($response->{id}, 'success', undef, $duration / @batch);
        $total_processed++;
    }
    
    $dbh->commit;
    
    print "Stored $stored codes\n";
    print "Total processed: $total_processed\n";
    
    $total_codes += $stored;
    
    # Small delay between batches
    sleep 1;
}

$dbh->disconnect;

print "\n";
print "=" x 60;
print "\n";
print "ANALYSIS COMPLETE\n";
print "=" x 60;
print "\n";
print "Total responses processed: $total_processed\n";
print "Total batches: $batch_num\n";
print "Total codes extracted: $total_codes\n";
print "\nRun 'make monitor-progress' to see results\n";

sub build_analysis_prompt {
    my ($batch) = @_;
    
    # Build the responses section first
    my $responses_text = '';
    foreach my $resp (@$batch) {
        my $text = $resp->{full_text} || $resp->{feedback} || '';
        $text = substr($text, 0, 600);  # Shorter to fit more in context
        $text =~ s/\n/ /g;
        $text =~ s/"/'/g;
        $text =~ s/[^\x20-\x7E]/?/g;
        
        my $org = $resp->{organization} || 'Unknown';
        my $country = $resp->{country} || 'Unknown';
        
        $responses_text .= "ID $resp->{id}: [$org, $country] $text\n\n";
    }
    
    my $prompt = qq{Analyze these consultation responses. For each response, determine:
1. theme: procurement OR licensing OR governance OR technical_infrastructure OR market_competition OR data_sovereignty OR interoperability OR other
2. sentiment: positive OR neutral OR critical OR mixed  
3. stakeholder: government OR company_large OR company_sme OR ngo OR academic OR individual OR other
4. argument: one sentence summary (max 80 chars)

Return ONLY a JSON array with this EXACT structure:
[{"response_id":33363055,"theme":"governance","sentiment":"neutral","stakeholder":"company_large","argument":"Open source needs governance and accountability"},{"response_id":33363057,"theme":"other","sentiment":"critical","stakeholder":"individual","argument":"Disagrees with EU centralization"}]

Do NOT add explanations. Do NOT use markdown. Output ONLY the JSON array.

RESPONSES:

$responses_text

JSON:};
    
    return $prompt;
}

sub call_ollama {
    my ($prompt) = @_;
    
    my $payload = encode_json({
        model => $model,
        prompt => $prompt,
        stream => JSON::false,
        format => "json",  # Force JSON mode
        system => "You extract structured data from text. Output only valid JSON arrays. Never add explanations or markdown.",
        options => {
            temperature => 0.0,  # Deterministic
            num_predict => 4000,
        }
    });
    
    my $response = $ua->post(
        "$ollama_host/api/generate",
        'Content-Type' => 'application/json',
        Content => $payload
    );
    
    return undef unless $response->is_success;
    
    my $result = decode_json($response->content);
    return $result->{response};
}

sub parse_llm_response {
    my ($text, $batch) = @_;
    my @codes;
    
    # Remove ALL markdown - backticks, code fences, etc.
    $text =~ s/```json\s*//gi;
    $text =~ s/```\s*//gi;
    $text =~ s/`//g;  # Remove single backticks too
    
    # Remove any explanatory text before/after JSON
    # Look for [ ... ] and extract just that
    my $json_str;
    if ($text =~ /(\[\s*\{.*?\}\s*\])/s) {
        $json_str = $1;
    } elsif ($text =~ /(\[.*\])/s) {
        $json_str = $1;
    } else {
        warn "No JSON array found in response\n";
        warn "Response was: " . substr($text, 0, 300) . "\n";
        
        # Save failed response for debugging
        my $fail_file = "/app/output/parse_failure_" . time() . ".txt";
        open my $fh, '>', $fail_file;
        print $fh "Failed to parse:\n$text\n";
        close $fh;
        warn "Saved to: $fail_file\n";
        
        return \@codes;
    }
    
    # Clean up encoding issues
    $json_str =~ s/[^\x20-\x7E\n\r\t\{\}\[\]:,"']/?/g;
    
    my $data;
    eval {
        $data = decode_json($json_str);
    };
    
    if ($@) {
        warn "Failed to parse JSON: $@\n";
        warn "JSON string was: " . substr($json_str, 0, 500) . "\n";
        
        # Save for debugging
        my $fail_file = "/app/output/json_parse_failure_" . time() . ".txt";
        open my $fh, '>', $fail_file;
        print $fh "JSON parse error: $@\n\n";
        print $fh "Extracted JSON:\n$json_str\n";
        close $fh;
        warn "Saved to: $fail_file\n";
        
        return \@codes;
    }
    
    unless (ref($data) eq 'ARRAY') {
        warn "LLM response is not an array, got: " . ref($data) . "\n";
        return \@codes;
    }
    
    print "Successfully parsed " . scalar(@$data) . " items from JSON\n";
    
    foreach my $item (@$data) {
        my $rid = $item->{response_id};
        
        unless ($rid) {
            warn "Item missing response_id, has keys: " . join(', ', keys %$item) . "\n";
            next;
        }
        
        # Validate we're processing expected responses
        my $found = 0;
        foreach my $r (@$batch) {
            if ($r->{id} == $rid) {
                $found = 1;
                last;
            }
        }
        
        unless ($found) {
            warn "Response ID $rid not in current batch, skipping\n";
            next;
        }
        
        # Theme
        my $theme = $item->{theme} || 'unknown';
        push @codes, {
            response_id => $rid,
            code_type => 'theme',
            code_value => $theme,
            confidence => 0.8,
            notes => undef
        };
        
        # Sentiment
        my $sentiment = $item->{sentiment} || 'neutral';
        push @codes, {
            response_id => $rid,
            code_type => 'sentiment',
            code_value => $sentiment,
            confidence => 0.8,
            notes => undef
        };
        
        # Stakeholder
        my $stakeholder = $item->{stakeholder} || 'unknown';
        push @codes, {
            response_id => $rid,
            code_type => 'stakeholder',
            code_value => $stakeholder,
            confidence => 0.8,
            notes => undef
        };
        
        # Argument
        my $arg = $item->{argument} || '';
        $arg =~ s/[^\x20-\x7E\n\r\t]/?/g;  # Clean non-ASCII
        
        push @codes, {
            response_id => $rid,
            code_type => 'argument',
            code_value => $arg,
            confidence => 0.7,
            notes => undef
        };
    }
    
    print "Extracted " . scalar(@codes) . " codes total\n";
    
    return \@codes;
}
