# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006-2020 Michael Daum http://michaeldaumconsulting.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html
#
###############################################################################
package Foswiki::Plugins::TagCloudPlugin::Core;

use strict;
use warnings;

use constant TRACE => 0; # toggle me

our %stopWords = (
  en => {
    list => [qw(
      a
      about
      above
      across
      after
      afterwards
      again
      against
      all
      almost
      alone
      along
      already
      also
      although
      always
      am
      among
      amongst
      amoungst
      amount
      an
      and
      another
      any
      anyhow
      anyone
      anything
      anyway
      anywhere
      are
      around
      as
      at
      back
      be
      became
      because
      become
      becomes
      becoming
      been
      before
      beforehand
      behind
      being
      below
      beside
      besides
      between
      beyond
      bill
      both
      bottom
      but
      by
      call
      can
      cannot
      cant
      co
      computer
      con
      could
      couldnt
      cry
      de
      describe
      detail
      do
      done
      down
      dont
      doesnt
      didnt
      due
      during
      each
      eg
      eight
      either
      eleven
      else
      elsewhere
      empty
      enough
      etc
      evenever
      every
      everyone
      everything
      everywhere
      except
      for
      does
      few
      fifteen
      fify
      fill
      find
      fire
      first
      fivefor
      former
      formerly
      forty
      found
      four
      from
      front
      full
      further
      get
      give
      go
      got
      had
      has
      hasnt
      have
      he
      hence
      her
      here
      hereafter
      hereby
      hereinhereupon
      hers
      herself
      him
      himself
      his
      how
      however
      hundred
      i
      ie
      if
      in
      inc
      indeed
      interest
      into
      is
      it
      its
      itself
      keep
      lastlatter
      latterly
      least
      less
      ltd
      made
      many
      may
      me
      meanwhile
      might
      mill
      mine
      more
      moreover
      most
      mostly
      move
      much
      must
      my
      myself
      name
      namely
      neither
      never
      nevertheless
      next
      nine
      no
      nobody
      none
      noone
      nor
      not
      nothing
      now
      nowhere
      of
      off
      often
      on
      once
      one
      only
      onto
      or
      other
      others
      otherwise
      our
      ours
      ourselves
      out
      over
      own
      part
      per
      perhaps
      please
      put
      rather
      re
      same
      see
      seem
      seemed
      seeming
      seems
      serious
      several
      she
      should
      show
      side
      since
      sincere
      six
      sixty
      so
      some
      somehow
      someone
      something
      sometime
      sometimes
      somewhere
      still
      such
      system
      take
      ten
      than
      that
      the
      their
      them
      themselves
      then
      thence
      there
      thereafter
      thereby
      therefore
      therein
      thereupon
      these
      they
      thick
      thin
      third
      this
      those
      though
      three
      through
      throughout
      thru
      thus
      to
      together
      too
      top
      toward
      towards
      twelve
      twenty
      two
      un
      under
      until
      up
      upon
      us
      very
      via
      was
      we
      well
      were
      what
      whatever
      when
      whence
      whenever
      where
      whereafter
      whereas
      whereby
      wherein
      whereupon
      wherever
      whether
      which
      while
      whither
      who
      whoever
      whole
      whom
      whose
      why
      will
      with
      within
      without
      would
      yet
      you
      your
      yours
      yourself
      yourselves
    )],
    pattern => undef,
  },
);

use constant NORMALIZE_LINEAR => 0;
use constant NORMALIZE_LOG => 1;

###############################################################################
sub writeDebug {
  print STDERR '- TagCloudPlugin - '.$_[0]."\n" if TRACE;
}

###############################################################################
sub handleTagCloud {
  my ($session, $params, $theTopic, $theWeb) = @_;

  # get params
  my $theTerms = $params->{_DEFAULT} || $params->{terms} || '';
  my $theHeader = $params->{header};
  my $theFooter = $params->{footer};
  my $theSep = $params->{separator} || $params->{sep} || '$n';
  my $theFormat = $params->{format} || 
    '<span style="font-size:$weightpx">$term</span>';
  my $theBuckets = $params->{buckets} || 10;
  my $theSort = $params->{sort} || 'alpha';
  my $theReverse = $params->{reverse} || 'off';
  my $theMin = $params->{min} || 0;
  my $theOffset = $params->{offset} || 10;
  my $theStopWords = $params->{stopwords} || 'off';
  my $theLanguage = $params->{language} || 'en';
  my $theSplit = $params->{split} || '[/,\.?\s]+';
  my $theExclude = $params->{exclude} || '';
  my $theInclude = $params->{include} || '';
  my $theLowerCase = $params->{lowercase} || 'off';
  my $theMap = $params->{map} || '';
  my $thePlural = $params->{plural} || 'on';
  my $theWarn = $params->{warn} || 'on';
  my $theGroup = $params->{group} || '';
  my $theFilter = $params->{filter} || 'off';
  my $theLimit = $params->{limit};
  my $theNormalize = $params->{normalize} || 'log' ;

  unless (defined($theHeader) || defined($theFooter)) {
    $theHeader = '<div class="tagCloud">';
    $theFooter = '</div>';
  }
  $theHeader ||= '';
  $theFooter ||= '';

  # fix params
  $theMin =~ s/[^\d]//g;
  $theMin = 1 unless defined $theMin;
  $theBuckets =~ s/[^\d]//g;
  $theBuckets = 10 if !$theBuckets || $theBuckets < 2;
  $theOffset =~ s/[^\d]//g;
  $theOffset = 10 unless defined $theOffset;
  $theSort = 'alpha' unless $theSort =~ /^(alpha|case|weight|count)$/;
  $theReverse = 'off' unless $theReverse =~ /^(on|off)$/;
  $theLowerCase = 'off' unless $theLowerCase =~ /^(on|off)$/;
  $theStopWords = 'off' unless $theStopWords =~ /^(on|off)$/;
  $thePlural = 'on' unless $thePlural =~ /^(on|off)$/;

  if ($theNormalize eq 'linear') {
    $theNormalize = NORMALIZE_LINEAR;
  } elsif ($theNormalize =~ /log(arithmic)?/) {
    $theNormalize = NORMALIZE_LOG;
  } else {
    $theNormalize = NORMALIZE_LINEAR; # default
  }


  # build class map
  my %classMap = ();
  if ($theMap) {
    foreach my $mapRule (split(/\s*,\s*/, $theMap)) {
      if ($mapRule =~ /^(.+)=(.+)$/) {
	$classMap{$1} = $2;
      }
    }
  }

  # generate term list
  if (expandVariables($theTerms)) {
    #writeDebug("initially theTerms=$theTerms\n");
    $theTerms = Foswiki::Func::expandCommonVariables($theTerms, $theTopic, $theWeb) if $theTerms =~ /%/;
  }

  # count terms
  my %termCount;
  
  # store optional additional information per term
  my %termInfo = ();

  # remove special chars
  #writeDebug("theFilter=$theFilter");
  #writeDebug("before theTerms=$theTerms\n");
  if ($theFilter eq 'off') {
    # nop
  } elsif ($theFilter eq 'on') {
    $theTerms =~ s/<[^>]+>/ /g;
    $theTerms =~ s/%[A-Z]+%/ /g;
    $theTerms =~ s/<\!\-\-.*?\-\->/ /gs;
    $theTerms =~ s/\&[a-z]+;/ /g;
    $theTerms =~ s/\&#[0-9]+;/ /g;
    $theTerms =~ s/[\*\.=\[\]\(\);&#\\\/\~\-\+`!}{"\$\>\<_]/ /g;
    $theTerms =~ s/[:<>%]//g;
    $theTerms =~ s/\d//g;
  } else {
    $theTerms =~ s/$theFilter/ /g;
  }
  #writeDebug("after theTerms=$theTerms\n");
  my $stopWords; 
  $stopWords = getStopWords($theLanguage) 
    if $theStopWords eq 'on';

  my @terms = ();
  foreach my $term (split(/$theSplit/, $theTerms)) {
    $term =~ s/^\s*(.*?)\s*$/$1/o;
    #writeDebug("term=$term");
    my $weight = 1;
    if ($term =~ /^(.*):(\d+)(?::(.*))*$/) {
      $term = $1;
      $weight = $2;
      my $termInfoString = $3 || "";
      my $infoNo = 3;
      foreach my $info (split(/:/, $termInfoString)) {
        $termInfo{$term}{$infoNo} = $info;
        $infoNo++;
      }
    }
    next if $term =~ /^.?$/;

    # filter
    my $lcterm = lc($term);
    $term = $lcterm if $theLowerCase eq 'on';
    next if $stopWords  && $lcterm =~ $stopWords;
    next if $theExclude && $term =~ /^($theExclude)$/;
    next if $theInclude && $term !~ /^($theInclude)$/;

    # SMELL order matters
    $term = singularForm($term) if $thePlural eq 'off';

    # apply term map
    foreach my $pattern (keys %classMap) {
      if ($term =~ /^$pattern$/) {
	$term = $classMap{$pattern};
	last;
      }
    }

    push @terms, $term;
    $termCount{$term}+=$weight;
  }
  
  # filter low frequencies, compute floor, ceiling
  my $floor = -1;
  my $ceiling = 0;
  my %origTermCount = %termCount;

  foreach my $term (@terms) {
    # truncation
    if ($origTermCount{$term} < $theMin) {
      delete $termCount{$term};
      next;
    }

    # normalization
    $termCount{$term} = log($origTermCount{$term}) if $theNormalize == NORMALIZE_LOG;

    $ceiling = $termCount{$term}
      if $termCount{$term} > $ceiling;
    $floor = $termCount{$term}
      if $termCount{$term} < $floor || $floor < 0;
  }
  my @tmp = map {defined($termCount{$_})?$_:()} @terms;
  @terms = @tmp;
  
  unless (scalar(@terms)) {
    return '<span class="foswikiAlert">nothing found</span>' if $theWarn eq 'on';
    return '';
  }

  # compute the weights
  my $diff = $ceiling - $floor;
  my $incr;
  if ($diff) {
    $incr = ($diff + 0.0) / ($theBuckets -1);
  } else {
    $incr = 1;
  }
  my %termWeight;
  foreach my $term (@terms) {
    $termWeight{$term} = int(($termCount{$term} - $floor + 0.0) / $incr) + 1;
  }

  # sort keys
  if ($theSort eq 'off') {
    # nop
  } elsif ($theSort eq 'alpha') {
    @terms = sort {lc($a) cmp lc($b)} keys %termCount;
  } elsif ($theSort eq 'case') {
    @terms = sort keys %termCount;
  } else {
    if ($theSort eq 'count') {
      @terms = sort {($termCount{$b} <=> $termCount{$a}) || ($a cmp $b)} keys %termCount;
    } else {
      @terms = sort {($termWeight{$b} <=> $termWeight{$a}) || ($a cmp $b)} keys %termCount;
    }
  }
  @terms = reverse @terms if $theReverse eq 'on';

  # format result
  my $result = '';

  my $index = 0;
  my $lastGroup = '';
  foreach my $term (@terms) {
    $index++;
    last if $theLimit && $index > $theLimit;
    my $text;
    my $weight = $termWeight{$term}+$theOffset;
    $text = $theSep if $result;
    my $group = '';
    if ($theGroup eq '') {
      $text .= $theFormat;
    } else {
      if ($theSort eq 'alpha') {
	$group = substr($term, 0, 1);
	$group = ($theLowerCase eq 'on')?lc($group):uc($group);
      } elsif ($theSort eq 'case') {
	$group = substr($term, 0, 1);
      } else {
	$group = int($weight/10)*10;
      }
      if ($lastGroup eq $group) {
	$group = '';
	$text .= $theFormat;
      } else {
	$lastGroup = $group;
	$text .= $theGroup.$theFormat;
      }
    }
    my %params = ( 'term'   => $term,
                   'index'  => $index,
                   'weight' => $weight,
                   'group'  => $group,
                   'count'  => $origTermCount{$term});
    if (defined($termInfo{$term})) {
      %params = (%params, %{ $termInfo{$term} });
    }
    expandVariables($text, %params);
    $text =~ s/\$fadeRGB\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)/&handleFadeRGB($1,$2,$3,$4,$5,$6, $weight, $theBuckets+$theOffset)/ge;
    $result .= $text;
  }
  expandVariables($theHeader);
  expandVariables($theFooter);
  $result = $theHeader.$result.$theFooter;

  return $result;
}

###############################################################################
# returns 1 if something was expanded
sub expandVariables {
  my (undef, %params) = @_;

  return 0 unless $_[0];

  my $found = 0;

  foreach my $key (keys %params) {
    if($_[0] =~ s/\$$key/$params{$key}/g) {
      $found = 1;
    }
  }
  $found = 1 if $_[0] =~ s/\$percnt/\%/g;
  $found = 1 if $_[0] =~ s/\$nop//g;
  $found = 1 if $_[0] =~ s/\$n/\n/g;
  $found = 1 if $_[0] =~ s/\$dollar/\$/g;

  return $found;
}

###############################################################################
# TODO: let's have more than two colors to fade
sub handleFadeRGB {
  my ($startRed, $startGreen, $startBlue, $endRed, $endGreen, $endBlue, $step, $max) = @_;
  
  my $red = int($startRed*(($max-$step+0.0)/$max)+$endRed*(($step+0.0)/$max));
  my $green = int($startGreen*(($max-$step+0.0)/$max)+$endGreen*(($step+0.0)/$max));
  my $blue = int($startBlue*(($max-$step+0.0)/$max)+$endBlue*(($step+0.0)/$max));

  return "rgb($red,$green,$blue)";
}

###############################################################################
# from Foswiki::Plurals
sub singularForm {
  my $string = shift;

  my $charset = $Foswiki::cfg{Site}{CharSet};
  
  $string = Encode::decode($charset, $string);
  $string =~ s/ies$/y/;      # plurals like policy / policies
  $string =~ s/sses$/ss/;    # plurals like address / addresses
  $string =~ s/ches$/ch/;    # plurals like search / searches
  $string =~ s/(oes|os)$/o/; # plurals like veto / vetoes
  $string =~ s/([Xx])es$/$1/;# plurals like box / boxes
  $string =~ s/([^s])s$/$1/; # others, excluding ss like address(es)
  $string = Encode::encode($charset, $string);

  return $string
}

###############################################################################
sub getStopWords {
  my $lang = shift;

  my $pattern = $stopWords{$lang}{pattern};
  unless (defined $pattern) {
    $pattern = join('|', @{$stopWords{$lang}{list}});
    $pattern = qr/\b($pattern)\b/;
    $stopWords{$lang}{pattern} = $pattern;
  }

  return $pattern;
}

1;
