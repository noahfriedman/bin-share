#!/usr/bin/env perl
# ph --- ldap phonebook search

# Author: Noah Friedman <friedman@splode.com>
# Created: 2012-09-28
# Public domain.

# $Id$

use Net::LDAP;
use Getopt::Long;
use strict;

$^W = 1;

my %opt =
  ( host    => "ldap",
    scope   => 'sub',
    onerror => 'die',
  );

# Display ldap attributes with optional different lable.
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

sub parse_options
{
  local *ARGV = \@{$_[0]}; # modify our local arglist, not real ARGV.

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

sub basedn
{
  map { return $_ unless $_ eq "o=netscaperoot"
      } $_[0]->root_dse->get_value ("namingContexts");
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

      map { my $key = $remap{$_} || $_;
            my $val = $entry->get_value ($_);
            $node{$key} = $val if defined $val;
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

sub main
{
  parse_options (\@_);
  my $ldap = Net::LDAP->new ($opt{host}, %opt) || die "$@\n";
  $ldap->bind ($opt{bind}, %opt) if defined $opt{bind};

  $opt{filter} = make_filter (@_);
  $opt{attrs}  = [map { $_->[0] } @attrmap];
  $opt{base}   = basedn ($ldap) unless defined $opt{base};

  result_print ($ldap->search (%opt));
}

main (@ARGV);

1;
