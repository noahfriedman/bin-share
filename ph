#!/usr/bin/env perl
# ph --- ldap phonebook search

# Author: Noah Friedman <friedman@splode.com>
# Created: 2012-09-28
# Public domain.

# $Id: ph,v 1.6 2017/06/08 18:51:54 friedman Exp $

use Net::LDAP;
use Getopt::Long;
use strict;

$^W = 1;

our %opt = ( host    => "ldap",
             scope   => 'sub',
             onerror => 'die',
             verify  => 'none',
           );

# Display ldap attributes with optional different label.
# This also controls the order in which fields are displayed.
my @attrmap =
  ([cn                          => 'name'         ],
   [title                       =>                ],
   [ou                          => 'organization' ],
   [businesscategory            => 'division'     ],
   [manager                     =>                ],
   [mail                        => 'email'        ],

   [telephonenumber             => 'work'         ],
   [homephone                   => 'home'         ],
   [mobile                      => 'cell'         ],
   [pager                       =>                ],
   [faxnumber                   => 'fax'          ],
   [facsimiletelephonenumber    => 'fax'          ],

   [departmentnumber            => 'dept'         ],
   [physicaldeliveryofficename  => 'mailstop'     ],
   [roomnumber                  => 'location'     ],
   [carlicense                  =>                ],
   [description                 =>                ],
  );

my %attrtrans;
my $max_attrlen = 0;

my @search_attr = (qw(cn sn telephonenumber pager mobile));

my %format_attr =
  ( telephonenumber             => \&format_phone,
    homephone                   => \&format_phone,
    mobile                      => \&format_phone,
    pager                       => \&format_phone,
    faxnumber                   => \&format_phone,
    facsimiletelephonenumber    => \&format_phone,
  );

sub maxlen
{
  shift while @_ && !defined $_[0];
  return unless @_;

  my $max = length $_[0];
  map { if (defined $_)
          {
            my $l = length $_;
            $max = $l if $l > $max;
          }
      } @_;
  return $max;
}

# Query server to find out what directory roots are available, and if more
# than one, use hostname's fqdn to guess most likely relevant one.
sub baseDN
{
  my @nc = $_[0]->root_dse->get_value ("namingContexts");
  map { return $_ unless lc $_ eq "o=netscaperoot" } @nc if @nc <= 2;

  use POSIX qw(uname);
  my $nodename = (uname())[1];
  unless ($nodename =~ /\./) { # try to get FQDN
    my @n = gethostbyname ($nodename);
    if (@n) {
      for my $h ($n[0], split (/\s+/, $n[1])) {
        if ($h =~ /\./) {
          $nodename = $h;
          last;
        }
      }
    }
  }
  my @dc = split (/\./, lc $nodename);
  # Create "normalized" table by forcing lcase and stripping whitespace
  my %nc = map { my $key = lc $_;
                 $key =~ s/\s+//g;
                 $key => $_ ;
               } @nc;
  # Search for "dc=foo,dc=com" and "o=foo.com"
  map { map { return $nc{$_} if exists $nc{$_}
            } (join (",", map { "dc=$_" } @dc),
               "o=" . join (".", @dc));
        shift @dc;
      } @dc;

  return @nc[0]; # if all else fails, return first advertised.
}

sub make_filter
{
  my @f;
  map { if (/^\((.*)\)$/) { push @f, $1 }
        elsif (! /=/)     { push @f, "uid=" . $_;
                            my $arg = $_;
                            push @f, map { "$_=*$arg*" } @search_attr;
                          }
        else              { push @f, $_ }
      } @_;
  sprintf ("(|%s)", join ("", map { "($_)" } @f));
}

# Some ad-hoc reformatting for ease of reading.
sub format_phone
{
  local $_ = $_[1];

  s/[.-\s\(\)]*//g;

  return "+44 $1 $2" if /^(?:011)?(?:44)?0?(118\d)(\d{6})$/; # UK; bad p4 ldap formatting

  return  "+1 $1 $2 $3"           if /^1?(\d{3})(\d{3})(\d{4})$/; # US
  return  "+$1 $2 $3"             if /^(?:011|\+)?(44)(\d{4})(\d{4,6})$/; # UK
  return  "+$1 $2 $3 $4 $5 $6 $7" if /^(?:011|\+)?(33)(\d)(\d\d)(\d\d)(\d\d)(\d\d)$/; # FR

  return  "+$1 $2 $3 $4" if /^(?:011|\+)?(61)0?(4\d\d)(\d{3})(\d{3})$/; # AU mobile
  return  "+$1 $2 $3 $4" if /^(?:011|\+)?(61)0?(\d)(\d{4})(\d{4})$/; # AU

  return $_[1];
}

sub result_format
{
  my $result = shift;

  my @result_entries = $result->entries;
  return unless @result_entries;

  my %remap;
  map { my ($from, $to) = @$_;
        $remap{$from} = $to if defined $to;
      } @attrmap;

  my @entry;
  for my $entry (@result_entries)
    {
      my %node;
      $node{dn} = $entry->dn;

      map { my $elt = lc $_;
            my $val = $entry->get_value ($_);
            if (defined $val)
              {
                my $fmtfn = $format_attr{$elt};
                $val = &$fmtfn ($elt, $val) if ref $fmtfn eq 'CODE';
                $node{$remap{$elt} || $elt} = $val;
              }
          } $entry->attributes;
      push @entry, \%node;
    }
  return \@entry;
}

sub result_print
{
  my $result = shift;
  my $entry = result_format ($result);
  return unless defined $entry;

  my @attr = map { $_->[1] || $_->[0] } @attrmap;
  my $w0 = maxlen (map { keys %$_ } @$entry);
  my $fmt = "%${w0}s  %s\n";

  for my $ent (@$entry)
    {
      map { my $val = $ent->{$_};
            printf $fmt, $_, $val if defined $val;
          } @attr;
      print "\n";
    }
}

sub parse_options
{
  local *ARGV = \@{$_[0]}; # modify our local arglist, not real ARGV.

  # Precedence for defs (highest->lowest): options, rc file, default
  my @rc = ($ENV{MLDAPSEARCHRC},
            (defined $ENV{XDG_CONFIG_HOME}
             ? "$ENV{XDG_CONFIG_HOME}/mldapsearch.conf"
             : ()),
            "$ENV{HOME}/.mldapsearchrc");
  # The reason for these machinations is to avoid creating a new scoping
  # block in which the rc file is read.
  map { (do $_, goto readrc) if defined $_ && -f $_ } @rc;
 readrc:

  my $parser = Getopt::Long::Parser->new;
  $parser->configure (qw(bundling autoabbrev));
  my $succ = $parser->getoptions
    ( "b|root|base=s"  => \$opt{base},
      "h|host=s",      => \$opt{host},
      "D|bind=s",      => \$opt{bind},
      "w|pswd|pass=s", => \$opt{password},
      "p|port=s",      => \$opt{port},
    );
}

sub main
{
  parse_options (\@_);
  my $ldap = Net::LDAP->new ($opt{host}, %opt) || die "$@\n";
  $ldap->bind ($opt{bind}, %opt) if defined $opt{bind};

  $opt{filter} = make_filter (@_);
  $opt{attrs}  = [map { $_->[0] } @attrmap];
  $opt{base}   = baseDN ($ldap) unless defined $opt{base};

  result_print ($ldap->search (%opt));
}

main (@ARGV);

1;
