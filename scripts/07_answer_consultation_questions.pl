#!/usr/bin/perl
use strict;
use warnings;
use DBI;

print "Consultation Question Analysis\n";
print "==============================\n\n";

# Configuration
my $db_name = $ENV{POSTGRES_DB} || 'documented_insights';
my $db_user = $ENV{POSTGRES_USER} || 'sysadmin';
my $db_pass = $ENV{POSTGRES_PASSWORD} || 'changeme';
my $db_host = $ENV{POSTGRES_HOST} || 'postgres';

my $output_file = '/app/output/consultation_questions_analysis.md';

# Connect to database
my $dbh = DBI->connect(
    "dbi:Pg:dbname=$db_name;host=$db_host",
    $db_user, $db_pass,
    { AutoCommit => 1, RaiseError => 1, pg_enable_utf8 => 1 }
) or die "Cannot connect: $DBI::errstr\n";

print "Connected to database.\n";
print "Generating analysis...\n\n";

open my $out, '>:encoding(UTF-8)', $output_file or die "Cannot create output: $!\n";

# Header
print $out "# Analysis of EU Open Digital Ecosystems Consultation Responses\n\n";
print $out "## Overview\n\n";

my $total = $dbh->selectrow_array("SELECT COUNT(*) FROM responses");
my $with_text = $dbh->selectrow_array("SELECT COUNT(*) FROM responses WHERE full_text IS NOT NULL");
my $with_attachments = $dbh->selectrow_array("SELECT COUNT(*) FROM responses WHERE has_attachment = true");

print $out "This analysis examines $total consultation responses ($with_text with text, $with_attachments with attachments) ";
print $out "to identify key themes and patterns relevant to the five consultation questions.\n\n";

# Question 1: Strengths and Weaknesses + Barriers
print $out "## Question 1: Strengths, Weaknesses and Barriers\n\n";
print $out "**Question:** What are the strengths and weaknesses of the EU open-source sector? ";
print $out "What are the main barriers that hamper (i) adoption and maintenance of high-quality and secure open source ";
print $out "(ii) sustainable contributions to open-source communities?\n\n";

print $out "### Key Themes from Response Analysis\n\n";

# Barrier-related terms
my $barriers = $dbh->selectall_arrayref(q{
    SELECT w.word, wf.total_count, wf.document_count,
           ROUND(100.0 * wf.document_count / (SELECT COUNT(*) FROM responses WHERE full_text IS NOT NULL), 1) as pct
    FROM response_words w
    JOIN word_frequency wf ON w.word = wf.word
    WHERE w.word IN ('barriers', 'barrier', 'challenges', 'obstacles', 'difficulties', 
                     'problems', 'issues', 'constraints', 'limitations')
    GROUP BY w.word, wf.total_count, wf.document_count
    ORDER BY wf.total_count DESC
});

if (@$barriers) {
    print $out "#### Barrier Language Usage\n\n";
    print $out "\\begin{longtable}{lrrr}\n";
    print $out "\\toprule\n";
    print $out "Term & Occurrences & Documents & \\% Coverage \\\\\n";
    print $out "\\midrule\n";
    print $out "\\endfirsthead\n\n";
    print $out "\\multicolumn{4}{c}{{\\bfseries \\tablename\\ \\thetable{} -- continued from previous page}} \\\\\n";
    print $out "\\toprule\n";
    print $out "Term & Occurrences & Documents & \\% Coverage \\\\\n";
    print $out "\\midrule\n";
    print $out "\\endhead\n\n";
    print $out "\\bottomrule\n";
    print $out "\\endlastfoot\n\n";
    
    foreach my $row (@$barriers) {
        printf $out "%s & %d & %d & %.1f\\%% \\\\\n", @$row;
    }
    print $out "\\end{longtable}\n\n";
}

# Co-occurrence with "barriers"
my $barrier_context = $dbh->selectall_arrayref(q{
    SELECT w2.word, COUNT(*) as co_occur
    FROM response_words w1
    JOIN response_words w2 ON w1.response_id = w2.response_id
    WHERE w1.word IN ('barriers', 'barrier')
      AND w2.word != 'barriers' AND w2.word != 'barrier'
      AND w2.word NOT IN (SELECT word FROM stopwords)
      AND LENGTH(w2.word) > 4
    GROUP BY w2.word
    ORDER BY COUNT(*) DESC
    LIMIT 30
});

if (@$barrier_context) {
    print $out "#### Context: Terms Appearing with 'Barriers'\n\n";
    print $out "Terms frequently mentioned alongside barrier discussions:\n\n";
    
    print $out "\\begin{longtable}{lr}\n";
    print $out "\\toprule\n";
    print $out "Term & Co-occurrences \\\\\n";
    print $out "\\midrule\n";
    print $out "\\endfirsthead\n\n";
    print $out "\\multicolumn{2}{c}{{\\bfseries \\tablename\\ \\thetable{} -- continued from previous page}} \\\\\n";
    print $out "\\toprule\n";
    print $out "Term & Co-occurrences \\\\\n";
    print $out "\\midrule\n";
    print $out "\\endhead\n\n";
    print $out "\\bottomrule\n";
    print $out "\\endlastfoot\n\n";
    
    foreach my $row (@$barrier_context) {
        printf $out "%s & %d \\\\\n", @$row;
    }
    print $out "\\end{longtable}\n\n";
}

# Specific barrier types
print $out "#### Specific Barriers Mentioned\n\n";

my @barrier_types = (
    ['procurement', 'Procurement Barriers'],
    ['funding', 'Funding Barriers'],
    ['skills', 'Skills/Capacity Barriers'],
    ['governance', 'Governance Barriers'],
    ['vendor', 'Vendor Lock-in'],
    ['lock-in', 'Lock-in Issues'],
    ['maintenance', 'Maintenance Challenges'],
    ['sustainability', 'Sustainability Issues']
);

foreach my $bt (@barrier_types) {
    my ($term, $label) = @$bt;
    
    my $count = $dbh->selectrow_array(
        "SELECT COUNT(DISTINCT response_id) FROM response_words WHERE word = ?", 
        undef, $term
    );
    
    if ($count && $count > 10) {
        my $pct = sprintf("%.1f", 100.0 * $count / $with_text);
        print $out "- **$label**: mentioned in $count responses ($pct\\%)\n";
    }
}
print $out "\n";

# Question 2: Added Value
print $out "## Question 2: Added Value of Open Source\n\n";
print $out "**Question:** What is the added value of open source for the public and private sectors? ";
print $out "Provide concrete examples including factors such as cost, risk, lock-in, security, innovation.\n\n";

print $out "### Value-Related Themes\n\n";

my $value_terms = $dbh->selectall_arrayref(q{
    SELECT word, total_count, document_count,
           ROUND(100.0 * document_count / (SELECT COUNT(*) FROM responses WHERE full_text IS NOT NULL), 1) as pct
    FROM word_frequency
    WHERE word IN ('value', 'benefits', 'advantages', 'savings', 'cost-effective',
                   'transparency', 'flexibility', 'independence', 'control', 
                   'interoperability', 'standards', 'innovation', 'security')
    ORDER BY total_count DESC
});

if (@$value_terms) {
    print $out "\\begin{longtable}{lrrr}\n";
    print $out "\\toprule\n";
    print $out "Value Factor & Occurrences & Documents & \\% Coverage \\\\\n";
    print $out "\\midrule\n";
    print $out "\\endfirsthead\n\n";
    print $out "\\multicolumn{4}{c}{{\\bfseries \\tablename\\ \\thetable{} -- continued from previous page}} \\\\\n";
    print $out "\\toprule\n";
    print $out "Value Factor & Occurrences & Documents & \\% Coverage \\\\\n";
    print $out "\\midrule\n";
    print $out "\\endhead\n\n";
    print $out "\\bottomrule\n";
    print $out "\\endlastfoot\n\n";
    
    foreach my $row (@$value_terms) {
        printf $out "%s & %d & %d & %.1f\\%% \\\\\n", @$row;
    }
    print $out "\\end{longtable}\n\n";
}

# Public vs Private sector mentions
my $public_count = $dbh->selectrow_array(
    "SELECT COUNT(DISTINCT response_id) FROM response_words WHERE word = 'public'"
);
my $private_count = $dbh->selectrow_array(
    "SELECT COUNT(DISTINCT response_id) FROM response_words WHERE word = 'private'"
);
my $sector_count = $dbh->selectrow_array(
    "SELECT COUNT(DISTINCT response_id) FROM response_words WHERE word = 'sector'"
);

print $out "### Sector Focus\n\n";
print $out "- Public sector mentioned in $public_count responses (" . 
    sprintf("%.1f", 100.0 * $public_count / $with_text) . "\\%)\n";
print $out "- Private sector mentioned in $private_count responses (" . 
    sprintf("%.1f", 100.0 * $private_count / $with_text) . "\\%)\n";
print $out "- General 'sector' mentions in $sector_count responses (" . 
    sprintf("%.1f", 100.0 * $sector_count / $with_text) . "\\%)\n\n";

# Question 3: EU-level Measures
print $out "## Question 3: EU-Level Measures and Actions\n\n";
print $out "**Question:** What concrete measures and actions may be taken at EU level to support ";
print $out "the development and growth of the EU open-source sector and contribute to the EU's ";
print $out "technological sovereignty and cybersecurity agenda?\n\n";

print $out "### Proposed Measures (by frequency)\n\n";

my $measures = $dbh->selectall_arrayref(q{
    SELECT word, total_count, document_count,
           ROUND(100.0 * document_count / (SELECT COUNT(*) FROM responses WHERE full_text IS NOT NULL), 1) as pct
    FROM word_frequency
    WHERE word IN ('funding', 'support', 'investment', 'grants', 'subsidies',
                   'procurement', 'regulation', 'standards', 'certification',
                   'education', 'training', 'infrastructure', 'framework',
                   'policy', 'legislation', 'incentives', 'partnership')
    ORDER BY total_count DESC
});

if (@$measures) {
    print $out "\\begin{longtable}{lrrr}\n";
    print $out "\\toprule\n";
    print $out "Measure Type & Occurrences & Documents & \\% Coverage \\\\\n";
    print $out "\\midrule\n";
    print $out "\\endfirsthead\n\n";
    print $out "\\multicolumn{4}{c}{{\\bfseries \\tablename\\ \\thetable{} -- continued from previous page}} \\\\\n";
    print $out "\\toprule\n";
    print $out "Measure Type & Occurrences & Documents & \\% Coverage \\\\\n";
    print $out "\\midrule\n";
    print $out "\\endhead\n\n";
    print $out "\\bottomrule\n";
    print $out "\\endlastfoot\n\n";
    
    foreach my $row (@$measures) {
        printf $out "%s & %d & %d & %.1f\\%% \\\\\n", @$row;
    }
    print $out "\\end{longtable}\n\n";
}

# Sovereignty and security emphasis
my $sovereignty_co = $dbh->selectall_arrayref(q{
    SELECT w2.word, COUNT(*) as co_occur
    FROM response_words w1
    JOIN response_words w2 ON w1.response_id = w2.response_id
    WHERE w1.word IN ('sovereignty', 'sovereign')
      AND w2.word NOT IN ('sovereignty', 'sovereign')
      AND w2.word NOT IN (SELECT word FROM stopwords)
      AND w2.word IN ('funding', 'support', 'infrastructure', 'investment', 
                      'procurement', 'standards', 'regulation', 'policy')
    GROUP BY w2.word
    ORDER BY COUNT(*) DESC
});

if (@$sovereignty_co) {
    print $out "### Measures in Sovereignty Context\n\n";
    print $out "Measures frequently mentioned alongside sovereignty discussions:\n\n";
    
    foreach my $row (@$sovereignty_co) {
        printf $out "- **%s**: %d co-occurrences\n", @$row;
    }
    print $out "\n";
}

# Question 4: Technology Areas
print $out "## Question 4: Priority Technology Areas\n\n";
print $out "**Question:** What technology areas should be prioritised and why?\n\n";

print $out "### Technology Area Mentions\n\n";

my $tech_areas = $dbh->selectall_arrayref(q{
    SELECT word, total_count, document_count,
           ROUND(100.0 * document_count / (SELECT COUNT(*) FROM responses WHERE full_text IS NOT NULL), 1) as pct
    FROM word_frequency
    WHERE word IN ('cloud', 'artificial', 'intelligence', 'cybersecurity', 'security',
                   'blockchain', 'quantum', 'edge', 'automotive', 'manufacturing',
                   'healthcare', 'education', 'infrastructure', 'network', 'data',
                   'platform', 'frameworks', 'hardware', 'software')
    ORDER BY total_count DESC
});

if (@$tech_areas) {
    print $out "\\begin{longtable}{lrrr}\n";
    print $out "\\toprule\n";
    print $out "Technology Area & Occurrences & Documents & \\% Coverage \\\\\n";
    print $out "\\midrule\n";
    print $out "\\endfirsthead\n\n";
    print $out "\\multicolumn{4}{c}{{\\bfseries \\tablename\\ \\thetable{} -- continued from previous page}} \\\\\n";
    print $out "\\toprule\n";
    print $out "Technology Area & Occurrences & Documents & \\% Coverage \\\\\n";
    print $out "\\midrule\n";
    print $out "\\endhead\n\n";
    print $out "\\bottomrule\n";
    print $out "\\endlastfoot\n\n";
    
    foreach my $row (@$tech_areas) {
        printf $out "%s & %d & %d & %.1f\\%% \\\\\n", @$row;
    }
    print $out "\\end{longtable}\n\n";
}

# AI specific
my $ai_terms = $dbh->selectall_arrayref(q{
    SELECT w2.word, COUNT(*) as co_occur
    FROM response_words w1
    JOIN response_words w2 ON w1.response_id = w2.response_id
    WHERE w1.word IN ('artificial', 'intelligence')
      AND w2.word NOT IN ('artificial', 'intelligence')
      AND w2.word NOT IN (SELECT word FROM stopwords)
      AND LENGTH(w2.word) > 4
    GROUP BY w2.word
    ORDER BY COUNT(*) DESC
    LIMIT 20
});

if (@$ai_terms) {
    print $out "### AI Technology Context\n\n";
    print $out "Terms appearing with AI/Intelligence mentions:\n\n";
    
    foreach my $row (@$ai_terms) {
        printf $out "- %s: %d mentions\n", @$row;
    }
    print $out "\n";
}

# Question 5: Sector Applications
print $out "## Question 5: Sector Applications for Competitiveness\n\n";
print $out "**Question:** In what sectors could increased use of open source lead to ";
print $out "increased competitiveness and cyber resilience?\n\n";

print $out "### Sector Mentions\n\n";

my $sectors = $dbh->selectall_arrayref(q{
    SELECT word, total_count, document_count,
           ROUND(100.0 * document_count / (SELECT COUNT(*) FROM responses WHERE full_text IS NOT NULL), 1) as pct
    FROM word_frequency
    WHERE word IN ('healthcare', 'health', 'medical', 'hospital',
                   'education', 'academic', 'university', 'research',
                   'finance', 'banking', 'financial',
                   'government', 'administration', 'public-sector',
                   'automotive', 'manufacturing', 'industrial', 'industry',
                   'energy', 'utilities', 'telecommunications', 'transport')
    ORDER BY total_count DESC
});

if (@$sectors) {
    print $out "\\begin{longtable}{lrrr}\n";
    print $out "\\toprule\n";
    print $out "Sector & Occurrences & Documents & \\% Coverage \\\\\n";
    print $out "\\midrule\n";
    print $out "\\endfirsthead\n\n";
    print $out "\\multicolumn{4}{c}{{\\bfseries \\tablename\\ \\thetable{} -- continued from previous page}} \\\\\n";
    print $out "\\toprule\n";
    print $out "Sector & Occurrences & Documents & \\% Coverage \\\\\n";
    print $out "\\midrule\n";
    print $out "\\endhead\n\n";
    print $out "\\bottomrule\n";
    print $out "\\endlastfoot\n\n";
    
    foreach my $row (@$sectors) {
        printf $out "%s & %d & %d & %.1f\\%% \\\\\n", @$row;
    }
    print $out "\\end{longtable}\n\n";
}

# Competitiveness mentions
my $competitive = $dbh->selectall_arrayref(q{
    SELECT w2.word, COUNT(*) as co_occur
    FROM response_words w1
    JOIN response_words w2 ON w1.response_id = w2.response_id
    WHERE w1.word IN ('competitiveness', 'competitive', 'competition')
      AND w2.word NOT IN ('competitiveness', 'competitive', 'competition')
      AND w2.word NOT IN (SELECT word FROM stopwords)
      AND w2.word IN (SELECT word FROM word_frequency WHERE document_count > 50)
    GROUP BY w2.word
    ORDER BY COUNT(*) DESC
    LIMIT 20
});

if (@$competitive) {
    print $out "### Competitiveness Context\n\n";
    print $out "Terms associated with competitiveness discussions:\n\n";
    
    foreach my $row (@$competitive) {
        printf $out "- %s: %d co-occurrences\n", @$row;
    }
    print $out "\n";
}

# Cross-cutting themes
print $out "## Cross-Cutting Themes\n\n";

print $out "### Stakeholder Perspectives\n\n";

my $stakeholder_stats = $dbh->selectall_arrayref(q{
    SELECT user_type, COUNT(*) as count,
           ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM responses), 1) as pct
    FROM responses
    WHERE user_type IS NOT NULL AND user_type != ''
    GROUP BY user_type
    ORDER BY COUNT(*) DESC
});

print $out "\\begin{longtable}{lrr}\n";
print $out "\\toprule\n";
print $out "Stakeholder Type & Responses & \\% of Total \\\\\n";
print $out "\\midrule\n";
print $out "\\endfirsthead\n\n";
print $out "\\multicolumn{3}{c}{{\\bfseries \\tablename\\ \\thetable{} -- continued from previous page}} \\\\\n";
print $out "\\toprule\n";
print $out "Stakeholder Type & Responses & \\% of Total \\\\\n";
print $out "\\midrule\n";
print $out "\\endhead\n\n";
print $out "\\bottomrule\n";
print $out "\\endlastfoot\n\n";

foreach my $row (@$stakeholder_stats) {
    my ($type, $count, $pct) = @$row;
    $type =~ s/_/ /g;
    printf $out "%s & %d & %.1f\\%% \\\\\n", $type, $count, $pct;
}
print $out "\\end{longtable}\n\n";

print $out "### Geographic Distribution\n\n";

my $country_stats = $dbh->selectall_arrayref(q{
    SELECT country, COUNT(*) as count
    FROM responses
    WHERE country IS NOT NULL AND country != ''
    GROUP BY country
    ORDER BY COUNT(*) DESC
    LIMIT 10
});

print $out "Top 10 countries by response volume:\n\n";

foreach my $row (@$country_stats) {
    printf $out "- %s: %d responses\n", @$row;
}
print $out "\n";

close $out;
$dbh->disconnect;

print "Analysis complete: $output_file\n";
