import std.stdio;
import std.math;
import std.random: uniform;
import image;

// TODO:
// Refraction
// Transparency
// Mipmapping

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

    Vec3 opUnary( string op )() const
    {
        static if (op == "-")
        {
            return Vec3( -x, -y, -z );
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
    float smoothness;
    float emission;
}

struct Sphere
{
    Vec3 position;
    float radius;
    Vec3 color;
    float smoothness;
    float emission;
}

struct Triangle
{
    Vec3 v0, v1, v2;
    Vec3 normal;
    Vec3 color;
    float smoothness;
    float emission;
}

Vec3 randomRayInHemisphere( Vec3 aNormal )
{
    Vec3 v2 = Vec3( uniform( -1.0f, 1.0f ), uniform( -1.0f, 1.0f ), uniform( -1.0f, 1.0f ) );
    v2 = normalize( v2 );

    float d = 2;
    
    while (d > 1.0f)
    {
        v2 = Vec3( uniform( -1.0f, 1.0f ), uniform( -1.0f, 1.0f ), uniform( -1.0f, 1.0f ) );
        d = sqrt( v2.x * v2.x + v2.y * v2.y + v2.z * v2.z );
    }

    v2.x /= d;
    v2.y /= d;
    v2.z /= d;
    
    return v2 * ( dot( v2, aNormal ) < 0.0f ? -1.0f : 1.0f);
}

Vec3 lerp( Vec3 v1, Vec3 v2, float amount )
{
    return Vec3( v1.x + (v2.x - v1.x) * amount,
                 v1.y + (v2.y - v1.y) * amount,
                 v1.z + (v2.z - v1.z) * amount );
}

Vec3 pathTraceRay( Vec3 rayOrigin, Vec3 rayDirection, Plane[] planes, Sphere[] spheres, Triangle[] triangles, int recursion )
{
    float closestDistance = float.max;
    int closestIndex = -1;

    Vec3 hitPoint = Vec3( 0, 0, 0 );
    Vec3 hitNormal = Vec3( 0, 1, 0 );
    Vec3 hitColor = Vec3( 0, 0, 0 );
    float hitSmoothness = 0;
    float hitEmission = 0;
    
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
            immutable float sines = sin( 10 * hitPoint.x ) * sin( 10 * hitPoint.y ) * sin( 10 * hitPoint.z );
            //hitColor = sines < 0 ? planes[ planeIndex ].color : Vec3( 1, 0, 0 );
            hitColor = sines < 0 ? Vec3( 1, 1, 1 ) : planes[ planeIndex ].color;
            hitSmoothness = planes[ planeIndex ].smoothness;
            hitEmission = planes[ planeIndex ].emission;
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
            hitSmoothness = spheres[ sphereIndex ].smoothness;
            hitEmission = spheres[ sphereIndex ].emission;
        }                
    }

    for (int triangleIndex = 0; triangleIndex < triangles.length; ++triangleIndex)
    {
        // Algorithm source: http://geomalgorithms.com/a06-_intersect-2.html#intersect_RayTriangle()
        immutable Vec3 vn1 = triangles[ triangleIndex ].v1 - triangles[ triangleIndex ].v0;
        immutable Vec3 vn2 = triangles[ triangleIndex ].v2 - triangles[ triangleIndex ].v0;

        immutable float distance = -dot( rayOrigin - triangles[ triangleIndex ].v0, triangles[ triangleIndex].normal ) / dot( rayDirection, triangles[ triangleIndex].normal );

        if (distance < 0.003f)
        {
            continue;
        }

        immutable Vec3 hitp = rayOrigin + rayDirection * distance;

        // Is hit point inside the triangle?
        immutable float uu = dot( vn1, vn1 );
        immutable float uv = dot( vn1, vn2 );
        immutable float vv = dot( vn2, vn2 );
        immutable Vec3 w = hitp - triangles[ triangleIndex].v0;
        immutable float wu = dot( w, vn1 );
        immutable float wv = dot( w, vn2 );
        immutable float D = uv * uv - uu * vv;
        
        // get and test parametric coords
        immutable float s = (uv * wv - vv * wu) / D;
        
        if (s <= 0.0f || s >= 1.0f)
        {
            continue;
        }
        
        float t = (uv * wu - uu * wv) / D;
        
        if (t <= 0.0f || (s + t) >= 1.0f)
        {
            continue;
        }

        closestDistance = t;
        closestIndex = triangleIndex;
        hitPoint = hitp;
        hitNormal = triangles[ triangleIndex ].normal;
        hitColor = triangles[ triangleIndex ].color;
        hitSmoothness = triangles[ triangleIndex ].smoothness;        
        hitEmission = triangles[ triangleIndex ].emission;
    }

    if (hitEmission > 0)
    {
        return hitColor * hitEmission;
    }
    
    if (recursion > 0 && closestIndex != -1)
    {
        immutable Vec3 reflectionDir = reflect( rayDirection, hitNormal );
        //immutable Vec3 jitteredReflectionDir = normalize( reflectionDir + Vec3( uniform( -1.0f, 1.0f ), uniform( -1.0f, 1.0f ), uniform( -1.0f, 1.0f ) ) );
        immutable Vec3 jitteredReflectionDir = normalize( randomRayInHemisphere( reflectionDir ) );
        immutable Vec3 finalReflectionDir = lerp( jitteredReflectionDir, reflectionDir, hitSmoothness );
        immutable Vec3 reflectedColor = pathTraceRay( hitPoint, finalReflectionDir, planes, spheres, triangles, recursion - 1 );
        hitColor = (hitColor + Vec3( hitEmission, hitEmission, hitEmission ) ) * reflectedColor;
        return hitColor;
    }
    
    return Vec3( 0, 0, 0 );
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
    Plane[ 5 ] planes;
    planes[ 0 ].position = Vec3( 0, 5, 0 );
    planes[ 0 ].normal = Vec3( 0, -1, 0 );
    planes[ 0 ].color = Vec3( 0.8f, 0.8f, 0.8f );
    planes[ 0 ].smoothness = 0.2f;
    planes[ 0 ].emission = 1;
    
    planes[ 1 ].position = Vec3( 0, -5, 0 );
    planes[ 1 ].normal = Vec3( 0, 1, 0 );
    planes[ 1 ].color = Vec3( 0.5f, 1.0f, 0.5f );
    planes[ 1 ].smoothness = 0.2f;
    planes[ 1 ].emission = 0;

    planes[ 2 ].position = Vec3( -10, 0, 0 );
    planes[ 2 ].normal = Vec3( 1, 0, 0 );
    planes[ 2 ].color = Vec3( 1, 0, 0 );
    planes[ 2 ].smoothness = 0.2f;
    planes[ 2 ].emission = 0;

    planes[ 3 ].position = Vec3( 10, 0, 0 );
    planes[ 3 ].normal = Vec3( -1, 0, 0 );
    planes[ 3 ].color = Vec3( 0, 1, 0 );
    planes[ 3 ].smoothness = 0.2f;
    planes[ 3 ].emission = 0;

    planes[ 4 ].position = Vec3( 0, 0, -40 );
    planes[ 4 ].normal = Vec3( 0, 0, 1 );
    planes[ 4 ].color = Vec3( 1, 1, 0 );
    planes[ 4 ].smoothness = 0.2f;
    planes[ 4 ].emission = 0;

    Sphere[ 4 ] spheres;
    spheres[ 0 ].position = Vec3( -8, -4, -30 );
    spheres[ 0 ].radius = 5;
    spheres[ 0 ].color = Vec3( 0, 0, 1 );
    spheres[ 0 ].smoothness = 0.9f;
    spheres[ 0 ].emission = 0;
    
    spheres[ 1 ].position = Vec3( 0, -0.5f, -12 );
    spheres[ 1 ].radius = 3;
    spheres[ 1 ].color = Vec3( 0, 1, 0 );
    spheres[ 1 ].smoothness = 0.5f;
    spheres[ 1 ].emission = 0;
    
    spheres[ 2 ].position = Vec3( 8, -4, -30 );
    spheres[ 2 ].radius = 5;
    spheres[ 2 ].color = Vec3( 1, 0, 0 );
    spheres[ 2 ].smoothness = 0.2f;
    spheres[ 2 ].emission = 0;

    spheres[ 3 ].position = Vec3( 4, 5, -30 );
    spheres[ 3 ].radius = 2;
    spheres[ 3 ].color = Vec3( 0.5f, 0.5f, 0.5f );
    spheres[ 3 ].smoothness = 0.2f;
    spheres[ 3 ].emission = 1;

    Triangle[ 1 ] triangles;
    triangles[ 0 ].v0 = Vec3( 8, -2, -30 );
    triangles[ 0 ].v1 = Vec3( 14, -2, -30 );
    triangles[ 0 ].v2 = Vec3( 8, -0, -30 );
    triangles[ 0 ].normal = Vec3( 0, 0, -1 );
    triangles[ 0 ].color = Vec3( 1, 0, 0 );
    triangles[ 0 ].smoothness = 0.2f;
    triangles[ 0 ].emission = 0;

    Texture tex;
    readTGA( "wall1.tga", tex );
    
    immutable Vec3 cameraPosition = Vec3( 0, 0, 0 );
    immutable Vec3 camZ = Vec3( 0, 0, 1 );
    immutable Vec3 camX = normalize( cross( camZ, Vec3( 0, 1, 0 ) ) );
    immutable Vec3 camY = normalize( cross( camZ, camX ) );

    const int width = 1280;
    const int height = 720;

    immutable float dist = 1;
    immutable Vec3 center = cameraPosition - camZ * dist;

    immutable float fW = 1;
    immutable float fH = fW * height / cast(float)width;
    
    immutable float halfW = 0.5f * fW;
    immutable float halfH = 0.5f * fH;
    
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

                color = color + pathTraceRay( cameraPosition, rayDirection, planes, spheres, triangles, 2 ) * (1.0f / sampleCount);
    
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
