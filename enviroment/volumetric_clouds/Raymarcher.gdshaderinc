#include "res://enviroment/volumetric_clouds/noise.gdshaderinc"
#define ITERATIONS 5
#define EPSILON .01
#define MAX_DIST 10.

float sdSphere(vec3 p, float radius) {
  return length(p) - radius;
}

struct Ray{
	float dist;
	int iterations;
	vec4 color;
	bool exit_early;
};

Ray map(in vec3 p){
	Ray r;
	float distance = sdSphere(p, 1.0);

  	float f = fbm(p);

  	r.dist = 1. - distance + f;
	return r;
}

// https://iquilezles.org/articles/normalsSDF
vec3 calcNormal( in vec3 pos){
    vec2 e = vec2(1.0,-1.0)*0.5773;
    const float eps = 0.0005;
    return normalize( e.xyy*map( pos + e.xyy*eps ).dist +
					  e.yyx*map( pos + e.yyx*eps ).dist +
					  e.yxy*map( pos + e.yxy*eps ).dist +
					  e.xxx*map( pos + e.xxx*eps ).dist );
}

vec2 calcUV(in vec3 pos, in mat4 object_transform){
	// Transform hit position from world space to object (local) space.
	vec3 localPos = (inverse(object_transform) * vec4(pos, 1.0)).xyz;

	// Now use localPos for UV mapping.
	// For triplanar mapping in local space:
	vec3 n_local = normalize(calcNormal(localPos));
	vec2 uv_x = vec2(localPos.y, localPos.z);
	vec2 uv_y = vec2(localPos.x, localPos.z);
	vec2 uv_z = vec2(localPos.x, localPos.y);
	return (abs(n_local.x) * uv_x + abs(n_local.y) * uv_y + abs(n_local.z) * uv_z) /
	          (abs(n_local.x) + abs(n_local.y) + abs(n_local.z));
}
//segment tracing


varying vec3 SUN_POSITION;
const float MARCH_SIZE = 0.08;
//This tutorial a huge help here!
//https://www.youtube.com/watch?v=khblXafu7iA
Ray raymarch(vec3 ro, vec3 rd){
	Ray r;
	r.dist = 0.;
	r.iterations = 0;
	r.exit_early = false;
	
	vec3 sunDirection = normalize(SUN_POSITION);

    for( int i=0; i < ITERATIONS; i++ ){
		r.iterations = i;
		vec3 pos = ro + rd * r.dist; //position along ray
        float d = map(pos).dist; //current dist to scene
		r.dist += d;
		if (d > 0.0) {
			// Directional derivative
			// For fast diffuse lighting
			float diffuse = clamp((map(pos).dist - map(pos + 0.3 * sunDirection).dist) / 0.3, 0.0, 1.0 );
			vec3 lin = vec3(0.60,0.60,0.75) * 1.1 + 0.8 * vec3(1.0,0.6,0.3) * diffuse;
			vec4 color = vec4(mix(vec3(1.0, 1.0, 1.0), vec3(0.0, 0.0, 0.0), d), d );
			color.rgb *= lin;
			color.rgb *= color.a;
			r.color += color * (1.0 - r.color.a);
		}
		if(d < EPSILON * r.dist) break; //early stop
		if(r.dist > MAX_DIST) {
			r.exit_early = true;
			return r;
		}
    }
	return r;
}
