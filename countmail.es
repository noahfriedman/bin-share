#!/usr/local/bin/es -p
# countmail.es --- be obnoxious about how much mail you have
# Author: Noah Friedman <friedman@prep.ai.mit.edu>
# Created: 1993-02-22
# Translated to es: 1994-02-19
# Last modified: 1994-02-28
# Public domain

# Commentary:

# "countmail is the work of someone in an altered state."
#    --Ben A. Mesander <ben@piglet.cr.usgs.gov>

# The original idea for this program came from
# Lauren P. Burka <exile@gnu.ai.mit.edu>

# Code:

if { ~ $* () } \
     {
       if { ~ $USER () } \
            {
              if { ! ~ $LOGNAME () } \
                   { USER = $LOGNAME } \
                 {
                   if { ! { USER = `{ whoami } } } \
                        { 
                          USER = `{ 
                                    id \
                                     | sed -ne 's/.*uid=[0-9]*(//;s/).*//;p'
                                  } 
                        }
                 }
            }

       let (result = /usr/spool/mail)
         {
           for (dir = /usr/spool/mail /var/mail /usr/mail)
             {
               if { access -d $dir } \
                    {
                      result = $dir
                      break
                    }
             }
           file = $result/$USER
         }
     } \
   { 
     file = $1 
   }

* = `{ grep '^From ' $file >[2] /dev/null | wc -l }
if { ~ $* 0 } \
     { * = ZERO } \
   { 
     * = <={
        # Strips excess spaces and commas, and puts each digit into a
        # separate slot in the array.
        * = <={ %fsplit '' <={%flatten '' <={%fsplit ', ' $^* } } }

        let (ones = ONE TWO THREE FOUR FIVE SIX SEVEN EIGHT NINE;
             tens = TEN TWENTY THIRTY FORTY FIFTY SIXTY SEVENTY EIGHTY NINETY;
             teens = ELEVEN TWELVE (THIR FOUR FIF SIX SEVEN EIGH NINE)^TEEN;
             bignum = (THOUSAND 
                       (M B TR QUADR QUINT SEXT SEPT OCT NON 
                       ('' UN DUO TRE QUATTUORO QUIN SEX SEPTEN OCTO NOVEM)^DEC
                       VIGINT)^ILLION );
             a = $*
             bignum-ref = ;
             val100 =; val10 =; val1 =;
             result =)
          {
            while { ! ~ $#a 0 1 2 3 } \
              { 
                a = $a(4 ...) 
                bignum-ref = $bignum-ref ''
              }

            if { ~ $#a 1 } \
                 { * = 0 0 $* } \
               { ~ $#a 2 } \
                 { * = 0 $* }

            while { ! ~ $* () } \
              {
                val100 =; val10 =; val1 =;
                if { ! ~ $1 0 } { val100 = $ones($1) HUNDRED }
                if { ! ~ $2 0 } { val10 = $tens($2) }
                if { ! ~ $3 0 } \
                     { 
                       if { ~ $val10 ten } \
                            { val10 = ; val1 = $teens($3) } \
                          { val1 = $ones($3) } 
                     }

                result = $result $val100 
                if { ~ $val10 *ty && ! ~ $val1 () } \
                     { result = $result $^val10^-^$val1 } \
                   { result = $result $val10 $val1 }
                if { ! { ~ $bignum-ref () || ~ $1$2$3 000 } } \
                     { 
                       result = $result $bignum($#bignum-ref) 
                     }
                bignum-ref = $bignum-ref(2 ...)
                * = $*(4 ...)
              }
            result $result
          }
     }
   }

s = 'S'
if { ~ $^* ONE } \
     { s = '' }

echo $^*'!

'$^*' NEW MAIL MESSAGE'$s'!

HAHAHAHAHA!
'

# countmail.es ends here
