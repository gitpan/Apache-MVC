package Apache::MVC;
use base qw(Class::Accessor Class::Data::Inheritable);
use attributes ();
use Class::DBI::Loader;
use UNIVERSAL::require;
use Apache::Constants ":common";
use strict;
use warnings;
our $VERSION = "0.2";
__PACKAGE__->mk_classdata($_) for qw( _config init_done view_object );
__PACKAGE__->mk_accessors ( qw( config ar params query objects model_class
args action template ));
__PACKAGE__->config({});
__PACKAGE__->init_done(0);


sub import {
    my $real = shift;
    if ($real ne "Apache::MVC") {
        no strict 'refs';
        *{$real."::handler"} = sub { Apache::MVC::handler($real, @_) };
    }
}

# This is really dirty.
sub config {
    my $self = shift;
    if (ref $self) { return $self->_config_accessor(@_) }
    return $self->_config(@_);
}

sub set_database {
    my ($calling_class, $dsn) = @_;
    $calling_class = ref $calling_class if ref $calling_class;
    my $config = $calling_class->config;
    $config->{model} ||= "Apache::MVC::Model::CDBI";
    $config->{model}->require;
    $config->{dsn} = $dsn;
    $config->{loader} = Class::DBI::Loader->new(
        namespace => $calling_class,
        dsn => $dsn
    ); 
    $config->{classes} = [ $config->{loader}->classes ];
    for my $subclass (@{$config->{classes}}) {
        no strict 'refs';
        unshift @{$subclass."::ISA"}, $config->{model};
        $config->{model}->adopt($subclass)
           if $config->{model}->can("adopt");
    }
}

sub init {
    my $class = shift;
    my $config = $class->config;
    $config->{view}  ||= "Apache::MVC::View::TT";
    $config->{view}->require;
    $config->{display_tables} ||= [ $class->config->{loader}->tables ];
    $class->view_object($class->config->{view}->new);
    $class->init_done(1);

}

sub class_of {
    my ($self, $table) = @_;
    return $self->config->{loader}->_table2class($table);
}

sub handler {
    # See Apache::MVC::Workflow before trying to understand this.
    my $class = shift;
    $class->init unless $class->init_done;
    my $r = bless { config => $class->config }, $class;
    $r->get_request();
    $r->parse_location();

    $r->model_class($r->class_of($r->{table}));
    my $status = $r->is_applicable;
    if ($status == OK) { 
        $status = $r->call_authenticate;
        return $status unless $status == OK;
        $r->additional_data();
    
        $r->model_class->process($r);
    } else { 
        # Otherwise, it's just a plain template.
        delete $r->{model_class};
        $r->{path} =~ s{/}{}; # De-absolutify
        $r->template($r->{path});
    }
    return $r->view_object->process($r);
}

sub get_request {
    my $self = shift;
    require Apache; require Apache::Request; 
    $self->{ar} = Apache::Request->new(Apache->request);
}

sub parse_location {
    my $self = shift;
    $self->{path} = $self->{ar}->uri;
    my $loc = $self->{ar}->location;
    $self->{path} =~ s/^$loc//; # I shouldn't need to do this?
    $self->{path} ||= "frontpage";
    my @pi = split /\//, $self->{path};
    shift @pi while @pi and !$pi[0];
    $self->{table} = shift @pi;
    $self->{action} = shift @pi;
    $self->{args} = \@pi;

    $self->{params} = { $self->{ar}->content };
    $self->{query}  = { $self->{ar}->args };
}

sub is_applicable {
    my $self = shift;
    my $config = $self->config;
    $config->{ok_tables} = {map {$_ => 1} @{$config->{display_tables}}};
    warn "We don't have that table ($self->{table})"
        unless $config->{ok_tables}{$self->{table}};
    return DECLINED() unless exists $config->{ok_tables}{$self->{table}};

    # Does the action method exist?
    my $cv = $self->model_class->can($self->{action});
    warn "We don't have that action ($self->{action})" unless $cv;
    return DECLINED() unless $cv;

    # Is it exported?
    $self->{method_attribs} = join " ", attributes::get($cv);
    do { warn "$self->{action} not exported";
    return DECLINED() 
     } unless $self->{method_attribs} =~ /\bExported\b/i;
    return OK();
}

sub call_authenticate {
    my $self = shift;
    return $self->model_class->authenticate($self) if 
        $self->model_class->can("authenticate");
    return $self->authenticate();
}

sub additional_data {}

sub authenticate { return OK }

1;

=head1 NAME

Apache::MVC - Web front end to a data source

=head1 SYNOPSIS

    package BeerDB;
    use base 'Apache::MVC';
    sub handler { Apache::MVC::handler("BeerDB", @_) }
    BeerDB->set_database("dbi:mysql:beerdb");
    BeerDB->config->{uri_base} = "http://your.site/";
    BeerDB->config->{display_tables} = [qw[beer brewery pub style]];
    # Now set up your database:
    # has-a relationships
    # untaint columns

    1;

=head1 DESCRIPTION

A large number of web programming tasks follow the same sort of pattern:
we have some data in a datasource, typically a relational database. We
have a bunch of templates provided by web designers. We have a number of
things we want to be able to do with the database - create, add, edit,
delete records, view records, run searches, and so on. We have a web
server which provides input from the user about what to do. Something in
the middle takes the input, grabs the relevant rows from the database,
performs the action, constructs a page, and spits it out.

This module aims to be the most generic and extensible "something in the
middle".

An example would help explain this best. You need to add a product
catalogue to a company's web site. Users need to list the products in
various categories, view a page on each product with its photo and
pricing information and so on, and there needs to be a back-end where
sales staff can add new lines, change prices, and delete out of date
records. So, you set up the database, provide some default templates
for the designers to customize, and then write an Apache handler like
this:

    package ProductDatabase;
    use base 'Apache::MVC';
    __PACKAGE__->set_database("dbi:mysql:products");
    BeerDB->config->{uri_base} = "http://your.site/catalogue/";
    ProductDatabase::Product->has_a("category" => ProductDatabase::Category); 
    # ...

    sub authenticate {
        my ($self, $request) = @_;
        return OK if $request->{ar}->get_remote_host() eq "sales.yourcorp.com";
        return OK if $request->{action} =~ /^(view|list)$/;
        return DECLINED;
    }
    1;

You then put the following in your Apache config:

    <Location /catalogue>
        SetHandler perl-script
        PerlHandler ProductDatabase
    </Location>

And copy the templates found in F<templates/factory> into the
F<catalogue/factory> directory off the web root. When the designers get
back to you with custom templates, they are to go in
F<catalogue/custom>. If you need to do override templates on a
database-table-by-table basis, put the new template in
F<catalogue/I<table>>. 

This will automatically give you C<add>, C<edit>, C<list>, C<view> and
C<delete> commands; for instance, a product list, go to 

    http://your.site/catalogue/product/list

For a full example, see the included "beer database" application.

=head1 HOW IT WORKS

There's some documentation for the workflow in L<Apache::MVC::Workflow>,
but the basic idea is that a URL part like C<product/list> gets
translated into a call to C<ProductDatabase::Product-E<gt>list>. This
propagates the request with a set of objects from the database, and then 
calls the C<list> template; first, a C<product/list> template if it
exists, then the C<custom/list> and finally C<factory/list>. 

If there's another action you want the system to do, you need to either
subclass the model class, and configure your class slightly differently:

    package ProductDatabase::Model;
    use base 'Apache::MVC::Model::CDBI';

    sub supersearch :Exported {
        my ($self, $request) = @_;
        # Do stuff, get a bunch of objects back
        $r->objects(\@objects);
        $r->template("template_name");
    }

    ProductDatabase->config->{model_class} = "ProductDatabase::Model";

(The C<:Exported> attribute means that the method can be called via the
URL C</I<table>/supersearch/...>.)

Alternatively, you can put the method directly into the specific model
class for the table:

    sub ProductDatabase::Product::supersearch :Exported { ... }

By default, the view class uses Template Toolkit as the template
processor, and the model class uses C<Class::DBI>; it may help you to be
familiar with these modules before going much further with this,
although I expect there to be other subclasses for other templating
systems and database abstraction layers as time goes on. The article at
C<http://www.perl.com/pub/a/2003/07/15/nocode.html> is a great
introduction to the process we're trying to automate.

=head1 AUTHOR

Simon Cozens, C<simon@cpan.org>

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.
