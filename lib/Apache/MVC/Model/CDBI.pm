package Apache::MVC::Model::CDBI;
use base qw(Apache::MVC::Model::Base Class::DBI);
use Lingua::EN::Inflect::Number qw(to_PL);
use Class::DBI::AsForm;
use Class::DBI::FromCGI;
use Class::DBI::AbstractSearch;
use Class::DBI::Plugin::RetrieveAll;
use Class::DBI::Pager;
use CGI::Untaint;
use strict;

=head1 NAME

Apache::MVC::Model::CDBI - Model class based on Class::DBI

=head1 DESCRIPTION

This is a master model class which uses C<Class::DBI> to do all the hard
work of fetching rows and representing them as objects. It is a good
model to copy if you're replacing it with other database abstraction
modules.

=cut

sub related {
    my ($self, $r) = @_;
    # Has-many methods; XXX this is a hack
    map {to_PL($_)} 
    grep { exists $r->{config}{ok_tables}{$_} }
    map {$_->table}
    keys %{shift->__hasa_list || {}}
}

sub do_edit :Exported {
    my ($self, $r) = @_;
    my $h = CGI::Untaint->new(%{$r->{params}});
    my ($obj) = @{$r->objects};
    if ($obj) {
        # We have something to edit
        $obj->update_from_cgi($h);
        warn "Updating an object ($obj) with ".Dumper($h); use Data::Dumper;
    } else {
        $obj = $self->create_from_cgi($h);
    }
    if (my %errors = $obj->cgi_update_errors) {
        # Set it up as it was:
        warn "There were errors: ".Dumper(\%errors)."\n";
        $r->{template_args}{cgi_params} = $r->{params};
        $r->{template_args}{errors} = \%errors;
        $r->{template} = "edit";
    } else {
        $r->{template} = "view";
    }
    $r->objects([ $obj ]);
}

sub delete :Exported {
    my ($self, $r) = @_;
    $_->SUPER::delete for @{ $r->objects };
    $r->objects([ $self->retrieve_all ]);
    $r->{template} = "list";
}

sub adopt {
    my ($self, $child) = @_;
    $child->autoupdate(1);
    $child->columns( Stringify => qw/ name / );
}

sub search :Exported {
    return shift->SUPER::search(@_) if caller eq "Class::DBI"; # oops
    my ($self, $r) = @_;
    my %fields = map {$_ => 1 } $self->columns;
    my $oper = "like"; # For now
    use Carp; Carp::confess("Urgh") unless ref $r;
    my %params = %{$r->{params}};
    my %values = map { $_ => {$oper, $params{$_} } }
                 grep { $params{$_} and $fields{$_} } keys %params;

    $r->objects([ %values ? $self->search_where(%values) : $self->retrieve_all ]);
    $r->template("list");
    $r->{template_args}{search} = 1;
}

sub list :Exported {
    my ($self, $r) = @_;
    my %ok_columns = map {$_ => 1} $self->columns;
    if ( my $rows = $r->config->{rows_per_page}) {
        $self = $self->pager($rows, $r->query->{page});
        $r->{template_args}{pager} = $self;
    } 
    my $order;
    if ($order = $r->query->{order} and $ok_columns{$order}) {
        $r->objects([ $self->retrieve_all_sorted_by( $order.
            ($r->query->{o2} eq "desc" && " DESC")
        )]);
    } else {
        $r->objects([ $self->retrieve_all ]);
    }
}
1;

