use 5.006;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Apache::MVC',
    VERSION_FROM      => 'lib/Apache/MVC.pm', # finds $VERSION
    PREREQ_PM         => {
        Class::DBI::Loader => 0,
        Class::DBI::AbstractSearch => 0,
        Class::DBI::Pager => 0,
        Class::DBI::Plugin::RetrieveAll => 0,
        Class::DBI::AsForm => 0,
        Class::DBI::FromCGI => 0,
        Class::DBI::Loader::Relationship => 0,
        CGI::Untaint => 0,
        UNIVERSAL::moniker => 0,
        UNIVERSAL::require => 0,
        Apache::Request => 0,
        Template => 0,
    }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Apache/MVC.pm', # retrieve abstract from module
       AUTHOR         => 'Simon Cozens <simon@nonet>') : ()),
);

if (!-e "t/beerdb.db") {
    print "Making SQLite DB\n";
    require DBD::SQLite 
        or die "No, wait, we don't have SQLite installed. Never mind\n";
    require DBI;
    my $dbh = DBI->connect("dbi:SQLite:dbname=t/beerdb.db");

    my $sql = join ( '', (<DATA>) );

    for my $statement (split /;/, $sql) {
        $statement =~ s/\#.*$//mg; # strip # comments
        $statement =~ s/auto_increment//g;
        next unless $statement =~ /\S/;
        eval { $dbh->do($statement) };
        die "$@: $statement" if $@;
    }
}

__DATA__

create table brewery (
    id int not null auto_increment primary key,
    name varchar(30),
    url varchar(50),
    notes text
);

create table beer (
    id int not null auto_increment primary key,
    brewery integer,
    style integer, 
    name varchar(30),
    url varchar(120),
#    tasted date,
    score integer(2),
    price varchar(12),
    abv varchar(10),
    notes text
);

create table handpump (
    id int not null auto_increment primary key,
    beer integer,
    pub integer
);

create table pub (
    id int not null auto_increment primary key,
    name varchar(60),
    url varchar(120),
    notes text
);

INSERT INTO beer (id, brewery, name, abv) VALUES
    (1, 1, "Organic Best Bitter", "4.1");
INSERT INTO brewery (id, name, url) VALUES
    (1, "St Peter's Brewery", "http://www.stpetersbrewery.co.uk/");
INSERT INTO pub (id, name) VALUES (1, "Turf Tavern");
INSERT INTO handpump (id, pub, beer) VALUES (1, 1,1);

