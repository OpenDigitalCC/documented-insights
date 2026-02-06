#!/usr/bin/perl
# lib/DomainQuery.pm
# Build SQL queries from domain configurations

package DomainQuery;

use strict;
use warnings;
use utf8;

# Build WHERE clause for domain keywords/keyphrases
# Returns SQL condition string
sub build_where_clause {
    my ($config) = @_;
    
    my @conditions;
    
    # Keywords: word boundary matching
    if (@{$config->{keywords}}) {
        foreach my $keyword (@{$config->{keywords}}) {
            my $escaped = quotemeta($keyword);
            push @conditions, "lower(full_text) ~ '\\m$escaped\\M'";
        }
    }
    
    # Keyphrases: flexible matching
    if (@{$config->{keyphrases}}) {
        foreach my $phrase (@{$config->{keyphrases}}) {
            my $pattern = keyphrase_to_pattern($phrase);
            push @conditions, "lower(full_text) ~ '$pattern'";
        }
    }
    
    return '' unless @conditions;
    
    # Join with OR - match any term
    return '(' . join(' OR ', @conditions) . ')';
}

# Convert keyphrase to regex pattern with flexible whitespace/punctuation
sub keyphrase_to_pattern {
    my ($phrase) = @_;
    
    # Split into words
    my @words = split(/\s+/, $phrase);
    
    # Escape each word for regex
    @words = map { quotemeta($_) } @words;
    
    # Join with flexible separator: whitespace, hyphen, or nothing
    my $pattern = join('[\\s\\-]*', @words);
    
    # Add word boundaries
    return "\\m$pattern\\M";
}

# Build query for sub-theme
sub build_sub_theme_where {
    my ($config, $theme_name) = @_;
    
    return '' unless exists $config->{sub_themes}{$theme_name};
    
    my @terms = @{$config->{sub_themes}{$theme_name}};
    my @conditions;
    
    foreach my $term (@terms) {
        # Check if term is a keyphrase (contains space)
        if ($term =~ /\s/) {
            my $pattern = keyphrase_to_pattern($term);
            push @conditions, "lower(full_text) ~ '$pattern'";
        }
        else {
            my $escaped = quotemeta($term);
            push @conditions, "lower(full_text) ~ '\\m$escaped\\M'";
        }
    }
    
    return '' unless @conditions;
    return '(' . join(' OR ', @conditions) . ')';
}

# Get matching response IDs for domain
sub get_matching_response_ids {
    my ($dbh, $config) = @_;
    
    my $where = build_where_clause($config);
    return [] unless $where;
    
    my $sql = qq{
        SELECT id
        FROM responses
        WHERE full_text IS NOT NULL
          AND $where
        ORDER BY id
    };
    
    my $rows = $dbh->selectcol_arrayref($sql);
    return $rows || [];
}

# Get matching responses with metadata
sub get_matching_responses {
    my ($dbh, $config) = @_;
    
    my $where = build_where_clause($config);
    return [] unless $where;
    
    my $sql = qq{
        SELECT id, ec_id, country, organization, user_type, language,
               date_feedback, has_attachment
        FROM responses
        WHERE full_text IS NOT NULL
          AND $where
        ORDER BY id
    };
    
    my $rows = $dbh->selectall_arrayref($sql, { Slice => {} });
    return $rows || [];
}

# Get count of matching responses
sub get_match_count {
    my ($dbh, $config) = @_;
    
    my $where = build_where_clause($config);
    return 0 unless $where;
    
    my $sql = qq{
        SELECT COUNT(*)
        FROM responses
        WHERE full_text IS NOT NULL
          AND $where
    };
    
    return $dbh->selectrow_array($sql) || 0;
}

# Get stakeholder breakdown for domain
sub get_stakeholder_breakdown {
    my ($dbh, $config) = @_;
    
    my $where = build_where_clause($config);
    return [] unless $where;
    
    my $sql = qq{
        SELECT user_type,
               COUNT(*) as count,
               COUNT(DISTINCT country) as countries,
               COUNT(DISTINCT organization) as organizations,
               ROUND(100.0 * COUNT(*) / (
                   SELECT COUNT(*) 
                   FROM responses 
                   WHERE full_text IS NOT NULL AND $where
               ), 1) as percentage
        FROM responses
        WHERE full_text IS NOT NULL
          AND $where
          AND user_type IS NOT NULL
          AND user_type != ''
        GROUP BY user_type
        ORDER BY COUNT(*) DESC
    };
    
    return $dbh->selectall_arrayref($sql, { Slice => {} });
}

# Get geographic breakdown for domain
sub get_geographic_breakdown {
    my ($dbh, $config) = @_;
    
    my $where = build_where_clause($config);
    return [] unless $where;
    
    my $sql = qq{
        SELECT country,
               COUNT(*) as count,
               COUNT(DISTINCT user_type) as stakeholder_types,
               ROUND(100.0 * COUNT(*) / (
                   SELECT COUNT(*) 
                   FROM responses 
                   WHERE full_text IS NOT NULL AND $where
               ), 1) as percentage
        FROM responses
        WHERE full_text IS NOT NULL
          AND $where
          AND country IS NOT NULL
          AND country != ''
        GROUP BY country
        ORDER BY COUNT(*) DESC
    };
    
    return $dbh->selectall_arrayref($sql, { Slice => {} });
}

# Get word co-occurrences for domain terms
sub get_domain_cooccurrence {
    my ($dbh, $config, $limit) = @_;
    
    $limit ||= 30;
    
    # Get matching response IDs
    my $response_ids = get_matching_response_ids($dbh, $config);
    return [] unless @$response_ids;
    
    # Convert to SQL array format
    my $ids_list = join(',', @$response_ids);
    
    my $sql = qq{
        SELECT w.word,
               COUNT(*) as occurrences,
               COUNT(DISTINCT w.response_id) as documents,
               ROUND(100.0 * COUNT(DISTINCT w.response_id) / ?, 1) as doc_pct
        FROM response_words w
        WHERE w.response_id IN ($ids_list)
          AND w.word NOT IN (SELECT word FROM stopwords)
        GROUP BY w.word
        ORDER BY COUNT(*) DESC
        LIMIT ?
    };
    
    return $dbh->selectall_arrayref($sql, { Slice => {} }, scalar(@$response_ids), $limit);
}

# Get sub-theme breakdown
sub get_sub_theme_breakdown {
    my ($dbh, $config) = @_;
    
    return {} unless exists $config->{sub_themes} && %{$config->{sub_themes}};
    
    my %results;
    
    foreach my $theme (sort keys %{$config->{sub_themes}}) {
        my $where = build_sub_theme_where($config, $theme);
        next unless $where;
        
        my $sql = qq{
            SELECT COUNT(*)
            FROM responses
            WHERE full_text IS NOT NULL
              AND $where
        };
        
        my $count = $dbh->selectrow_array($sql) || 0;
        $results{$theme} = $count;
    }
    
    return \%results;
}

# Get example responses for domain (for quotes/evidence)
sub get_example_responses {
    my ($dbh, $config, $limit) = @_;
    
    $limit ||= 5;
    
    my $where = build_where_clause($config);
    return [] unless $where;
    
    # Prioritize responses with attachments (likely more detailed)
    my $sql = qq{
        SELECT id, ec_id, country, organization, user_type,
               CASE 
                   WHEN LENGTH(full_text) > 500 
                   THEN SUBSTRING(full_text FROM 1 FOR 500) || '...'
                   ELSE full_text
               END as excerpt
        FROM responses
        WHERE full_text IS NOT NULL
          AND $where
        ORDER BY has_attachment DESC, LENGTH(full_text) DESC
        LIMIT ?
    };
    
    return $dbh->selectall_arrayref($sql, { Slice => {} }, $limit);
}

# Analyze term usage patterns and contexts
sub get_term_usage_patterns {
    my ($dbh, $config) = @_;
    
    # Get response IDs for this domain
    my $response_ids = get_matching_response_ids($dbh, $config);
    return {} unless @$response_ids;
    
    my %patterns;
    
    # Analyze key domain terms (top 5 from keywords/keyphrases)
    my @key_terms = @{$config->{keywords}};
    push @key_terms, @{$config->{keyphrases}};
    
    # Limit to first 5 terms for analysis
    @key_terms = @key_terms[0..4] if @key_terms > 5;
    
    my $ids_list = join(',', @$response_ids);
    
    foreach my $term (@key_terms) {
        # Calculate term strength relative to corpus
        my $domain_freq_sql = qq{
            SELECT COUNT(*) as freq
            FROM response_words
            WHERE response_id IN ($ids_list)
              AND word = ?
        };
        
        my $corpus_freq_sql = qq{
            SELECT total_count
            FROM word_frequency
            WHERE word = ?
        };
        
        my $domain_freq = $dbh->selectrow_array($domain_freq_sql, undef, lc($term)) || 0;
        my $corpus_freq = $dbh->selectrow_array($corpus_freq_sql, undef, lc($term)) || 1;
        
        # Calculate relative strength (how much more common in this domain vs corpus)
        my $domain_size = scalar(@$response_ids);
        my $corpus_size = $dbh->selectrow_array("SELECT COUNT(*) FROM responses WHERE full_text IS NOT NULL") || 1;
        
        my $domain_rate = $domain_freq / $domain_size;
        my $corpus_rate = $corpus_freq / $corpus_size;
        
        my $strength = $corpus_rate > 0 ? ($domain_rate / $corpus_rate) : 1;
        
        # Analyze co-occurrence for context
        my $positive_words = get_positive_cooccurrence($dbh, $term, $ids_list);
        my $negative_words = get_negative_cooccurrence($dbh, $term, $ids_list);
        
        $patterns{$term} = {
            strength => $strength,
            domain_frequency => $domain_freq,
            positive_context => $positive_words,
            negative_context => $negative_words,
            usage_note => get_usage_interpretation($strength)
        };
    }
    
    return \%patterns;
}

# Get positive co-occurrence words
sub get_positive_cooccurrence {
    my ($dbh, $term, $ids_list) = @_;
    
    my @positive_indicators = ('support', 'benefit', 'opportunity', 'enable', 'improve', 
                              'strengthen', 'promote', 'advantage', 'positive', 'necessary');
    
    my $pattern = join('|', map { quotemeta($_) } @positive_indicators);
    
    my $sql = qq{
        SELECT w.word
        FROM response_words w
        WHERE w.response_id IN ($ids_list)
          AND w.word ~ ?
          AND EXISTS (
              SELECT 1 FROM response_words w2
              WHERE w2.response_id = w.response_id
                AND w2.word = ?
          )
        GROUP BY w.word
        ORDER BY COUNT(*) DESC
        LIMIT 3
    };
    
    my $words = $dbh->selectcol_arrayref($sql, undef, $pattern, lc($term));
    
    return @$words ? "Used with: " . join(', ', @$words) : undef;
}

# Get negative co-occurrence words
sub get_negative_cooccurrence {
    my ($dbh, $term, $ids_list) = @_;
    
    my @negative_indicators = ('barrier', 'problem', 'lack', 'fail', 'insufficient',
                              'limit', 'prevent', 'hinder', 'challenge', 'difficult');
    
    my $pattern = join('|', map { quotemeta($_) } @negative_indicators);
    
    my $sql = qq{
        SELECT w.word
        FROM response_words w
        WHERE w.response_id IN ($ids_list)
          AND w.word ~ ?
          AND EXISTS (
              SELECT 1 FROM response_words w2
              WHERE w2.response_id = w.response_id
                AND w2.word = ?
          )
        GROUP BY w.word
        ORDER BY COUNT(*) DESC
        LIMIT 3
    };
    
    my $words = $dbh->selectcol_arrayref($sql, undef, $pattern, lc($term));
    
    return @$words ? "Discussed alongside: " . join(', ', @$words) : undef;
}

# Interpret strength score
sub get_usage_interpretation {
    my ($strength) = @_;
    
    if ($strength > 3.0) {
        return "Highly concentrated in this domain (appears 3x+ more than in general corpus)";
    }
    elsif ($strength > 1.5) {
        return "Moderately concentrated in this domain";
    }
    elsif ($strength > 0.8) {
        return "Standard usage frequency";
    }
    else {
        return "Less emphasized in this domain compared to general corpus";
    }
}

# Analyze overall sentiment patterns in domain
sub get_domain_sentiment {
    my ($dbh, $config) = @_;
    
    my $response_ids = get_matching_response_ids($dbh, $config);
    return {} unless @$response_ids;
    
    my $ids_list = join(',', @$response_ids);
    my $total_responses = scalar(@$response_ids);
    
    # Action-oriented language
    my $action_sql = qq{
        SELECT COUNT(DISTINCT response_id) * 100.0 / ?
        FROM response_words
        WHERE response_id IN ($ids_list)
          AND word IN ('propose', 'should', 'must', 'require', 'recommend', 'urge', 'call')
    };
    
    # Problem-focused language
    my $problem_sql = qq{
        SELECT COUNT(DISTINCT response_id) * 100.0 / ?
        FROM response_words
        WHERE response_id IN ($ids_list)
          AND word IN ('barrier', 'problem', 'lack', 'fail', 'challenge', 'difficult', 'insufficient')
    };
    
    # Solution-focused language
    my $solution_sql = qq{
        SELECT COUNT(DISTINCT response_id) * 100.0 / ?
        FROM response_words
        WHERE response_id IN ($ids_list)
          AND word IN ('solution', 'opportunity', 'benefit', 'enable', 'improve', 'advantage')
    };
    
    my %sentiment = (
        action_oriented => $dbh->selectrow_array($action_sql, undef, $total_responses) || 0,
        problem_focused => $dbh->selectrow_array($problem_sql, undef, $total_responses) || 0,
        solution_focused => $dbh->selectrow_array($solution_sql, undef, $total_responses) || 0
    );
    
    # Determine dominant tone
    my $action = $sentiment{action_oriented};
    my $problem = $sentiment{problem_focused};
    my $solution = $sentiment{solution_focused};
    
    if ($action > 40) {
        $sentiment{dominant_tone} = "Strong advocacy for specific actions";
        $sentiment{advocacy_level} = "High";
    }
    elsif ($solution > $problem * 1.5) {
        $sentiment{dominant_tone} = "Constructive and solution-oriented";
        $sentiment{advocacy_level} = "Moderate";
    }
    elsif ($problem > $solution * 1.5) {
        $sentiment{dominant_tone} = "Critical of current state";
        $sentiment{advocacy_level} = "Moderate";
    }
    else {
        $sentiment{dominant_tone} = "Balanced discussion";
        $sentiment{advocacy_level} = "Low to Moderate";
    }
    
    return \%sentiment;
}

# Get domain coverage statistics
sub get_coverage_stats {
    my ($dbh, $config) = @_;
    
    my $where = build_where_clause($config);
    return {} unless $where;
    
    my $sql = qq{
        SELECT 
            COUNT(*) as matching_responses,
            COUNT(DISTINCT country) as countries,
            COUNT(DISTINCT user_type) as stakeholder_types,
            COUNT(DISTINCT organization) as organizations,
            COUNT(CASE WHEN has_attachment THEN 1 END) as with_attachments,
            ROUND(100.0 * COUNT(*) / (
                SELECT COUNT(*) FROM responses WHERE full_text IS NOT NULL
            ), 1) as pct_of_corpus
        FROM responses
        WHERE full_text IS NOT NULL
          AND $where
    };
    
    my $stats = $dbh->selectrow_hashref($sql);
    return $stats || {};
}

# Build full analysis query set for domain
sub build_analysis_queries {
    my ($config) = @_;
    
    my $where = build_where_clause($config);
    return {} unless $where;
    
    my %queries = (
        # Basic counts
        total_matches => qq{
            SELECT COUNT(*) 
            FROM responses 
            WHERE full_text IS NOT NULL AND $where
        },
        
        # Stakeholder breakdown
        by_stakeholder => qq{
            SELECT user_type, COUNT(*) as count
            FROM responses
            WHERE full_text IS NOT NULL AND $where
                AND user_type IS NOT NULL
            GROUP BY user_type
            ORDER BY COUNT(*) DESC
        },
        
        # Geographic breakdown
        by_country => qq{
            SELECT country, COUNT(*) as count
            FROM responses
            WHERE full_text IS NOT NULL AND $where
                AND country IS NOT NULL
            GROUP BY country
            ORDER BY COUNT(*) DESC
        },
        
        # Language breakdown
        by_language => qq{
            SELECT language, COUNT(*) as count
            FROM responses
            WHERE full_text IS NOT NULL AND $where
                AND language IS NOT NULL
            GROUP BY language
            ORDER BY COUNT(*) DESC
        },
        
        # Organizations
        top_organizations => qq{
            SELECT organization, country, user_type, COUNT(*) as responses
            FROM responses
            WHERE full_text IS NOT NULL AND $where
                AND organization IS NOT NULL AND organization != ''
            GROUP BY organization, country, user_type
            ORDER BY COUNT(*) DESC
            LIMIT 20
        }
    );
    
    return \%queries;
}

1;
