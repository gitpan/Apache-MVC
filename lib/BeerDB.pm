package BeerDB;
use base 'Apache::MVC';
use Class::DBI::Loader::Relationship;
# This line is required if you don't have Apache calling Perl handlers
# as methods.
sub handler { Apache::MVC::handler(__PACKAGE__, @_) }

# This is the sample application. Change this to the path to your
# database. (or use mysql or something)
BeerDB->set_database("dbi:SQLite:t/beerdb.db");

# Change this to the root of the web space.
BeerDB->config->{uri_base} = "http://localhost/beerdb/";

BeerDB->config->{rows_per_page} = 10;

# Handpumps should not show up.
BeerDB->config->{display_tables} = [qw[beer brewery pub style]];
BeerDB::Brewery->untaint_columns( printable => [qw/name notes url/] );
BeerDB::Style->untaint_columns( printable => [qw/name notes/] );
BeerDB::Beer->untaint_columns(
    printable => [qw/abv name price notes/],
    integer => [qw/style brewery score/],
    date =>[ qw/date/],
);
BeerDB->config->{loader}->relationship($_) for (
    "a brewery produces beers",
    "a style defines beers",
    "a pub has beers on handpumps");
1;
