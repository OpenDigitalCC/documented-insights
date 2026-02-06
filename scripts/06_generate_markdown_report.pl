#!/usr/bin/perl
use strict;
use warnings;
use DBI;
use POSIX qw(strftime);

print "Generating Markdown Report\n";
print "===========================\n\n";

# Configuration
my $db_name = $ENV{POSTGRES_DB} || 'documented_insights';
my $db_user = $ENV{POSTGRES_USER} || 'sysadmin';
my $db_pass = $ENV{POSTGRES_PASSWORD} || 'changeme';
my $db_host = $ENV{POSTGRES_HOST} || 'postgres';

my $output_file = '/app/output/word_frequency_analysis.md';

# Connect to database
my $dbh = DBI->connect(
    "dbi:Pg:dbname=$db_name;host=$db_host",
    $db_user, $db_pass,
    { AutoCommit => 1, RaiseError => 1, pg_enable_utf8 => 1 }
) or die "Cannot connect: $DBI::errstr\n";

print "Connected to database.\n";
print "Generating report...\n\n";

# Open output file
open my $out, '>:encoding(UTF-8)', $output_file or die "Cannot create output: $!\n";

# Report metadata
my $date = strftime("%d %B %Y", localtime);
my $total_responses = $dbh->selectrow_array("SELECT COUNT(*) FROM responses");
my $total_words = $dbh->selectrow_array("SELECT COUNT(*) FROM word_frequency");
my $total_instances = $dbh->selectrow_array("SELECT SUM(total_count) FROM word_frequency");

# Header
print $out "# EU Open Digital Ecosystems Consultation\n\n";
print $out "## Word Frequency Analysis\n\n";
print $out "**Analysis Date:** $date\n\n";
print $out "**Corpus Statistics:**\n\n";
print $out "- Total responses analysed: $total_responses\n";
print $out "- Unique words: " . format_number($total_words) . "\n";
print $out "- Total word instances: " . format_number($total_instances) . "\n\n";

# Section 1: Top 50 Words
print $out "## Most Frequent Terms\n\n";
print $out "The 50 most frequently occurring terms across all consultation responses.\n\n";

my $top50 = $dbh->selectall_arrayref(q{
    SELECT word, total_count, document_count,
           ROUND(100.0 * document_count / (SELECT COUNT(*) FROM responses WHERE full_text IS NOT NULL), 1) as pct_docs
    FROM word_frequency
    ORDER BY total_count DESC
    LIMIT 50
});

# Build longtable
print $out "\\begin{longtable}{rlrrr}\n";
print $out "\\toprule\n";
print $out "Rank & Term & Occurrences & Documents & \\% Docs \\\\\n";
print $out "\\midrule\n";
print $out "\\endfirsthead\n\n";

print $out "\\multicolumn{5}{c}{{\\bfseries \\tablename\\ \\thetable{} -- continued from previous page}} \\\\\n";
print $out "\\toprule\n";
print $out "Rank & Term & Occurrences & Documents & \\% Docs \\\\\n";
print $out "\\midrule\n";
print $out "\\endhead\n\n";

print $out "\\midrule\n";
print $out "\\multicolumn{5}{r}{{Continued on next page}} \\\\\n";
print $out "\\endfoot\n\n";

print $out "\\bottomrule\n";
print $out "\\endlastfoot\n\n";

my $rank = 1;
foreach my $row (@$top50) {
    my ($word, $count, $docs, $pct) = @$row;
    printf $out "%d & %s & %s & %s & %.1f\\%% \\\\\n",
        $rank++, latex_escape($word), format_number($count), format_number($docs), $pct;
}

print $out "\\end{longtable}\n\n";

# Section 2: Domain-Specific Terms
print $out "## Domain-Specific Terminology\n\n";
print $out "Technical and policy vocabulary (terms longer than 8 characters appearing in at least 20 documents).\n\n";

my $domain = $dbh->selectall_arrayref(q{
    SELECT word, total_count, document_count,
           ROUND(100.0 * document_count / (SELECT COUNT(*) FROM responses WHERE full_text IS NOT NULL), 1) as pct_docs
    FROM word_frequency
    WHERE LENGTH(word) > 8
      AND document_count > 20
      AND word !~ '[0-9]'
    ORDER BY total_count DESC
    LIMIT 40
});

print $out "\\begin{longtable}{lrrr}\n";
print $out "\\toprule\n";
print $out "Term & Occurrences & Documents & \\% Docs \\\\\n";
print $out "\\midrule\n";
print $out "\\endfirsthead\n\n";

print $out "\\multicolumn{4}{c}{{\\bfseries \\tablename\\ \\thetable{} -- continued from previous page}} \\\\\n";
print $out "\\toprule\n";
print $out "Term & Occurrences & Documents & \\% Docs \\\\\n";
print $out "\\midrule\n";
print $out "\\endhead\n\n";

print $out "\\midrule\n";
print $out "\\multicolumn{4}{r}{{Continued on next page}} \\\\\n";
print $out "\\endfoot\n\n";

print $out "\\bottomrule\n";
print $out "\\endlastfoot\n\n";

foreach my $row (@$domain) {
    my ($word, $count, $docs, $pct) = @$row;
    printf $out "%s & %s & %s & %.1f\\%% \\\\\n",
        latex_escape($word), format_number($count), format_number($docs), $pct;
}

print $out "\\end{longtable}\n\n";

# Section 3: Distinctive Terms
print $out "## Distinctive Terms\n\n";
print $out "Terms with high concentration (appearing frequently but in fewer documents, indicating specialist usage).\n\n";

my $distinctive = $dbh->selectall_arrayref(q{
    SELECT word, total_count, document_count,
           ROUND(total_count::numeric / document_count, 1) as concentration,
           ROUND(100.0 * document_count / (SELECT COUNT(*) FROM responses WHERE full_text IS NOT NULL), 1) as doc_pct
    FROM word_frequency
    WHERE document_count >= 10
      AND document_count < (SELECT COUNT(*) FROM responses WHERE full_text IS NOT NULL) * 0.5
    ORDER BY concentration DESC
    LIMIT 30
});

print $out "\\begin{longtable}{lrrrr}\n";
print $out "\\toprule\n";
print $out "Term & Total Uses & Documents & Concentration & \\% Docs \\\\\n";
print $out "\\midrule\n";
print $out "\\endfirsthead\n\n";

print $out "\\multicolumn{5}{c}{{\\bfseries \\tablename\\ \\thetable{} -- continued from previous page}} \\\\\n";
print $out "\\toprule\n";
print $out "Term & Total Uses & Documents & Concentration & \\% Docs \\\\\n";
print $out "\\midrule\n";
print $out "\\endhead\n\n";

print $out "\\midrule\n";
print $out "\\multicolumn{5}{r}{{Continued on next page}} \\\\\n";
print $out "\\endfoot\n\n";

print $out "\\bottomrule\n";
print $out "\\endlastfoot\n\n";

foreach my $row (@$distinctive) {
    my ($word, $count, $docs, $conc, $pct) = @$row;
    printf $out "%s & %s & %s & %.1f & %.1f\\%% \\\\\n",
        latex_escape($word), format_number($count), format_number($docs), $conc, $pct;
}

print $out "\\end{longtable}\n\n";

# Section 4: Word Co-occurrences
my @cooccur_terms = (
    ['sovereignty', 'Sovereignty'],
    ['procurement', 'Procurement'],
    ['security', 'Security'],
    ['open-source', 'Open Source'],
    ['licensing', 'Licensing'],
    ['governance', 'Governance']
);

print $out "## Word Co-occurrences\n\n";
print $out "Terms that frequently appear together with key concepts, revealing related themes and discussion patterns.\n\n";

foreach my $term_pair (@cooccur_terms) {
    my ($term, $label) = @$term_pair;
    
    my $cooccur = $dbh->selectall_arrayref(qq{
        SELECT w2.word, COUNT(*) as co_occur,
               ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM response_words WHERE word = ?), 1) as pct
        FROM response_words w1
        JOIN response_words w2 ON w1.response_id = w2.response_id
        WHERE w1.word = ?
          AND w2.word != ?
          AND w2.word NOT IN (SELECT word FROM stopwords)
        GROUP BY w2.word
        ORDER BY COUNT(*) DESC
        LIMIT 20
    }, undef, $term, $term, $term);
    
    if (@$cooccur > 0) {
        print $out "### Terms Co-occurring with \"$label\"\n\n";
        
        print $out "\\begin{longtable}{lrr}\n";
        print $out "\\toprule\n";
        print $out "Term & Co-occurrences & \\% with " . latex_escape($label) . " \\\\\n";
        print $out "\\midrule\n";
        print $out "\\endfirsthead\n\n";
        
        print $out "\\multicolumn{3}{c}{{\\bfseries \\tablename\\ \\thetable{} -- continued from previous page}} \\\\\n";
        print $out "\\toprule\n";
        print $out "Term & Co-occurrences & \\% with " . latex_escape($label) . " \\\\\n";
        print $out "\\midrule\n";
        print $out "\\endhead\n\n";
        
        print $out "\\midrule\n";
        print $out "\\multicolumn{3}{r}{{Continued on next page}} \\\\\n";
        print $out "\\endfoot\n\n";
        
        print $out "\\bottomrule\n";
        print $out "\\endlastfoot\n\n";
        
        foreach my $row (@$cooccur) {
            my ($word, $count, $pct) = @$row;
            printf $out "%s & %s & %.1f\\%% \\\\\n",
                latex_escape($word), format_number($count), $pct;
        }
        
        print $out "\\end{longtable}\n\n";
    }
}

# Section 5: Country Distribution
print $out "## Response Distribution by Country\n\n";

my $countries = $dbh->selectall_arrayref(q{
    SELECT country, COUNT(*) as count
    FROM responses
    WHERE country IS NOT NULL AND country != ''
    GROUP BY country
    ORDER BY COUNT(*) DESC
    LIMIT 15
});

print $out "\\begin{longtable}{lr}\n";
print $out "\\toprule\n";
print $out "Country & Responses \\\\\n";
print $out "\\midrule\n";
print $out "\\endfirsthead\n\n";

print $out "\\multicolumn{2}{c}{{\\bfseries \\tablename\\ \\thetable{} -- continued from previous page}} \\\\\n";
print $out "\\toprule\n";
print $out "Country & Responses \\\\\n";
print $out "\\midrule\n";
print $out "\\endhead\n\n";

print $out "\\midrule\n";
print $out "\\multicolumn{2}{r}{{Continued on next page}} \\\\\n";
print $out "\\endfoot\n\n";

print $out "\\bottomrule\n";
print $out "\\endlastfoot\n\n";

foreach my $row (@$countries) {
    my ($country, $count) = @$row;
    printf $out "%s & %s \\\\\n", latex_escape($country), format_number($count);
}

print $out "\\end{longtable}\n\n";

# Section 6: Stakeholder Type Distribution
print $out "## Response Distribution by Stakeholder Type\n\n";

my $stakeholders = $dbh->selectall_arrayref(q{
    SELECT user_type, COUNT(*) as count
    FROM responses
    WHERE user_type IS NOT NULL AND user_type != ''
    GROUP BY user_type
    ORDER BY COUNT(*) DESC
});

print $out "\\begin{longtable}{lr}\n";
print $out "\\toprule\n";
print $out "Stakeholder Type & Responses \\\\\n";
print $out "\\midrule\n";
print $out "\\endfirsthead\n\n";

print $out "\\multicolumn{2}{c}{{\\bfseries \\tablename\\ \\thetable{} -- continued from previous page}} \\\\\n";
print $out "\\toprule\n";
print $out "Stakeholder Type & Responses \\\\\n";
print $out "\\midrule\n";
print $out "\\endhead\n\n";

print $out "\\midrule\n";
print $out "\\multicolumn{2}{r}{{Continued on next page}} \\\\\n";
print $out "\\endfoot\n\n";

print $out "\\bottomrule\n";
print $out "\\endlastfoot\n\n";

foreach my $row (@$stakeholders) {
    my ($type, $count) = @$row;
    printf $out "%s & %s \\\\\n", latex_escape($type), format_number($count);
}

print $out "\\end{longtable}\n\n";

close $out;
$dbh->disconnect;

print "Report generated: $output_file\n";
print "Convert to PDF: pandoc -f markdown -o output.pdf $output_file\n";

sub format_number {
    my $num = shift;
    return '' unless defined $num;
    
    # Add thousand separators
    my $formatted = reverse $num;
    $formatted =~ s/(\d{3})(?=\d)/$1,/g;
    return scalar reverse $formatted;
}

sub latex_escape {
    my $text = shift;
    return '' unless defined $text;
    
    # Escape LaTeX special characters
    $text =~ s/\\/\\textbackslash{}/g;
    $text =~ s/([&%\$#_\{\}])/\\$1/g;
    $text =~ s/~/\\textasciitilde{}/g;
    $text =~ s/\^/\\textasciicircum{}/g;
    
    return $text;
}
