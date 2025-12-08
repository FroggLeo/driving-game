shader_type sky;

// sky color credits
// https://www.figma.com/community/file/967898387862224533/sky-gradient-library

// updated by the script
uniform vec3 sun_rotation;

// TODO change to arrays of colors
uniform vec3 sunTint: source_color;

uniform vec3 zenithColor: source_color;
uniform vec3 horizonColor: source_color;

void sky() {
	// gets the direction of where the camera is looking
	vec3 direction = normalize(EYEDIR);
	// blend factor of the horizon and zenith
	// changes -1..1 to 0..1
	// so that at the bottom, the factor is 0 and the top the factor is 1
	float t = direction.y * 0.5 + 0.5;
	
	// 
	vec3 color = mix(horizonColor, zenithColor, t);
	
	vec3 sun_direction = normalize(sun_rotation);
	
	float towards_sun = max(dot(direction, sun_direction), 0);
	float sun_factor = pow(towards_sun, 90.0);
	
	color = mix(color, sunTint, sun_factor);
	COLOR = EYEDIR;
}

