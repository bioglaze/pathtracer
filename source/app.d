import std.stdio;
import std.math;

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

Vec3 normalize( Vec3 v )
{
    float length = sqrt( v.x * v.x + v.y * v.y + v.z * v.z );
    
    return Vec3( v.x / length, v.y / length, v.z / length );
}

float dot( Vec3 v1, Vec3 v2 )
{
    return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z;
}

Vec3 cross( Vec3 v1, Vec3 v2 )
{
    return Vec3( v1.y * v2.z - v1.z * v2.y,
                 v1.z * v2.x - v1.x * v2.z,
                 v1.x * v2.y - v1.y * v2.x );
}

struct Vec3
{
    this( float ax, float ay, float az )
    {
        x = ax;
        y = ay;
        z = az;
    }
    
    float x, y, z;
}

struct Plane
{
    Vec3 normal;
    Vec3 position;
}

struct Sphere
{
    Vec3 position;
    float radius;
}

Vec3 pathTraceRay( Vec3 origin, Vec3 direction )
{
    return Vec3( 0, 0, 0 );
}

void main()
{
    Plane plane;
    plane.position = Vec3( 0, 0, 0 );
    plane.normal = Vec3( 0, 1, 0 );

    Sphere sphere;
    sphere.position = Vec3( 0, 0, -10 );
    sphere.radius = 3;

    immutable Vec3 cameraPosition = Vec3( 0, 10, 1 );
    immutable Vec3 camZ = normalize( cameraPosition );
    immutable Vec3 camX = normalize( cross( camZ, Vec3( 0, 0, 1 ) ) );
    immutable Vec3 camY = normalize( cross( camZ, camX ) );
    
    const int width = 1280;
    const int height = 720;

    immutable float dist = 1;
    immutable Vec3 center = cameraPosition - Vec3( dist * camZ.x, dist * camZ.y, dist * camZ.z );
    const float halfW = 0.5f;
    const float halfH = 0.5f;
    
    uint[ width * height ] imageData;

    for (int y = 0; y < height; ++y)
    {
        immutable float yR = -1 + 2 * (y / cast(float)height);
        
        for (int x = 0; x < width; ++x)
        {
            immutable float xR = -1 + 2 * (x / cast(float)width);
            immutable Vec3 fp = center + xR * Vec3( halfW * camX.x, halfW * camX.y, halfW * camX.z ) +
                                         yR * Vec3( halfH * camY.x, halfH * camY.y, halfH * camY.z );

            immutable Vec3 rayDirection = normalize( fp - cameraPosition );

            immutable Vec3 distance = cameraPosition - sphere.position;
            immutable float b = dot( distance, rayDirection );
            immutable float c = dot( distance, distance ) - sphere.radius;
            immutable float d = b * b - c;
        
            immutable float di = d > 0.0001f ? (-b - sqrt( d )) : -1.0f;
            imageData[ y * width + x ] = di > 0 ? 0x00FF0000 : 0x00000000;  
        }
    }

    writeBMP( imageData, width, height );
}
