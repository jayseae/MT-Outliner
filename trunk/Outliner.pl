# ===========================================================================
# MT-Outliner: Access information from OPML files through template tags.
# A Plugin for Movable Type
#
# Release 1.3.0
# February 21, 2004
#
# http://jayseae.cxliv.org/outliner/
# http://www.amazon.com/o/registry/2Y29QET3Y472A/
#
# If you find the software useful or even like it, then a simple 'thank you'
# is always appreciated.  A reference back to me is even nicer.  If you find
# a way to make money from the software, do what you feel is right.
#
# Copyright 2003-2004, Chad Everett (software@jayseae.cxliv.org)
# Licensed under the Open Software License version 2.1
# ===========================================================================
package MT::Plugin::Outliner;

use vars qw($VERSION);
$VERSION = '1.3.0';

use strict;

use MT::Template::Context;
use MT::Util qw( format_ts );

MT::Template::Context->add_container_tag( Outliner => \&Outliner );
MT::Template::Context->add_tag( OutlinerBloglines => \&ReturnValue );
MT::Template::Context->add_tag( OutlinerDataSource => \&ReturnValue );
MT::Template::Context->add_tag( OutlinerDateCreated => \&ReturnDate );
MT::Template::Context->add_tag( OutlinerDateModified => \&ReturnDate );
MT::Template::Context->add_tag( OutlinerOPMLVersion => \&ReturnValue );
MT::Template::Context->add_tag( OutlinerOwnerName => \&ReturnValue );
MT::Template::Context->add_tag( OutlinerOwnerEmail => \&ReturnValue );
MT::Template::Context->add_tag( OutlinerTitle => \&ReturnValue );
MT::Template::Context->add_tag( OutlinerXMLVersion => \&ReturnValue );

MT::Template::Context->add_container_tag( OutlinerFolders => \&OutlinerFolders );
MT::Template::Context->add_conditional_tag( OutlinerFolderIfItems => \&ReturnValue );
MT::Template::Context->add_conditional_tag( OutlinerFolderIfNoItems => \&ReturnValue );
MT::Template::Context->add_conditional_tag( OutlinerFolderFiled => \&ReturnValue );
MT::Template::Context->add_conditional_tag( OutlinerFolderUnfiled => \&ReturnValue );
MT::Template::Context->add_tag( OutlinerFolderText => \&ReturnValue );
MT::Template::Context->add_tag( OutlinerFolderItemCount => \&ReturnValue );

MT::Template::Context->add_container_tag( OutlinerItems => \&OutlinerItems );
MT::Template::Context->add_tag( OutlinerItemText => \&ReturnValue );
MT::Template::Context->add_tag( OutlinerItemDesc => \&ReturnValue );
MT::Template::Context->add_tag( OutlinerItemHTML => \&ReturnValue );
MT::Template::Context->add_tag( OutlinerItemXML => \&ReturnValue );

sub Outliner {
  my ( $ctx, $args, $cond ) = @_;
  my $builder = $ctx->stash( 'builder' );
  my $tokens = $ctx->stash( 'tokens' );
  my $notfound = $args->{notfound} || 'Not Found';
  $ctx->stash( 'outlinernotfound', $notfound );
  my $res = '';
  my $dat;  
  my $url;

  if ( $args->{bloglines} ) {
    $ctx->stash( 'outlinerbloglines', $args->{bloglines} );
    $url = "http://www.bloglines.com/export?id=$args->{bloglines}";
    $dat = _load_link ( $url );
  } elsif ( $args->{opmllink} ) {
    $ctx->stash( 'outlinerbloglines', $notfound );
    $url = $args->{opmllink};
    $dat = _load_link ( $url );
  } elsif ( $args->{opmlpath} ) {
    $ctx->stash( 'outlinerbloglines', $notfound );
    $url = $args->{opmlpath};
    $dat = _load_path ( $url );
  }

  $dat =~ s|\x0d|\x0a|g;
  $dat =~ s|\x0a+|\x0a|g;
  $dat =~ s|([^>])\x0a|$1 |g;
  $ctx->stash( 'outlinercontent', $dat );
  $ctx->stash( 'outlinerdatasource', $url );
  $ctx->stash( 'outlinerxmlversion', ( $dat =~ m|xml version="([1-9][0-9.]*)"| ) );
  $ctx->stash( 'outlinerxmlversion', $notfound ) unless $ctx->stash( 'outlinerxmlversion' );
  $ctx->stash( 'outlineropmlversion', ( $dat =~ m|opml version="([1-9][0-9.]*)"| ) );
  $ctx->stash( 'outlineropmlversion', $notfound ) unless $ctx->stash( 'outlineropmlversion' );
  $ctx->stash( 'outlinertitle', ( $dat =~ m|<title>(.*)</title>| ) );
  $ctx->stash( 'outlinertitle', $notfound ) unless $ctx->stash( 'outlinertitle' );
  $ctx->stash( 'outlinerownername', ( $dat =~ m|<ownerName>(.*)</ownerName>| ) );
  $ctx->stash( 'outlinerownername', $notfound ) unless $ctx->stash( 'outlinerownername' );
  $ctx->stash( 'outlinerowneremail', ( $dat =~ m|<ownerEmail>(.*)</ownerEmail>| ) );
  $ctx->stash( 'outlinerowneremail', $notfound ) unless $ctx->stash( 'outlinerowneremail' );
  $ctx->stash( 'outlinerdatecreated', $notfound );
  $ctx->stash( 'outlinerdatemodified', $notfound );

  if ( $dat =~ m|<dateCreated>(.*)</dateCreated>| ) {
    my ( $dc_dd, $dc_mmm, $dc_yyyy, $dc_hh, $dc_mm, $dc_ss ) = ( $1 =~ m|\w{3}, (\d{1,2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2})| );
    $ctx->stash( 'outlinerdatecreated', $dc_yyyy . _find_month( $dc_mmm ) . sprintf( "%02d", $dc_dd ) . $dc_hh . $dc_mm . $dc_ss );
  } elsif ( $dat =~ m|<pubDate>(.*)</pubDate>| ) {
    my ( $dc_dd, $dc_mmm, $dc_yyyy, $dc_hh, $dc_mm, $dc_ss ) = ( $1 =~ m|\w{3}, (\d{1,2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2})| );
    $ctx->stash( 'outlinerdatecreated', $dc_yyyy . _find_month( $dc_mmm ) . sprintf( "%02d", $dc_dd ) . $dc_hh . $dc_mm . $dc_ss );
  }

  if ( $dat =~ m|<dateModified>(.*)</dateModified>| ) {
    my ( $dm_dd, $dm_mmm, $dm_yyyy, $dm_hh, $dm_mm, $dm_ss ) = ( $1 =~ m|\w{3}, (\d{1,2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2})| );
    $ctx->stash( 'outlinerdatemodified', $dm_yyyy . _find_month( $dm_mmm ) . sprintf( "%02d", $dm_dd ) . $dm_hh . $dm_mm . $dm_ss );
  } elsif ( $dat =~ m|<lastBuildDate>(.*)</lastBuildDate>| ) {
    my ( $dm_dd, $dm_mmm, $dm_yyyy, $dm_hh, $dm_mm, $dm_ss ) = ( $1 =~ m|\w{3}, (\d{1,2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2})| );
    $ctx->stash( 'outlinerdatemodified', $dm_yyyy . _find_month( $dm_mmm ) . sprintf( "%02d", $dm_dd ) . $dm_hh . $dm_mm . $dm_ss );
  }

  my $out = $builder->build( $ctx, $tokens );
  return $ctx->error( $builder->errstr ) unless defined $out;
  $res .= $out;
}

sub OutlinerFolders {
  my ( $ctx, $args, $cond ) = @_;
  my $builder = $ctx->stash( 'builder' );
  my $tokens = $ctx->stash( 'tokens' );
  my ( $res, $skipfirst ) = ( '', 0 );
  my $folders = {};
  my @content;

  $skipfirst = 1 if ( $ctx->stash( 'outlinerbloglines' ) && $ctx->stash( 'outlinerbloglines' ) ne $ctx->stash( 'outlinernotfound' ) );

  @content = split ( /\x0a/, $ctx->stash( 'outlinercontent' ) );
  push ( @content, '<outline text="Unfiled">' ) if $args->{unfiled};
  foreach my $content ( @content ) {
    my $use_folder = 0;
    $content =~ s|^[\s]*||;
    next unless ( $content =~ m|^<[/]?outline| );
    if ( $content =~ m|^<outline| ) {
      if ( $content =~ m|^<outline text="(.*)">| || $content =~ m|^<outline title="(.*)">| ) {
        if ( $skipfirst ) {
          $skipfirst = 0;
          next;
        }
        my $folder = $1;
        if ( $args->{folders} ) {
          my @folders = split( /:/, $args->{folders} );
          foreach my $check_folder ( @folders ) {
            if ( $folder eq $check_folder ) {
              if ( !$folders->{$folder} ) {
                $ctx->stash( 'outlinerfoldertext', $folder );
                $folders->{$folder} = 1;
                $use_folder = 1;
              }
            }
          }
        } else {
          $ctx->stash( 'outlinerfoldertext', $folder );
          $use_folder = 1;
        }
      } else {
        next;
      }
    } else {
      next;
    }
    if ( $use_folder ) {
      my $folder = $ctx->stash( 'outlinerfoldertext' );
      my $items = _get_items ( $ctx );
      $ctx->stash( 'outlinerfolderitems', \@$items );
      $ctx->stash( 'outlinerfolderitemcount', scalar @$items );
      $ctx->stash( 'outlinerfolderifitems', scalar @$items );
      $ctx->stash( 'outlinerfolderifnoitems', !(scalar @$items) );
      $ctx->stash( 'outlinerfolderfiled', !( $folder eq 'Unfiled' ) );
      $ctx->stash( 'outlinerfolderunfiled', ( $folder eq 'Unfiled' ) );
      my $out = $builder->build( $ctx, $tokens );
      return $ctx->error( $builder->errstr ) unless defined $out;
      $res .= $out;
    }
  }
  $res;
}

sub OutlinerItems {
  my ( $ctx, $args, $cond ) = @_;
  my $builder = $ctx->stash( 'builder' );
  my $tokens = $ctx->stash( 'tokens' );
  my $res = '';
  my $items;

  if ( $ctx->stash( 'outlinerfoldertext' ) ) {
    $items = $ctx->stash( 'outlinerfolderitems' );
  } else {
    $items = _get_items ( $ctx );
  }

  if ( $args->{sorted} ) {
    if ( $args->{sorted} eq 'case' ) {
      @$items = sort { $a->{text} cmp $b->{text} } @$items;
    }
    if ( $args->{sorted} eq 'nocase' ) {
      @$items = sort { lc ( $a->{text} ) cmp lc ( $b->{text} ) } @$items;
    }
  }

  foreach my $item ( @$items ) {
    $ctx->stash ( 'outlineritemtext', $item->{text} || '' );
    $ctx->stash ( 'outlineritemdesc', $item->{desc} || '' );
    $ctx->stash ( 'outlineritemhtml', $item->{html} || '' );
    $ctx->stash ( 'outlineritemxml', $item->{xml} || '' );
    my $out = $builder->build( $ctx, $tokens );
    return $ctx->error( $builder->errstr ) unless defined $out;
    $res .= $out;
  }
  $res;
}

sub ReturnValue {
  my ( $ctx, $args ) = @_;

  $ctx->stash( lc( $ctx->stash( 'tag' ) ) );
}

sub ReturnDate {
  my ( $ctx, $args ) = @_;

  if ( $args->{format} ) {
    if ( $ctx->stash( lc( $ctx->stash( 'tag' ) ) ) =~ /^[0-9]{14}$/ ) {
      format_ts( $args->{format}, $ctx->stash( lc( $ctx->stash( 'tag' ) ) ), $ctx->stash( 'blog' ));
    } else {
    $ctx->stash( lc( $ctx->stash( 'tag' ) ) );
    }
  } else {
    $ctx->stash( lc( $ctx->stash( 'tag' ) ) );
  }
}

sub _find_month {
  my( $mmm ) = @_;
  my @months = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );

  for my $num_month ( 0..11 ) {
    if ( $mmm eq $months[$num_month] ) {
      return sprintf( "%02d", $num_month + 1 );
    }
  }
}

sub _get_items {
  my ( $ctx ) = @_;
  my $builder = $ctx->stash( 'builder' );
  my $tokens = $ctx->stash( 'tokens' );
  my ( $folder, $folder_open, $skipfirst ) = ( '', 0, 0 );
  my ( @content, @items );

  $skipfirst = 1 if ( $ctx->stash( 'outlinerbloglines' ) && $ctx->stash( 'outlinerbloglines' ) ne $ctx->stash( 'outlinernotfound' ) );

  if ( $ctx->stash( 'outlinerfoldertext' ) ) {
    $folder = $ctx->stash( 'outlinerfoldertext' );
  }

  @content = split ( /\x0a/, $ctx->stash( 'outlinercontent' ) );
  foreach my $content ( @content ) {
    my $use_item = 0;
    my $item = {};
    $content =~ s|^[\s]*||;
    next unless ( $content =~ m|^<[/]?outline| );
    if ( $folder eq 'Unfiled' ) {
      if ( $content =~ m|^<outline text="(.*)">| || $content =~ m|^<outline title="(.*)">| ) {
        if ( $skipfirst ) {
          $skipfirst = 0;
          next;
        }
        $folder_open++;
      } elsif ( $content =~ m|^</outline>| ) {
        $folder_open-- unless ( $folder_open == 0 );
      } else {
        $use_item = 1 if ( !$folder_open );
      }
    } else {
      if ( $content =~ m|^<outline text="$folder">| || $content =~ m|^<outline title="$folder">| ) {
        $folder_open = 1;
      } elsif ( $content =~ m|^</outline>| ) {
        $folder_open = 0;
      } else {
        $use_item = 1 if ( $folder_open || !$folder );
      }
    }
    if ( $use_item ) {
      ( $item->{text} ) = ( $content =~ m|text="([^"]*)"| );
      ( $item->{text} ) = ( $content =~ m|title="([^"]*)"| ) unless $item->{text};
      ( $item->{desc} ) = ( $content =~ m|description="([^"]*)"| );
      ( $item->{desc} ) =~ s|&gt;|>|g if ( $item->{desc} );
      ( $item->{desc} ) =~ s|&lt;|<|g if ( $item->{desc} );
      ( $item->{desc} ) =~ s|&quot;|"|g if ( $item->{desc} );
      ( $item->{html} ) = ( $content =~ m|htmlUrl="(http://[^\s]*)[\s]?"| );
      ( $item->{html} ) = ( $content =~ m|url="(http://[^\s]*)[\s]?"| ) unless $item->{html};
      ( $item->{xml} ) = ( $content =~ m|xmlUrl="(http://[^\s]*)[\s]?"| );
      push ( @items, $item );
    }
  }
  my $items = \@items;
  $items;
}

sub _load_link {
  my $link = shift;
  require LWP::UserAgent;
  my $ua = LWP::UserAgent->new;
  my $req = HTTP::Request->new ( GET => $link );
  $ua->timeout (15);
  $ua->agent( "MTOutliner/$VERSION" );
  my $result = $ua->request( $req );
  return '' unless $result->is_success;
  return $result->content;
}

sub _load_path {
  my $path = shift;
  my $content;
  open ( FILE, $path ) || die "( $path ) Open Failed: $!\n";
  my @file = <FILE>;
  close (FILE);
  foreach my $line ( @file ) {
    $content .= $line;
  }
  return $content;
}

1;
