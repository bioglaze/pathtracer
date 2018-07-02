import std.stdio;

struct Texture
{
    byte[] pixels;
    int width;
    int height;
    int channels;
}

void readTGA( string path, out Texture texture )
{
    try
    {
        auto f = File( path, "r" );
            
        byte[ 1 ] idLength;
        f.rawRead( idLength );

        byte[ 1 ] colorMapType;
        f.rawRead( colorMapType );

        byte[ 1 ] imageType;
        f.rawRead( imageType );

        if (imageType[ 0 ] != 2)
        {
            throw new Exception( "wrong TGA type: must be uncompressed true-color" );
        }

        byte[ 5 ] colorSpec;
        f.rawRead( colorSpec );

        byte[ 4 ] specBegin;
        short[ 2 ] specDim;
        f.rawRead( specBegin );
        f.rawRead( specDim );
        texture.width = specDim[ 0 ];
        texture.height = specDim[ 1 ];

        byte[ 2 ] specEnd;
        f.rawRead( specEnd );

        if (idLength[ 0 ] > 0)
        {
            byte[] imageId = new byte[ idLength[ 0 ] ];
            f.rawRead( imageId );
        }

        texture.pixels = new byte[ texture.width * texture.height * 4 ];
        texture.channels = 4;
        
        f.rawRead( texture.pixels );
    }
    catch (Exception e)
    {
        writeln( "could not open ", path, ":", e );
    } 
}

align( 1 ) struct BMPHeader
{
    align(1):
    ushort magic;
    uint fileSize;
    ushort reserved1;
    ushort reserved2;
    uint bitmapOffset;
    uint size;
    int width;
    int height;
    ushort planes;
    ushort bpp;
    uint compression;
    uint sizeOfBitmap;
    int horizRes;
    int vertRes;
    uint colors;
    uint importantColors;
}

void writeBMP( uint[] imageData, int width, int height )
{
    BMPHeader header;
    header.magic = 0x4D42;
    header.fileSize = cast(uint)( BMPHeader.sizeof + imageData.length * 4 );    
    header.bitmapOffset = BMPHeader.sizeof;
    header.size = cast(uint)BMPHeader.sizeof - 14;
    header.width = width;
    header.height = -height;
    header.planes = 1;
    header.bpp = 32;
    header.compression = 0;
    header.sizeOfBitmap = cast(uint)imageData.length * 4;
    header.horizRes = 0;
    header.vertRes = 0;

    File f = File( "image.bmp", "wb" );
    f.rawWrite( (&header)[ 0 .. 1 ] );
    f.rawWrite( imageData );
}
