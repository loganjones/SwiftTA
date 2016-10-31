//
//  ta_HPI_decompress.h
//  HPIView
//
//  Created by Logan Jones on 10/30/16.
//  Copyright © 2016 Logan Jones. All rights reserved.
//

#ifndef ta_HPI_decompress_h
#define ta_HPI_decompress_h

#include <stdio.h>

int hpi_decompress_LZ77( const unsigned char *in, unsigned char *out );
size_t hpi_decompress_ZLib( const unsigned char *in, unsigned char *out, uint32_t inSize, uint32_t outSize );

#endif /* ta_HPI_decompress_h */
