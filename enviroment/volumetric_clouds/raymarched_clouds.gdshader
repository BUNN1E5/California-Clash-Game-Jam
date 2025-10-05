shader_type spatial;

render_mode cull_disabled;
render_mode unshaded;

uniform sampler2D _mainTex;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

uniform vec3 _sunPosition;

#include "res://enviroment/volumetric_clouds/noise.gdshaderinc"

#define MAX_STEPS 100

float sdSphere(vec3 p, float radius) {
  return length(p) - radius;
}

float scene(vec3 p) {
  float distance = sdSphere(p, 1.0);

  float f = fbm(p);

  return -distance + f;
}

const vec3 SUN_POSITION = vec3(1.0, 0.0, 0.0);
const float MARCH_SIZE = 0.08;

vec4 raymarch(vec3 rayOrigin, vec3 rayDirection) {
  float depth = 0.0;
  vec3 p = rayOrigin + depth * rayDirection;
  vec3 sunDirection = normalize(SUN_POSITION);

  vec4 res = vec4(0.0);

  for (int i = 0; i < MAX_STEPS; i++) {
    float density = scene(p);

    // We only draw the density if it's greater than 0
    if (density > 0.0) {
      // Directional derivative
      // For fast diffuse lighting
      float diffuse = clamp((scene(p) - scene(p + 0.3 * sunDirection)) / 0.3, 0.0, 1.0 );
      vec3 lin = vec3(0.60,0.60,0.75) * 1.1 + 0.8 * vec3(1.0,0.6,0.3) * diffuse;
      vec4 color = vec4(mix(vec3(1.0, 1.0, 1.0), vec3(0.0, 0.0, 0.0), density), density );
      color.rgb *= lin;
      color.rgb *= color.a;
      res += color * (1.0 - res.a);
    }

    depth += MARCH_SIZE;
    p = rayOrigin + depth * rayDirection;
  }

  return res;
}

void fragment() {
	vec2 uv = (FRAGCOORD.xy * 2. - VIEWPORT_SIZE.xy) / VIEWPORT_SIZE.y;
	//ro = Ray Origin || rd = ray direction
	vec3 ro = CAMERA_POSITION_WORLD;
	vec3 rd = normalize((INV_VIEW_MATRIX * vec4(VERTEX, 1)).xyz - ro);

	vec3 color = vec3(0.0);

	// Sun and Sky
	vec3 sunDirection = normalize(SUN_POSITION);
	float sun = clamp(dot(sunDirection, rd), 0.0, 1.0 );
	// Base sky color
	color = vec3(0.7,0.7,0.90);
	// Add vertical gradient
	color -= 0.8 * vec3(0.90,0.75,0.90) * rd.y;
	// Add sun color to sky
	color += 0.5 * vec3(1.0,0.5,0.3) * pow(sun, 10.0);

	// Cloud
	vec4 res = raymarch(ro, rd);
	color = color * (1.0 - res.a) + res.rgb;

	ALBEDO = color;
	ALPHA = res.a;
}


void vertex() {}