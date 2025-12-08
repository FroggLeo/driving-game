// credits:
// https://godotshaders.com/shader/rayleigh-mie-ozone-based-atmospheric-scatter/

shader_type sky;

const float EPS = 1e-6;
const float INFINITY = 1.0 / 0.0;
const float PLANET_RADIUS = 6371000.0;
const vec3 PLANET_CENTER = vec3(0.0, -PLANET_RADIUS, 0.0);
const float ATMOSPHERE_HEIGHT = 100000.0;
const float RAYLEIGH_HEIGHT = (ATMOSPHERE_HEIGHT * 0.08);
const float MIE_HEIGHT = (ATMOSPHERE_HEIGHT * 0.012);

uniform float rayleigh_strength : hint_range(0.0, 5.0) = 1.0;
uniform float mie_strength      : hint_range(0.0, 5.0) = 1.0;
uniform float ozone_strength    : hint_range(0.0, 5.0) = 1.0;

uniform sampler2D G_RAYLEIGH;
uniform sampler2D G_MIE;
uniform sampler2D G_OZONE;

const vec3 C_RAYLEIGH = vec3(5.802, 13.558, 33.100) * 1e-6;
const vec3 C_MIE = vec3(3.996,  3.996,  3.996) * 1e-6;
const vec3 C_OZONE = vec3(0.650,  1.881,  0.085) * 1e-6;

uniform float atmosphere_density: hint_range(0.0, 5.0) = 1.0;
uniform float exposure = 10.0;

uniform float sun_disc_feather: hint_range(0.0, 0.5) = 0.1;
uniform float sundisc_intensity = 10.0;

uniform bool use_debanding = true;

#define saturate(a) clamp(a, 0.0, 1.0)

vec2 sphere_intersection (vec3 rayStart, vec3 rayDir, vec3 sphereCenter, float sphereRadius)
{
	rayStart -= sphereCenter;
	float a = dot(rayDir, rayDir);
	float b = 2.0 * dot(rayStart, rayDir);
	float c = dot(rayStart, rayStart) - (sphereRadius * sphereRadius);
	float d = b * b - 4.0 * a * c;
	if (d < 0.0)
	{
		return vec2(-1.0);
	}
	else
	{
		d = sqrt(d);
		return vec2(-b - d, -b + d) / (2.0 * a);
	}
}

vec2 planet_intersection (vec3 rayStart, vec3 rayDir)
{
	return sphere_intersection(rayStart, rayDir, PLANET_CENTER, PLANET_RADIUS);
}

vec2 atmosphere_intersection (vec3 rayStart, vec3 rayDir)
{
	return sphere_intersection(rayStart, rayDir, PLANET_CENTER, PLANET_RADIUS + ATMOSPHERE_HEIGHT);
}

float phase_rayleigh (float costh)
{
	return 3.0 * (1.0 + costh*costh) / (16.0 * PI);
}

float phase_mie (float costh, float g)
{
	g = min(g, 0.9381);
	float k = 1.55*g - 0.55*g*g*g;
	float kcosth = k*costh;
	return (1.0 - k*k) / ((4.0 * PI) * (1.0-kcosth) * (1.0-kcosth));
}

float atmosphere_height (vec3 position_world_space) {
	return distance(position_world_space, PLANET_CENTER) - PLANET_RADIUS;
}
float density_rayleigh (float h) {
	return exp(-max(0.0, h / RAYLEIGH_HEIGHT));
}
float density_mie (float h) {
	return exp(-max(0.0, h / MIE_HEIGHT));
}
float density_ozone (float h) {
	return max(0.0, 1.0 - abs(h - 25000.0) / 15000.0);
}
vec3 density_atmosphere (float h) {
	return vec3(density_rayleigh(h), density_mie(h), density_ozone(h));
}

vec3 integrate_optical_depth (vec3 rayStart, vec3 rayDir)
{
	vec2 intersection = atmosphere_intersection(rayStart, rayDir);
	float  rayLength    = intersection.y;

	int    sampleCount  = 8;
	float  stepSize     = rayLength / float(sampleCount);

	vec3 opticalDepth = vec3(0.0);

	for (int i = 0; i < sampleCount; i++)
	{
		vec3 localPosition = rayStart + rayDir * (float(i) + 0.5) * stepSize;
		float localHeight  = atmosphere_height(localPosition);
		vec3 localDensity  = density_atmosphere(localHeight);

		opticalDepth += localDensity * stepSize;
	}

	return opticalDepth;
}

vec3 absorb (vec3 opticalDepth) {
	return exp(-(
		opticalDepth.x * C_RAYLEIGH * rayleigh_strength +
		opticalDepth.y * C_MIE * mie_strength * 1.1 +
		opticalDepth.z * C_OZONE * ozone_strength
	) * atmosphere_density);
}

vec3 integrate_scattering (vec3 rayStart, vec3 rayDir, float rayLength, vec3 lightDir, vec3 lightColor, out vec3 transmittance)
{
	float  rayHeight = atmosphere_height(rayStart);
	float  sampleDistributionExponent = 1.0 + saturate(1.0 - rayHeight / ATMOSPHERE_HEIGHT) * 8.0; // Slightly arbitrary max exponent of 9

	vec2 intersection = atmosphere_intersection(rayStart, rayDir);
	rayLength = min(rayLength, intersection.y);
	if (intersection.x > 0.0)
	{
		rayStart += rayDir * intersection.x;
		rayLength -= intersection.x;
	}

	float  costh    = dot(rayDir, lightDir);
	float  phaseR   = phase_rayleigh(costh);
	float  phaseM   = phase_mie(costh, 0.85);

	int    sampleCount  = 64;

	vec3 opticalDepth = vec3(0.0);
	vec3 rayleigh     = vec3(0.0);
	vec3 mie          = vec3(0.0);

	float  prevRayTime  = 0.0;

	for (int i = 0; i < sampleCount; i++)
	{
		float  rayTime = pow(float(i) / float(sampleCount), sampleDistributionExponent) * rayLength;
		float  stepSize = (rayTime - prevRayTime);

		vec3 localPosition = rayStart + rayDir * rayTime;
		float  localHeight   = atmosphere_height(localPosition);
		vec3 localDensity  = density_atmosphere(localHeight);

		opticalDepth += localDensity * stepSize;

		vec3 viewTransmittance = absorb(opticalDepth);

		vec3 opticalDepthlight  = integrate_optical_depth(localPosition, lightDir);
		vec3 lightTransmittance = absorb(opticalDepthlight);

		rayleigh += viewTransmittance * lightTransmittance * phaseR * localDensity.x * stepSize;
		mie      += viewTransmittance * lightTransmittance * phaseM * localDensity.y * stepSize;

		prevRayTime = rayTime;
	}

	transmittance = absorb(opticalDepth);

	return (rayleigh * C_RAYLEIGH * rayleigh_strength + mie * C_MIE * mie_strength) * lightColor * exposure;
}

float sun_disc(vec3 eyedir, vec3 sundir, float theta_r) {
	float cos_angle = dot(eyedir, sundir);
	float cos_inner = cos(theta_r * (1.0 - sun_disc_feather));
	float cos_outer = cos(theta_r * (1.0 + sun_disc_feather));
	return smoothstep(cos_outer, cos_inner, cos_angle);
}

float rand(vec2 co){
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void sky() {
	vec3 transmittance;
	vec3 radiance = integrate_scattering(vec3(0.0), EYEDIR, INFINITY, LIGHT0_DIRECTION, vec3(1.0, 0.996, 0.98), transmittance);

	float sun_mask = sun_disc(EYEDIR, LIGHT0_DIRECTION, LIGHT0_SIZE * 0.5);
	vec3 sundisc = vec3(sun_mask) * transmittance * sundisc_intensity;

	COLOR = radiance + sundisc;

	if (use_debanding) {
		COLOR += (rand(SKY_COORDS) - 0.5) * 0.001;
	}
}