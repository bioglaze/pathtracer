import std.stdio;
import std.math;
import std.random: uniform;

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

Vec3 reflect( Vec3 vec, Vec3 normal )
{
    return vec - normal * dot( normal, vec ) * 2;
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
    Vec3 color;
}

struct Sphere
{
    Vec3 position;
    float radius;
    Vec3 color;
}

Vec3 randomRayInHemisphere( Vec3 aNormal )
{
    Vec3 v2 = Vec3( uniform( -1.0f, 1.0f ), uniform( -1.0f, 1.0f ), uniform( -1.0f, 1.0f ) );
    normalize( v2 );

    while (v2.dot( v2 ) > 1.0f)
    {
        v2 = Vec3( uniform( -1.0f, 1.0f ), uniform( -1.0f, 1.0f ), uniform( -1.0f, 1.0f ) );
        normalize( v2 );
    }

    return v2 * ( dot( v2, aNormal ) < 0.0f ? -1.0f : 1.0f);
}

Vec3 pathTraceRay( Vec3 rayOrigin, Vec3 rayDirection, Plane[] planes, Sphere[] spheres, int recursion )
{
    float closestDistance = float.max;
    int closestIndex = -1;

    Vec3 hitPoint = Vec3( 0, 0, 0 );
    Vec3 hitNormal = Vec3( 0, 1, 0 );
    Vec3 hitColor = Vec3( 0, 0, 0 );

    const float tolerance = 0.003f;
    
    for (int planeIndex = 0; planeIndex < planes.length; ++planeIndex)
    {
        immutable float distance = ( dot( planes[ planeIndex ].normal, planes[ planeIndex ].position ) - 
                                     dot( planes[ planeIndex ].normal, rayOrigin )) / 
            dot( planes[ planeIndex ].normal, rayDirection );

        if (distance > tolerance && distance < closestDistance)
        {
            closestDistance = distance;
            closestIndex = planeIndex;
            hitPoint = rayOrigin + rayDirection * distance;
            hitNormal = planes[ planeIndex ].normal;
            hitColor = planes[ planeIndex ].color;
        }
    }
            
    for (int sphereIndex = 0; sphereIndex < spheres.length; ++sphereIndex)
    {
        immutable Vec3 sphereToCamera = rayOrigin - spheres[ sphereIndex ].position;
        immutable float b = dot( sphereToCamera, rayDirection );
        immutable float c = dot( sphereToCamera, sphereToCamera ) - spheres[ sphereIndex ].radius;
        immutable float d = b * b - c;
        
        immutable float di = d > tolerance ? (-b - sqrt( d )) : -1.0f;
                
        if (di > tolerance && di < closestDistance)
        {
            closestDistance = di;
            closestIndex = sphereIndex;
            hitPoint = rayOrigin + rayDirection * closestDistance;
            hitNormal = normalize( sphereToCamera );
            hitColor = spheres[ sphereIndex ].color;
        }                
    }

    if (recursion > 0 && closestIndex != -1)
    {
        immutable Vec3 reflectionDir = reflect( rayDirection, randomRayInHemisphere( hitNormal ) );
        immutable Vec3 reflectedColor = pathTraceRay( hitPoint, reflectionDir, planes, spheres, recursion - 1 );
        hitColor = hitColor + reflectedColor;
    }
    
    return hitColor;
}

uint encodeColor( Vec3 color )
{
    return cast(uint)(color.z * 255) + (cast(uint)(color.y * 255) << 8) + (cast(uint)(color.x * 255) << 16);
}

float toSRGB( float f )
{
    if (f > 1)
    {
        f = 1;
    }

    if (f < 0)
    {
        f = 0;
    }

    float s = f * 12.92f;

    if (s > 0.0031308f)
    {
        s = 1.055f * pow( f, 1 / 2.4f ) - 0.055f;
    }

    return s;
}

void main()
{
    Plane[ 1 ] planes;
    planes[ 0 ].position = Vec3( 0, 0, 0 );
    planes[ 0 ].normal = Vec3( 0, 1, 0 );
    planes[ 0 ].color = Vec3( 0, 0, 1 );
    
    Sphere[ 3 ] spheres;
    spheres[ 0 ].position = Vec3( 0, 0, -3 );
    spheres[ 0 ].radius = 3;
    spheres[ 0 ].color = Vec3( 1, 0, 0 );
    spheres[ 1 ].position = Vec3( 4, 0, 0 );
    spheres[ 1 ].radius = 3;
    spheres[ 1 ].color = Vec3( 0, 1, 0 );
    spheres[ 2 ].position = Vec3( -3, 0, 0 );
    spheres[ 2 ].radius = 1.5f;
    spheres[ 2 ].color = Vec3( 1, 1, 0 );

    immutable Vec3 cameraPosition = Vec3( 0, 1, 10 );
    immutable Vec3 camZ = Vec3( 0, 0, 1 );
    immutable Vec3 camX = normalize( cross( camZ, Vec3( 0, 1, 0 ) ) );
    immutable Vec3 camY = normalize( cross( camZ, camX ) );

    const int width = 1280;
    const int height = 720;

    immutable float dist = 1;
    immutable Vec3 center = cameraPosition - camZ * dist;

    float fW = 1;
    float fH = fW * height / cast(float)width;
    
    float halfW = 0.5f * fW;
    float halfH = 0.5f * fH;
    
    uint[ width * height ] imageData;

    const int sampleCount = 2;
    
    for (int y = 0; y < height; ++y)
    {
        immutable float yR = -1 + 2 * (y / cast(float)height);
            
        for (int x = 0; x < width; ++x)
        {
            Vec3 color = Vec3( 0, 0, 0 );
            
            for (int samples = 0; samples < sampleCount; ++samples)
            {
                immutable float xR = -1 + 2 * (x / cast(float)width);
                immutable Vec3 fp = center + camX * halfW * xR + camY * halfH * yR;

                immutable Vec3 rayDirection = normalize( fp - cameraPosition );

                color = color + pathTraceRay( cameraPosition, rayDirection, planes, spheres, 2 ) * (1.0f / sampleCount);
    
                if (color.x > 1)
                {
                    color.x = 1;
                }
                if (color.y > 1)
                {
                    color.y = 1;
                }
                if (color.z > 1)
                {
                    color.z = 1;
                }
            }

            imageData[ y * width + x ] = encodeColor( Vec3( toSRGB( color.x ), toSRGB( color.y ), toSRGB( color.z ) ) );                
        }
    }

            
    writeBMP( imageData, width, height );
}
