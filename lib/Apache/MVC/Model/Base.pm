package Apache::MVC::Model::Base;
our %remember;
sub MODIFY_CODE_ATTRIBUTES { $remember{$_[1]} = $_[2]; () }

sub FETCH_CODE_ATTRIBUTES { $remember{$_[1]} } 
sub view :Exported { }
sub edit :Exported { }

sub list :Exported {
    my ($self, $r) = @_;
    $r->objects([ $self->retrieve_all ]);
}

sub process {
    my ($class, $r) = @_;
    $r->template( my $method = $r->action );
    $r->objects([ $class->retrieve(shift @{$r->{args}}) ]);
    $class->$method($r);
}

=head1 NAME

Apache::MVC::Model::Base - Base class for model classes

=head1 DESCRIPTION

Anyone subclassing this for a different database abstraction mechanism
needs to provide the following methods:

=head2 do_edit

If there is an object in C<$r-E<gt>objects>, then it should be edited
with the parameters in C<$r-E<gt>params>; otherwise, a new object should
be created with those parameters, and put back into C<$r-E<gt>objects>.
The template should be changed to C<view>, or C<edit> if there were any
errors. A hash of errors will be passed to the template.

=cut

sub do_edit { die "This is an abstract method" }

=head2 retrieve

This turns an ID into an object of the appropriate class.

=head2 adopt

This is called on an model class representing a table and allows the
master model class to do any set-up required. 

=head2 related

This can go either in the master model class or in the individual
classes, and returns a list of has-many accessors. A brewery has many
beers, so C<BeerDB::Brewery> needs to return C<beers>.

=head2 columns

This is a list of the columns in a table.

=head2 table

This is the name of the table.

=head2 Commands

See the exported commands in C<Apache::MVC::Model::CDBI>.

=head1 Other overrides

Additionally, individual derived model classes may want to override the
following methods:

=head2 column_names

Return a hash mapping column names with human-readable equivalents.

=cut

sub column_names { my $class = shift; map { $_ => ucfirst $_ } $class->columns }

=head2 description

A description of the class to be passed to the template.

=cut

sub description { "A poorly defined class" }

1;

