#!/bin/sh
# Builds an 8-color palette from an image and writes it as a .env file.
# Usage: palette-from-image.sh <image> <out.env>
img="$1"
out="$2"
IM=$(command -v magick || command -v convert) || { echo "ImageMagick is not installed" >&2; exit 1; }

# -depth 8 forces 0-255 channel values, so the hex output is always 6 digits
$IM "$img[0]" -alpha off -colorspace sRGB -depth 8 -resize 96x96! txt:- 2>/dev/null | awk -v out="$out" '
function clamp(v) { return v < 0 ? 0 : (v > 255 ? 255 : v) }
function lum(r,g,b)  { return 0.299*r + 0.587*g + 0.114*b }
function mx3(r,g,b,  m) { m=r; if (g>m) m=g; if (b>m) m=b; return m }
function mn3(r,g,b,  m) { m=r; if (g<m) m=g; if (b<m) m=b; return m }
function sat(r,g,b,  M,m) { M=mx3(r,g,b); m=mn3(r,g,b); return M==0 ? 0 : (M-m)/M }
function hue(r,g,b,  M,m,d,h) {
    M=mx3(r,g,b); m=mn3(r,g,b); d=M-m
    if (d==0) return -1
    if (M==r) h=60*((g-b)/d)
    else if (M==g) h=60*((b-r)/d)+120
    else h=60*((r-g)/d)+240
    if (h<0) h+=360
    return h
}
function col(r,g,b) {
    return sprintf("#%02x%02x%02x", clamp(int(r+0.5)), clamp(int(g+0.5)), clamp(int(b+0.5)))
}
function mix(r1,g1,b1,r2,g2,b2,t) { return col(r1+(r2-r1)*t, g1+(g2-g1)*t, b1+(b2-b1)*t) }

/^#/ { next }
{
    gsub(/[(),:]/, " ")
    if (NF < 5) next
    n++; R[n]=clamp($3+0); G[n]=clamp($4+0); B[n]=clamp($5+0)
}
END {
    if (n == 0) exit 1
    lo=1e9; hi=-1; dk=1; lt=1
    for (i=1; i<=n; i++) {
        L=lum(R[i],G[i],B[i])
        if (L<lo) { lo=L; dk=i }
        if (L>hi) { hi=L; lt=i }
    }

    sA=0; sR=0; sY=0; sG=0
    for (i=1; i<=n; i++) {
        r=R[i]; g=G[i]; b=B[i]
        s=sat(r,g,b); L=lum(r,g,b); h=hue(r,g,b)
        if (s < 0.3 || L < 60 || L > 235) continue
        if (s > sA && L > 70 && L < 230) { sA=s; iA=i }
        if (h < 0) continue
        if ((h <= 20 || h >= 340) && s > sR) { sR=s; iR=i }
        if (h >= 40 && h <= 70 && s > sY) { sY=s; iY=i }
        if (h >= 85 && h <= 160 && s > sG) { sG=s; iG=i }
    }

    bgc  = col(R[dk],G[dk],B[dk])
    fgc  = col(R[lt],G[lt],B[lt])
    surf = mix(R[dk],G[dk],B[dk], R[lt],G[lt],B[lt], 0.12)
    mut  = mix(R[dk],G[dk],B[dk], R[lt],G[lt],B[lt], 0.45)
    acc  = iA ? col(R[iA],G[iA],B[iA]) : fgc
    red  = iR ? col(R[iR],G[iR],B[iR]) : "#f7768e"
    grn  = iG ? col(R[iG],G[iG],B[iG]) : "#9ece6a"
    yel  = iY ? col(R[iY],G[iY],B[iY]) : "#e0af68"

    printf "bg=%s\nsurface=%s\nfg=%s\nmuted=%s\naccent=%s\nred=%s\ngreen=%s\nyellow=%s\n",
        bgc, surf, fgc, mut, acc, red, grn, yel > out
    close(out)
}'