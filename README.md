# Vbinary: variable length integer coding revisited

Please refer to the
[http://psta.psiras.ru/2018/04(039)/content-04(039).html][article].

vbinary-eval.pl outputs data for "Bits Needed to Encode a Value"
vs. "Value to Encode" graphs:

% ./vbinary-eval.pl vbinary2x | head
0 0
2 3
4 6
6 9
8 12
10 15
12 18
14 21
16 24
18 27

Enable verbosity with -v to understand how vbinary parameters work:

% ./vbinary-eval.pl -v 'vbinary2x(2x,4,5)' | head
level  0/0 width  2 data   1 exts 3 totbits  2 totvalues 1
level  1/0 width  2 data   1 exts 3 totbits  4 totvalues 2
level  1/1 width  4 data  16 exts 0 totbits  6 totvalues 18
level  1/2 width  5 data  32 exts 0 totbits  7 totvalues 50
level  2/0 width  2 data   1 exts 3 totbits  6 totvalues 51
level  2/1 width  4 data  16 exts 0 totbits  8 totvalues 67
level  2/2 width  5 data  32 exts 0 totbits  9 totvalues 99
level  3/0 width  2 data   1 exts 3 totbits  8 totvalues 100
level  3/1 width  4 data  16 exts 0 totbits 10 totvalues 116
level  3/2 width  5 data  32 exts 0 totbits 11 totvalues 148
