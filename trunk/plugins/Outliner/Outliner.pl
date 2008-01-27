# ===========================================================================
# Copyright 2003-2006, Everitz Consulting (everitz.com)
#
# Licensed under the Open Software License version 2.1
# ===========================================================================
package MT::Plugin::Outliner;

use base qw(MT::Plugin);
use strict;

use MT;
use MT::Template::Context;
use MT::Util qw(format_ts);
use XML::Twig;

# version
use vars qw($VERSION);
$VERSION = '2.0.1';

my $Outliner;
my $about = {
  name => 'MT-Outliner',
  description => 'Access information from OPML files through template tags.',
  author_name => 'Everitz Consulting',
  author_link => 'http://www.everitz.com/',
  plugin_link => 'http://www.everitz.com/sol/mt-outliner/index.html',
  doc_link => 'http://www.everitz.com/sol/mt-outliner/index.html',
  version => $VERSION
}; 
$Outliner = MT::Plugin::Outliner->new($about);
MT->add_plugin($Outliner);

MT::Template::Context->add_container_tag(Outliner => \&Outliner);
MT::Template::Context->add_tag(OutlinerBloglines => \&ReturnValue);
MT::Template::Context->add_tag(OutlinerDataSource => \&ReturnValue);
MT::Template::Context->add_tag(OutlinerDateCreated => \&ReturnValue);
MT::Template::Context->add_tag(OutlinerDateModified => \&ReturnValue);
MT::Template::Context->add_tag(OutlinerOPMLVersion => \&ReturnValue);
MT::Template::Context->add_tag(OutlinerOwnerName => \&ReturnValue);
MT::Template::Context->add_tag(OutlinerOwnerEmail => \&ReturnValue);
MT::Template::Context->add_tag(OutlinerTitle => \&ReturnValue);
MT::Template::Context->add_tag(OutlinerXMLVersion => \&ReturnValue);

MT::Template::Context->add_container_tag(OutlinerFolders => \&OutlinerFolders);
MT::Template::Context->add_tag(OutlinerFolderText => \&ReturnValue);
MT::Template::Context->add_tag(OutlinerFolderItemCount => \&ReturnValue);
MT::Template::Context->add_conditional_tag(OutlinerFolderIfItems => \&ReturnValue);
MT::Template::Context->add_conditional_tag(OutlinerFolderIfNoItems => \&ReturnValue);
MT::Template::Context->add_tag(OutlinerFolderSubsCount => \&ReturnValue);
MT::Template::Context->add_conditional_tag(OutlinerFolderIfSubs => \&ReturnValue);
MT::Template::Context->add_conditional_tag(OutlinerFolderIfNoSubs => \&ReturnValue);

MT::Template::Context->add_tag(OutlinerRecurse => \&OutlinerRecurse);

MT::Template::Context->add_container_tag(OutlinerItems => \&OutlinerItems);
MT::Template::Context->add_tag(OutlinerItemText => \&ReturnValue);
MT::Template::Context->add_tag(OutlinerItemDesc => \&ReturnValue);
MT::Template::Context->add_tag(OutlinerItemHTML => \&ReturnValue);
MT::Template::Context->add_tag(OutlinerItemXML => \&ReturnValue);

sub Outliner {
  my ($ctx, $args, $cond) = @_;
  my $builder = $ctx->stash('builder');
  my $tokens = $ctx->stash('tokens');
  my $notfound = $args->{notfound} || 'Not Found';
  $ctx->stash('outlinernotfound', $notfound);
  my @tags = (
    'outlinerdatecreated',
    'outlinerdatemodified',
    'outlineropmlversion',
    'outlinerownername',
    'outlinerowneremail',
    'outlinertitle',
    'outlinerxmlversion'
  );
  my $res = '';
  my $dat;  
  my $url;
  if ($args->{bloglines}) {
    $ctx->stash('outlinerbloglines', $args->{bloglines});
    $url = "http://www.bloglines.com/export?id=$args->{bloglines}";
    $dat = ol_load_link ($url);
  } else {
    $ctx->stash('outlinerbloglines', $notfound);
    if ($args->{opmllink}) {
      $url = $args->{opmllink};
      $dat = ol_load_link ($url);
    } elsif ($args->{opmlpath}) {
      $url = $args->{opmlpath};
      $dat = ol_load_path ($url);
    }
  }
  return $ctx->error("Error processing file: $url") unless $dat;
  $dat =~ s|&|&amp;|g;
  $ctx->stash('outlinercontent', $dat);
  $ctx->stash('outlinerdatasource', $url);
  foreach my $tag (@tags) {
    $ctx->stash($tag, '');
  }
  my $twig = XML::Twig->new(
    TwigHandlers => {
      'head' => sub {
        my @kids = $_->children();
        foreach my $k (@kids) {
          my $key = 'outliner'.$k->gi;
          $key =~ tr/A-Z/a-z/;
          $ctx->stash($key, $k->text);
        }
        $_[0]->purge;
      },
      'opml' => sub {
        my $key = 'outlineropmlversion';
        $ctx->stash($key, $_->{'att'}->{'version'});
        $key = 'outlinerxmlversion';
        $ctx->stash($key, $_[0]->xml_version);
        $_[0]->purge;
      }
    },
    TwigRoots => { 'head' => 1, 'opml' => 1 }
  );
  $twig->parse ($dat);
  my $date;
  if ($date = ol_format_date($ctx->stash('outlinerdatecreated'), 'a')) {
    $ctx->stash('outlinerdatecreated', $date);
  } else {
    if ($date = ol_format_date($ctx->stash('outlinerpubdate'), 'b')) {
      $ctx->stash('outlinerdatecreated', $date);
    } else {
    }
  }
  if ($date = ol_format_date($ctx->stash('outlinerdatemodified'), 'c')) {
    $ctx->stash('outlinerdatemodified', $date);
  } else {
    if ($date = ol_format_date($ctx->stash('outlinerlastbuilddate'), 'd')) {
      $ctx->stash('outlinerdatemodified', $date);
    }
  }
  foreach my $tag (@tags) {
    $ctx->stash($tag, $notfound) unless $ctx->stash($tag);
  }
  my $out = $builder->build($ctx, $tokens);
  return $ctx->error($builder->errstr) unless defined $out;
  $res .= $out;
}

sub OutlinerFolders {
  my ($ctx, $args, $cond) = @_;
  my $builder = $ctx->stash('builder');
  my $tokens = $ctx->stash('tokens');
  my $dat = $ctx->stash('outlinercontent');
  my $res = '';
  $ctx->stash('outlinertokens', $tokens);
  my $twig = XML::Twig->new(
    TwigHandlers => {
      'body' => sub {
        my @folders = $_->children('outline');
        foreach my $f (@folders) {
          next unless $f->has_child('outline');
          my $folder = $f->{'att'}->{'text'} || $f->{'att'}->{'title'};
          next if ($args->{folders} && $args->{folders} !~ m|$folder|);
          my $out = ol_load_folder ($ctx, $builder, $tokens, $f);
          return $ctx->error($builder->errstr) unless defined $out;
          $res .= $out;
        }
        $_[0]->purge;
      }
    },
    TwigRoots => { 'body' => 1 }
  );
  $twig->parse ($dat);
  $res;
}

sub OutlinerItems {
  my ($ctx,$args,$cond) = @_;
  my $builder = $ctx->stash('builder');
  my $tokens = $ctx->stash('tokens');
  my $res = '';
  my $items;
  if ($ctx->stash('outlinerfoldertext')) {
    $items = $ctx->stash('outlinerfolderitems');
  } else {
    my $dat = $ctx->stash('outlinercontent');
    my $twig = XML::Twig->new(
      TwigHandlers => {
        'body' => sub {
          my @kids = $_->children('outline');
          my @items;
          foreach my $k (@kids) {
            next if $k->has_child('outline');
            push @items, $k;
          }
          $items = ol_load_children (\@kids);
          $_[0]->purge;
        }
      },
      TwigRoots => { 'body' => 1 }
    );
    $twig->parse ($dat);
  }
  if ($args->{sorted}) {
    if ($args->{sorted} eq 'case') {
      @$items = sort { $a->{text} cmp $b->{text} } @$items;
    } elsif ($args->{sorted} eq 'nocase') {
      @$items = sort { lc ($a->{text}) cmp lc ($b->{text}) } @$items;
    }
  }
  foreach my $item (@$items) {
    $ctx->stash ('outlineritemtext', $item->{text} || '');
    $ctx->stash ('outlineritemdesc', $item->{desc} || '');
    $ctx->stash ('outlineritemhtml', $item->{html} || '');
    $ctx->stash ('outlineritemxml', $item->{xml} || '');
    my $out = $builder->build($ctx, $tokens);
    return $ctx->error($builder->errstr) unless defined $out;
    $res .= $out;
  }
  $res;
}

sub OutlinerRecurse {
  my ($ctx, $args) = @_;
  my $builder = $ctx->stash('builder');
  my $tokens = $ctx->stash('outlinertokens');
  my $res = '';
  my $folders = $ctx->stash('outlinerfoldersubfolders');
  return $res unless $folders;
  foreach my $f (@$folders) {
    next unless $f->has_child('outline');
    my $folder = $f->{'att'}->{'text'} || $f->{'att'}->{'title'};
    next if ($args->{folders} && $args->{folders} !~ m|$folder|);
    my $out = ol_load_folder ($ctx, $builder, $tokens, $f);
    return $ctx->error($builder->errstr) unless defined $out;
    $res .= $out;
  }
  $res;
}

sub ReturnValue {
  my ($ctx, $args) = @_;
  my $val = $ctx->stash(lc($ctx->stash('tag')));
  if (my $fmt = $args->{format}) {
    if ($val =~ /^[0-9]{14}$/) {
      return format_ts($fmt, $val, $ctx->stash('blog'));
    }
  }
  $val;
}

sub ol_format_date {
  my $date = shift;
  my $mode = shift;
  return 0 unless $date;
  my ($dc_dd, $dc_mo, $dc_yyyy, $dc_hh, $dc_mm, $dc_ss) =
     ($date =~ m|\w{3}, (\d{1,2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2})|);
  my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
  for my $month (0..11) {
    if ($dc_mo eq $months[$month]) {
      $dc_mo = $month + 1;
    }
  }
  $dc_yyyy.sprintf("%02d", $dc_mo).sprintf("%02d", $dc_dd).$dc_hh.$dc_mm.$dc_ss;
}

sub ol_load_children {
  my $kids = shift;
  my $type = shift;
  my @items;
  foreach my $k (@$kids) {
    if ($type) {
      push (@items, $k) if ($type eq 'folders' && $k->has_child);
    } else {
      unless ($k->has_child) {
        my $item = {};
        $item->{text} = $k->{'att'}->{'text'} || $k->{'att'}->{'title'};
        $item->{desc} = $k->{'att'}->{'description'};
        $item->{desc} =~ s|&gt;|>|g if $item->{desc};
        $item->{desc} =~ s|&lt;|<|g if $item->{desc};
        $item->{desc} =~ s|&quot;|"|g if $item->{desc};
        $item->{html} = $k->{'att'}->{'htmlUrl'} || $k->{'att'}->{'url'};
        $item->{xml} = $k->{'att'}->{'xmlUrl'};
        push (@items, $item);
      }
    }
  }
  \@items;
}

sub ol_load_folder {
  my ($ctx, $builder, $tokens, $f) = @_;
  my $folder = $f->{'att'}->{'text'} || $f->{'att'}->{'title'};
  $folder =~ s|&|&amp;|g;
  $ctx->stash('outlinerfoldertext', $folder);
  my @kids = $f->children('outline');
  my $items = ol_load_children (\@kids);
  $ctx->stash('outlinerfolderitems', \@$items);
  $ctx->stash('outlinerfolderitemcount', scalar @$items);
  $ctx->stash('outlinerfolderifitems', scalar @$items);
  $ctx->stash('outlinerfolderifnoitems', !(scalar @$items));
  $items = ol_load_children (\@kids, 'folders');
  $ctx->stash('outlinerfoldersubfolders', \@$items);
  $ctx->stash('outlinerfoldersubfoldercount', scalar @$items);
  $ctx->stash('outlinerfolderifsubfolders', scalar @$items);
  $ctx->stash('outlinerfolderifnosubfolders', !(scalar @$items));
  my $out = $builder->build($ctx, $tokens);
  $out;
}

sub ol_load_link {
  my $link = shift;
  require LWP::UserAgent;
  my $ua = LWP::UserAgent->new;
  my $req = HTTP::Request->new (GET => $link);
  $ua->timeout (15);
  $ua->agent("MTOutliner/$VERSION");
  my $result = $ua->request($req);
  return '' unless $result->is_success;
  $result->content;
}

sub ol_load_path {
  my $path = shift;
  my $content;
  open (FILE, $path) || die "($path) Open Failed: $!\n";
  my @file = <FILE>;
  close (FILE);
  foreach my $line (@file) {
    $content .= $line;
  }
  $content;
}

1;
