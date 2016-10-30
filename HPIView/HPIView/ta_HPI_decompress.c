//
//  ta_HPI_decompress.c
//  HPIView
//
//  Created by Logan Jones on 10/30/16.
//  Copyright © 2016 Logan Jones. All rights reserved.
//

#include "ta_HPI_decompress.h"
#include "zlib.h"


int hpi_decompress_LZ77( const unsigned char *in, unsigned char *out )
{
    int x;
    int work1;
    int work2;
    int work3;
    int inptr;
    int outptr;
    int count;
    int done;
    char DBuff[4096];
    int DPtr;
    
    done = 0;
    
    inptr = 0;
    outptr = 0;
    work1 = 1;
    work2 = 1;
    work3 = in[inptr++];
    
    while (!done) {
        if ((work2 & work3) == 0) {
            out[outptr++] = in[inptr];
            DBuff[work1] = in[inptr];
            work1 = (work1 + 1) & 0xFFF;
            inptr++;
        }
        else {
            count = *((unsigned short *) (in+inptr));
            inptr += 2;
            DPtr = count >> 4;
            if (DPtr == 0) {
                return outptr;
            }
            else {
                count = (count & 0x0f) + 2;
                if (count >= 0) {
                    for (x = 0; x < count; x++) {
                        out[outptr++] = DBuff[DPtr];
                        DBuff[work1] = DBuff[DPtr];
                        DPtr = (DPtr + 1) & 0xFFF;
                        work1 = (work1 + 1) & 0xFFF;
                    }
                    
                }
            }
        }
        work2 *= 2;
        if (work2 & 0x0100) {
            work2 = 1;
            work3 = in[inptr++];
        }
    }
    
    return outptr;
}

size_t hpi_decompress_ZLib( const unsigned char *in, unsigned char *out, uint32_t inSize, uint32_t outSize )
{
    z_stream zs;
    int result;
    
    zs.next_in = in;
    zs.avail_in = inSize;
    zs.total_in = 0;
    
    zs.next_out = out;
    zs.avail_out = outSize;
    zs.total_out = 0;
    
    zs.msg = NULL;
    zs.state = NULL;
    zs.zalloc = Z_NULL;
    zs.zfree = Z_NULL;
    zs.opaque = NULL;
    
    zs.data_type = Z_BINARY;
    zs.adler = 0;
    zs.reserved = 0;
    
    result = inflateInit(&zs);
    if (result != Z_OK) {
        return 0;
    }
    
    result = inflate(&zs, Z_FINISH);
    if (result != Z_STREAM_END) {
        zs.total_out = 0;
    }
    
    result = inflateEnd(&zs);
    if (result != Z_OK) {
        return 0;
    }
    
    return zs.total_out;
}
