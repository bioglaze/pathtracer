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

    Vec3 opBinary( string op )( Vec3 v ) const
    {
        static if (op == "+")
        {
            return Vec3( x + v.x, y + v.y, z + v.z );
        }
        else static if (op == "-")
        {
            return Vec3( x - v.x, y - v.y, z - v.z );
        }
        else static if (op == "*")
        {
            return Vec3( x * v.x, y * v.y, z * v.z );
        }
        else static assert( false, "operator " ~ op ~ " not implemented" );
    }

    Vec3 opBinary( string op )( float f ) const
    {
        static if (op == "*")
        {
            return Vec3( x * f, y * f, z * f );
        }
        else static assert( false, "operator " ~ op ~ " not implemented" );
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
    Plane[ 1 ] planes;
    planes[ 0 ].position = Vec3( 0, 0, 0 );
    planes[ 0 ].normal = Vec3( 0, 1, 0 );

    Sphere[ 3 ] spheres;
    spheres[ 0 ].position = Vec3( 0, 0, 0 );
    spheres[ 0 ].radius = 3;
    spheres[ 1 ].position = Vec3( 4, 0, 0 );
    spheres[ 1 ].radius = 3;
    spheres[ 2 ].position = Vec3( -3, 0, 0 );
    spheres[ 2 ].radius = 1.5f;

    immutable Vec3 cameraPosition = Vec3( 0, 1, 10 );
    immutable Vec3 camZ = Vec3( 0, 0, 1 );
    immutable Vec3 camX = normalize( cross( camZ, Vec3( 0, 1, 0 ) ) );
    immutable Vec3 camY = normalize( cross( camZ, camX ) );

    const int width = 1280;
    const int height = 720;

    immutable float dist = 1;
    immutable Vec3 center = cameraPosition - camZ * dist;
    const float halfW = 0.5f;
    const float halfH = 0.5f * height / cast(float)width;
    
    uint[ width * height ] imageData;

    for (int y = 0; y < height; ++y)
    {
        immutable float yR = -1 + 2 * (y / cast(float)height);
        
        for (int x = 0; x < width; ++x)
        {
            immutable float xR = -1 + 2 * (x / cast(float)width);
            immutable Vec3 fp = center + camX * halfW * xR + camY * halfH * yR;

            immutable Vec3 rayDirection = normalize( fp - cameraPosition );

            float closestDistance = float.max;
            int closestIndex = -1;

            for (int planeIndex = 0; planeIndex < planes.length; ++planeIndex)
            {
                immutable float distance = ( dot( planes[ planeIndex ].normal, planes[ planeIndex ].position ) - 
			                 dot( planes[ planeIndex ].normal, cameraPosition )) / 
			                 dot( planes[ planeIndex ].normal, rayDirection );

                if (distance > 0 && distance < closestDistance)
                {
                    closestDistance = distance;
                    closestIndex = planeIndex;
                }
            }
            
            for (int sphereIndex = 0; sphereIndex < spheres.length; ++sphereIndex)
            {
                immutable Vec3 sphereToCamera = cameraPosition - spheres[ sphereIndex ].position;
                immutable float b = dot( sphereToCamera, rayDirection );
                immutable float c = dot( sphereToCamera, sphereToCamera ) - spheres[ sphereIndex ].radius;
                immutable float d = b * b - c;
        
                immutable float di = d > 0.0001f ? (-b - sqrt( d )) : -1.0f;
                
                if (di > 0 && di < closestDistance)
                {
                    closestDistance = di;
                    closestIndex = sphereIndex;
                }                
            }

            if (closestIndex != -1)
            {
                imageData[ y * width + x ] = 0x00FF0000;
            }
            else
            {
                imageData[ y * width + x ] = 0x00000000;
            }
        }
    }

    writeBMP( imageData, width, height );
}
