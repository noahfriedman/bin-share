#!/usr/bin/env python3

import rpm
import sys
import stat as st

GROUPS  = { 'summary'   : ( 'name',
                            'version',
                            'release',
                            'arch',
                            'size',

                            'sourcerpm',
                            'buildhost',
                            'buildtime',
                            'installtime',

                            'os',
                            'platform',
                            'optflags',
                            'archivesize',

                            'packager',
                            'vendor',
                            'distribution',
                            'group',
                            'license',
                            'url',
                            'bugurl',

                            'summary',
                            'description',
                          ),

            'changelog' : ( 'changelogtime',
                            'changelogname',
                            'changelogtext',
                          ),

            'file'      : ( 'fileinodes',
                            'filemodes',
                            'filenlinks',
                            'fileusername',
                            'filegroupname',
                            'filesizes',
                            'filemtimes',
                            'oldfilenames',

                            'fileflags',
                            'filecolors',
                          ),

            'provides'  : ( 'provides',
                            'provideversion',
                            'provideflags',
                          ),

            'requires'  : ( 'requires'
                            'requireversion',
                            'requireflags',
                          ),
          }

# exclude regexps
#
#	/usr/lib/.build-id/
#	/usr/share/licenses/
#	/__pycache__
#	\.egg-info
#	\.py[oc]$


def lsh( value, count ):
    """Shift VALUE bits left COUNT times.
    If COUNT is negative, bits are shifted to the right.

    Python's native << and >> operators do not allow
    shifting by negative amounts.
    """
    if count < 0:
        return value >> abs( count )
    return value << count


def make_bitmask_map( names, start=0 ):
    return { lsh( 1, idx ) : name
             for (idx, name) in enumerate( names, start=start )
             if name is not None }


# See rpmfileAttrs_e (RPMFILE_*) in rpmfiles.h
file_flag_map = make_bitmask_map(
    ( #'none',              # 1<<-1
      'config',             # 1<< 0  from %%config
      'doc',                # 1<< 1  from %%doc
      'icon',               # 1<< 2  from %%donotuse.
      'missingok',          # 1<< 3  from %%config(missingok)
      'noreplace',          # 1<< 4  from %%config(noreplace)
      'specfile',           # 1<< 5  marks 1st file in srpm
      'ghost',              # 1<< 6  from %%ghost
      'license',            # 1<< 7  from %%license
      'readme',             # 1<< 8  from %%readme
      None,                 # 1<< 9  unused
      None,                 # 1<<10  unused
      'pubkey',             # 1<<11  from %%pubkey
      'artifact', ))        # 1<<12  from %%artifact


# See rpmVerifyAttrs_e (RPMVERIFY_*) in rpmfiles.h
verify_flag_map = make_bitmask_map(
    ( #'none',              # 1<<-1
      'md5',	            # 1<< 0  from %verify(md5) - obsolete
      #'filedigest',        # 1<< 0  from %verify(filedigest)
      'filesize',           # 1<< 1  from %verify(size)
      'linkto',	            # 1<< 2  from %verify(link)
      'user',	            # 1<< 3  from %verify(user)
      'group',	            # 1<< 4  from %verify(group)
      'mtime',	            # 1<< 5  from %verify(mtime)
      'mode',	            # 1<< 6  from %verify(mode)
      'rdev',	            # 1<< 7  from %verify(rdev)
      'caps',	            # 1<< 8  from %verify(caps)
      *(None,)*(14-8),      #        bits 9-14 reserved for rpmVerifyAttrs
      'contexts',           # 1<<15  verify: from --nocontexts
      *(None,)*(22-15),     #        bits 16-22 used in rpmVerifyFlags
      *(None,)*(27-22),     #        bits 23-27 used in rpmQueryFlags
      'readlinkfail',       # 1<<28  readlink failed
      'readfail',           # 1<<29  file read failed
      'lstatfail',          # 1<<30  lstat failed
      'lgetfileconfail', )) # 1<<31  lgetfilecon failed



rpmfile_attrs_exclude = ( 'imasig', 'match' )
rpmfile_attrs = [ attr for attr in dir( rpm.file )
                  if attr.find( '__' ) < 0
                  and attr not in rpmfile_attrs_exclude ]


# Can access members as foo['x'] or foo.x interchangably
class RpmFile( dict ):
    def __init__( self, *args, **kwargs ):
        self.__dict__ = self
        super().__init__( *args, *kwargs )

    def __getattr__( self, elt ):
        try:
            return self.__getitem__( elt )
        except KeyError as e:
            raise AttributeError( e )

    modestring = property( lambda self: st.filemode( self['mode'] ))


def rpmfile_to_dict( rpmfile ):
    res  = RpmFile( (attr , getattr( rpmfile, attr )) for attr in rpmfile_attrs )
    # Decode fflags
    if fflags := res.get( 'fflags', 0 ):
        if ffdesc := [ file_flag_map[ m ] for m in file_flag_map if fflags & m == m ]:
            if len( ffdesc ) == 1:
                res[ 'ffdesc' ] = ffdesc[0]
            else:
                res[ 'ffdesc' ] = ffdesc

    # resolve links
    if links := res.get( 'links' ):
        res[ 'links' ] = tuple( elt.name for elt in links )

    return res


def rpmfiles_to_dicts( rpmfiles ):
    return [ rpmfile_to_dict( elt ) for elt in rpmfiles ]


def find_packages( *args ):
    ts = rpm.TransactionSet()
    result = []
    for pat in args:
        mi = ts.dbMatch()
        mi.pattern( 'name', rpm.RPMMIRE_GLOB, pat )
        result.extend( mi )
    return result


def main( argv=sys.argv ):
    ts = rpm.TransactionSet()
    result = []
    for pat in argv:
        mi = ts.dbMatch()
        mi.pattern( 'name', rpm.RPMMIRE_GLOB, pat )
        for hdr in mi:
            files = rpm.files( hdr )
            result.extend( rpmfiles_to_dicts( files ))
    return result


if __name__ == '__main__':
    main()
elif __name__ == '__pyrepl__':
    repl_pp._width = 200
