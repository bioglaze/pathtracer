import core.simd;
import std.concurrency;
import std.math;
import std.stdio;
import std.random: uniform;
import image;

// TODO:
// SIMD
// Refraction
// Transparency
// Mipmapping
// Threading
// Anti-aliasing

/*struct sVec3
{
    float4 x;
    float4 y;
    float4 z;
    }*/

 // https://stackoverflow.com/questions/4120681/how-to-calculate-vector-dot-product-using-sse-intrinsic-functions-in-c
float4 dot4( float4 a, float4 b )
{
    float4 mulRes = __simd( XMM.MULPS, a, b );
    float4 shufReg = __simd( XMM.MOVSHDUP, mulRes );
    float4 sumsReg = __simd( XMM.ADDPS, mulRes, shufReg );
    shufReg = __simd( XMM.MOVHLPS, shufReg, sumsReg );
    sumsReg = __simd( XMM.ADDSS, sumsReg, shufReg );
    return __simd( XMM.CVTSS2SD, sumsReg );
}

Texture tex;

Vec3 normalize( Vec3 v )
{
    immutable float length = sqrt( v.x * v.x + v.y * v.y + v.z * v.z );
    
    return v / length;
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
        else static if (op == "/")
        {
            return Vec3( x / f, y / f, z / f );
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

// http://entropymine.com/imageworsener/srgbformula/
float sRGBToLinear( float s )
{
    if (s > 1)
    {
        s = 1;
    }

    if (s < 0)
    {
        s = 0;
    }

    if (s >= 0 && s <= 0.0404482362771082f)
    {
        return s / 12.92f;
    }

    if (s > 0.0404482362771082f && s <= 1)
    {
        return pow( (s + 0.055f) / 1.055f, 2.4f );
    }

    return 0;
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

Vec3 RandomUnitVector()
{
    float z = uniform( 0.0f, 1.0f ) * 2.0f - 1.0f;
    float a = uniform( 0.0f, 1.0f ) * 2.0f * 3.14159265f;
    float r = sqrt( 1.0f - z * z );
    float x = r * cos( a );
    float y = r * sin( a );
    return Vec3( x, y, z );
}

Vec3 lerp( Vec3 v1, Vec3 v2, float amount )
{
    return Vec3( v1.x + (v2.x - v1.x) * amount,
                 v1.y + (v2.y - v1.y) * amount,
                 v1.z + (v2.z - v1.z) * amount );
}

Vec3 pathTraceRay( Vec3 rayOrigin, Vec3 rayDirection, Plane[] planes, Sphere[] spheres, Triangle[] triangles, int recursion )
{
    if (recursion == 0)
    {
        return Vec3( 0, 0, 0 );
    }
    
    float closestDistance = float.max;
    int closestIndex = -1;
    Vec3 closestTextureColor = Vec3( 0, 0, 0 );
    
    Vec3 hitPoint = Vec3( 0, 0, 0 );
    Vec3 hitNormal = Vec3( 0, 1, 0 );
    Vec3 hitColor = Vec3( 0, 0, 0 );
    float hitSmoothness = 0;
    float hitEmission = 0;

    enum ClosestType { Plane, Sphere, Triangle }
    ClosestType closestType;
    
    const float tolerance = 0.0003f;
    
    for (int planeIndex = 0; planeIndex < planes.length; ++planeIndex)
    {
        immutable float distance = ( dot( planes[ planeIndex ].normal, planes[ planeIndex ].position ) - 
                                     dot( planes[ planeIndex ].normal, rayOrigin )) / 
            dot( planes[ planeIndex ].normal, rayDirection );

        if (distance > tolerance && distance < closestDistance)
        {
            closestDistance = distance;
            closestIndex = planeIndex;
            closestType = ClosestType.Plane;
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
            closestType = ClosestType.Sphere;
            hitPoint = rayOrigin + rayDirection * closestDistance;
            hitNormal = normalize( sphereToCamera );
            hitColor = spheres[ sphereIndex ].color;
            hitSmoothness = spheres[ sphereIndex ].smoothness;
            hitEmission = spheres[ sphereIndex ].emission;
        }                
    }

    /*for (int triangleIndex = 0; triangleIndex < triangles.length; ++triangleIndex)
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
        
        immutable float t = (uv * wu - uu * wv) / D;
        
        if (t <= 0.0f || (s + t) >= 1.0f)
        {
            continue;
        }

        immutable int offs = cast(int)(t * tex.height * tex.width + s * tex.width) * 4;
        closestTextureColor.z = tex.pixels[ offs + 0 ] / 255.0f;
        closestTextureColor.y = tex.pixels[ offs + 1 ] / 255.0f;
        closestTextureColor.x = tex.pixels[ offs + 2 ] / 255.0f;
        
        closestDistance = t;
        closestIndex = triangleIndex;
        closestType = ClosestType.Triangle;
    }*/

    // Optimized
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
        
        immutable float t = (uv * wu - uu * wv) / D;
        
        if (t <= 0.0f || (s + t) >= 1.0f)
        {
            continue;
        }

        immutable int offs = cast(int)(t * tex.height * tex.width + s * tex.width) * 4;
        closestTextureColor.z = sRGBToLinear( tex.pixels[ offs + 0 ] / 255.0f );
        closestTextureColor.y = sRGBToLinear( tex.pixels[ offs + 1 ] / 255.0f );
        closestTextureColor.x = sRGBToLinear( tex.pixels[ offs + 2 ] / 255.0f );
        
        closestDistance = t;
        closestIndex = triangleIndex;
        closestType = ClosestType.Triangle;
    }

    if (hitEmission > 0)
    {
        return hitColor * hitEmission;
    }

    if (closestIndex > -1 && closestType == ClosestType.Plane)
    {
        hitPoint = rayOrigin + rayDirection * closestDistance;
        hitNormal = planes[ closestIndex ].normal;
        //immutable float sines = sin( 10 * hitPoint.x ) * sin( 10 * hitPoint.y ) * sin( 10 * hitPoint.z );
        //hitColor = sines < 0 ? Vec3( 1, 1, 1 ) : planes[ closestIndex ].color;
        hitColor = planes[ closestIndex ].color;
        hitSmoothness = planes[ closestIndex ].smoothness;
        hitEmission = planes[ closestIndex ].emission;
    }
    else if (closestIndex > -1 && closestType == ClosestType.Triangle)
    { 
        hitPoint = rayOrigin + rayDirection * closestDistance;
        hitNormal = triangles[ closestIndex ].normal;
        hitColor = closestTextureColor;//triangles[ closestIndex ].color;
        hitSmoothness = triangles[ closestIndex ].smoothness;
        hitEmission = triangles[ closestIndex ].emission;
    }
    
    if (recursion > 0 && closestIndex != -1)
    {
        //immutable Vec3 reflectionDir = normalize( reflect( rayDirection, hitNormal ) );
        //immutable Vec3 jitteredReflectionDir = normalize( randomRayInHemisphere( reflectionDir ) );
        //immutable Vec3 finalReflectionDir = lerp( jitteredReflectionDir, reflectionDir, 0/*hitSmoothness*/ );
        immutable Vec3 finalReflectionDir = normalize( hitNormal + RandomUnitVector() );
        //immutable Vec3 finalReflectionDir = normalize( randomRayInHemisphere( hitNormal ) );
        
        // BRDF
        float cosTheta = dot( finalReflectionDir, hitNormal );

        if (cosTheta < 0)
        {
            cosTheta = -cosTheta;
        }

        Vec3 startPoint = hitPoint + hitNormal * 0.01;
        immutable Vec3 reflectedColor1 = pathTraceRay( startPoint, finalReflectionDir, planes, spheres, triangles, recursion - 1 );

        //immutable Vec3 dirToEmissive = normalize( spheres[ 3 ].position - hitPoint );
        
        //immutable Vec3 reflectedColorTowardEmissive = pathTraceRay( hitPoint, dirToEmissive, planes, spheres, triangles, recursion - 1 );
        immutable Vec3 reflectedColor = reflectedColor1;// + reflectedColorTowardEmissive;
        
        immutable Vec3 brdf = hitColor / 3.14159265f;        
        immutable float p = 1.0f / (2.0f * 3.14159265f);
        
        return Vec3( hitEmission, hitEmission, hitEmission ) + (brdf * reflectedColor * cosTheta / p);
    }
    if (recursion > 0 && closestIndex == -1)
    {
        return Vec3( 0.5f, 0.5f, 0.8f );
    }
    
    return Vec3( 0, 0, 0 );
}

const int width = 1280;
const int height = 720;

static uint[ width * height ] imageData;

void traceRays( Tid owner, int startY, int endY, int width, int height/*, uint[] imageData*/, Plane[] planes, Sphere[] spheres, Triangle[] triangles )
{
    immutable Vec3 cameraPosition = Vec3( 0, 0, 0 );
    immutable Vec3 camZ = Vec3( 0, 0, 1 );
    immutable Vec3 camX = normalize( cross( camZ, Vec3( 0, 1, 0 ) ) );
    immutable Vec3 camY = normalize( cross( camZ, camX ) );

    immutable float dist = 1;
    immutable Vec3 center = cameraPosition - camZ * dist;

    immutable float fW = 1;
    immutable float fH = fW * height / cast(float)width;
    
    immutable float halfW = 0.5f * fW;
    immutable float halfH = 0.5f * fH;

    const int sampleCount = 4;
    int percent = 0;

    for (int y = startY; y < endY; ++y)
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

                color = color + pathTraceRay( cameraPosition, rayDirection, planes, spheres, triangles, 8 ) * (1.0f / sampleCount);
    
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

                if (color.x < 0)
                {
                    writeln( "x < 0" );
                }
                if (color.y < 0)
                {
                    writeln( "y < 0" );
                }
                if (color.z < 0)
                {
                    writeln( "z < 0" );
                }
            }

            imageData[ y * width + x ] = encodeColor( Vec3( toSRGB( color.x ), toSRGB( color.y ), toSRGB( color.z ) ) );                
        }

        if ((y % (height / 10)) == 0)
        {
            writeln( percent, " %" );
            percent += 10;
        }
    }

    owner.send( true );
}

void main()
{
    Plane[ 6 ] planes;
    planes[ 0 ].position = Vec3( 0, 5, 0 );
    planes[ 0 ].normal = Vec3( 0, -1, 0 );
    planes[ 0 ].color = Vec3( 0.8f, 0.8f, 0.8f );
    planes[ 0 ].smoothness = 1.0f;
    planes[ 0 ].emission = 1;
    
    planes[ 1 ].position = Vec3( 0, -5, 0 );
    planes[ 1 ].normal = Vec3( 0, 1, 0 );
    planes[ 1 ].color = Vec3( 1.0f, 0.5f, 0.5f );
    planes[ 1 ].smoothness = 1.0f;
    planes[ 1 ].emission = 0;

    planes[ 2 ].position = Vec3( -10, 0, 0 );
    planes[ 2 ].normal = Vec3( 1, 0, 0 );
    planes[ 2 ].color = Vec3( 1, 0, 0 );
    planes[ 2 ].smoothness = 1.0f;
    planes[ 2 ].emission = 0;

    planes[ 3 ].position = Vec3( 10, 0, 0 );
    planes[ 3 ].normal = Vec3( -1, 0, 0 );
    planes[ 3 ].color = Vec3( 0, 1, 0 );
    planes[ 3 ].smoothness = 1.0f;
    planes[ 3 ].emission = 0;

    planes[ 4 ].position = Vec3( 0, 0, -40 );
    planes[ 4 ].normal = Vec3( 0, 0, 1 );
    planes[ 4 ].color = Vec3( 1, 1, 0 );
    planes[ 4 ].smoothness = 1.0f;
    planes[ 4 ].emission = 0;

    planes[ 5 ].position = Vec3( 0, 0, 40 );
    planes[ 5 ].normal = Vec3( 0, 0, -1 );
    planes[ 5 ].color = Vec3( 1, 1, 0 );
    planes[ 5 ].smoothness = 1.0f;
    planes[ 5 ].emission = 0;

    Sphere[ 3 ] spheres;
    spheres[ 0 ].position = Vec3( -8, -4, -30 );
    spheres[ 0 ].radius = 3;
    spheres[ 0 ].color = Vec3( 0, 0, 1 );
    spheres[ 0 ].smoothness = 1.0f;
    spheres[ 0 ].emission = 0;
    
    spheres[ 1 ].position = Vec3( 0, -4, -30 );
    spheres[ 1 ].radius = 3;
    spheres[ 1 ].color = Vec3( 0, 1, 0 );
    spheres[ 1 ].smoothness = 1.0f;
    spheres[ 1 ].emission = 0;
    
    spheres[ 2 ].position = Vec3( 8, -4, -30 );
    spheres[ 2 ].radius = 3;
    spheres[ 2 ].color = Vec3( 1, 0, 0 );
    spheres[ 2 ].smoothness = 1.0f;
    spheres[ 2 ].emission = 0;

    Triangle[ 1 ] triangles;
    triangles[ 0 ].v0 = Vec3( 8, -2, -30 );
    triangles[ 0 ].v1 = Vec3( 14, -2, -30 );
    triangles[ 0 ].v2 = Vec3( 8, -0, -30 );
    immutable Vec3 p1 = triangles[ 0 ].v1 - triangles[ 0 ].v0;
    immutable Vec3 p2 = triangles[ 0 ].v2 - triangles[ 0 ].v0;
    triangles[ 0 ].normal = normalize( cross( p1, p2 ) );
    triangles[ 0 ].color = Vec3( 1, 0, 0 );
    triangles[ 0 ].smoothness = 0.2f;
    triangles[ 0 ].emission = 0;
    
    /*for (int i = 1; i < 10; ++i)
    {
        triangles[ i ].v0 = Vec3( 4 + i * 2 , -4, -30 );
        triangles[ i ].v1 = Vec3( 6 + i * 2, -4, -30 );
        triangles[ i ].v2 = Vec3( 4 + i * 2, -0, -30 );
        immutable Vec3 p3 = triangles[ i ].v1 - triangles[ i ].v0;
        immutable Vec3 p4 = triangles[ i ].v2 - triangles[ i ].v0;
        triangles[ i ].normal = normalize( cross( p3, p4 ) );
        triangles[ i ].color = Vec3( 1, 0, 0 );
        triangles[ i ].smoothness = 0.2f;
        triangles[ i ].emission = 0;
        }*/
    
    readTGA( "wall1.tga", tex );

    traceRays( thisTid, 0, height, width, height, planes, spheres, triangles );
    
    //auto tId1 = spawn( &traceRays, thisTid, 0, height, width, height, planes, spheres, triangles );
    //auto tId2 = spawn( &traceRays, thisTid, height / 2, height, width, height, planes, spheres, triangles );
    //auto isDone = receiveOnly!bool;
    writeln( "100 %" );
            
    writeBMP( imageData, width, height );
}
