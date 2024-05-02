#version 330

#define SATURATION .40
#define SHARPNESS .15
#define DIM .10 //dims only light pixels (close to white)
#define DIMSLOPE 1 //the less value the more other colours affected
#define LUM 0.00 //float 0-1 where 1 is full whitescreen (danger!)
/*
#define R R_VALUE
#define G G_VALUE
#define B B_VALUE
*/

in vec2 texcoord;
uniform sampler2D tex;

/*vec4 default_post_processing(vec4 c);*/

vec4 getColor(sampler2D tex, vec2 texcoord)
{
	vec2 texsize = textureSize(tex, 0);
    	vec4 c = texture2D(tex, texcoord/texsize, 0);
	return c;
}

vec4 getSharpenedColor(sampler2D tex, vec2 texcoord)
{
	vec2 texsize = textureSize(tex, 0);

	vec4 up = texture2D(tex, (texcoord+vec2(0,1))/texsize, 0);
    	vec4 left = texture2D(tex, (texcoord+vec2(-1,0))/texsize, 0);
    	vec4 center = texture2D(tex, texcoord/texsize, 0);
    	vec4 right = texture2D(tex, (texcoord+vec2(1,0))/texsize, 0);
    	vec4 down = texture2D(tex, (texcoord+vec2(0,-1))/texsize, 0);
    
	vec4 c = (1.0 + 4.0*SHARPNESS)*center -SHARPNESS*(up + left + right + down);
	return c;
}

vec4 saturate(vec4 color)
{
	//vec3 intensity = vec3(dot(color.rgb, vec3(0.2125, 0.7154, 0.0721))); //???
	vec3 intensity = vec3((color.r + color.g + color.b) / 3); //brightness based
    	color.rgb = mix(intensity, color.rgb, SATURATION);
	return color;
}

float remap(float value, float min1, float max1, float min2, float max2) 
{
  return min2 + (value - min1) * (max2 - min2) / (max1 - min1);
}

vec4 dimWhites(vec4 color)
{
	//float whitenessdot = dot(normalize(color.rgb), vec3(0.57735, 0.57735, 0.57735));
	//float whiteness = remap(whitenessdot, 0.5, 1, 0, 1);
	//float whiteness = (whitenessdot-0.5)*2;
	float whiteness = (color.r + color.g + color.b) / 3; //brightness based
	//float whiteness = dot(color.rgb, vec3(0.2125, 0.7154, 0.0721)); //luminance based
	float slopedwhiteness = pow(whiteness,DIMSLOPE)*DIM;
	color.rgb = color.rgb * (1-slopedwhiteness);
    	//color.rgb = color.rgb * (pow(1-whiteness*DIM, DIMSLOPE));
	//color.rgb = color.rgb * (1-whiteness*DIM); //darken whites

	color.rgb = color.rgb + (1-whiteness)*LUM; //brighten blacks
	return color;
}

vec4 brightenBlacks(vec4 color)
{
	float whiteness = (color.r + color.g + color.b) / 3;
	color.rgb = color.rgb + (1-whiteness)*LUM; //brighten blacks
	return color;
}

/*
vec4 filterColor(vec4 color)
{					
	color.r = color.r*R;
	color.g = color.g*G;
	color.b = color.b*B;
	return color;
}
*/

vec4 window_shader() 
{
	vec4 c;

	if (SHARPNESS > 0 )
	{
		c = getSharpenedColor(tex, texcoord);
	}
	else
	{
		c = getColor(tex, texcoord);
	}


	if (DIM > 0 )
	{
		c = dimWhites(c);
	}

	//c = brightenBlacks(c);

	if (SATURATION != 1 )
	{
		c = saturate(c);
	}

	/*c = filterColor(c); xcalib can do that as contrast*/

	/*return default_post_processing(c);*/
	return c;
}