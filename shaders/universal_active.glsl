#version 330

//#define FULLSCREEN //ifdef then it's picom shader for fullscreen apps

#define Saturation .55
#define Sharpness 0

#define UseEffects 1

#define Dim .25 //dims only light pixels (close to white)
#define DimSlope 2.0 //the less value the more colours affected def:1.0
#define DimThreshold 0.33 //luminance more than that will be dimmed def:0.33
#define DimCompensation 1 //1.0=contrast raises proportional to dim, 0=no effect

#define Lum 0 //brighten blacks, float 0-1 where 1 is full whitescreen (danger!)
#define LumSlope 0.25
#define LumThreshold 0.5 //only pixel with brightness less than that are affected
//#define LumCompensation 1 //lower black point after luming
#define LumSat 1
#define FixedSatRatio 0

#define ExpandBlacks 1 //gamma-corrects blacks dont touching whites
#define ExpandBlacksSlope 0.25 //more = how much whites affected def:0.25
#define ExpandBlacksGamma 0.25 //curve factor for expansion def:0.25
#define ExpandBlacksSat 1 //expands also saturation
#define ExpandBlacksSatSlope 0.25 //unused

#define BlackLightness 0.01


//Dynamic exposure (contrast) - someway good in fullscreen, anti-flash, eye protection etc. 

//darken bright scenes
#define ExposureSuppression 0.0 //factor (0+) def:0.5
//#define ExposureSuppressionLimit 1 //upper limit unused
#define ExposureSuppressionThreshold 0.1 //exposure higher than that will be decreased def:0.1
#define ExposureSuppressionSlope 0.5 //curve sloppiness, less - affects very bright only def:1

//brighten dark scenes
#define ExposureExpansion 0.5 // 0.5 //factor (0+)
#define ExposureExpansionThreshold 1 //exposure lower than that will be increased
#define ExposureExpansionSlope 0.5 //curve sloppiness
#define ExposureExpansionIgnoreLevel 0.2

#define LumaResX 8
#define LumaResY 4

uniform sampler2D tex; //window texture
in vec2 texcoord; //current pixel coord relative to window texture (0-1)
//uniform float time; //picom provided time in msec from some point
/*
vec2 pts[LumaResX*LumaResY] = CalculatePoints();

const vec2[LumaResX*LumaResY] CalculatePoints()
{
  vec2[LumaResX*LumaResY] points;// = vec2[10];

  return points;
}
*/

vec4 default_post_processing(vec4 c); //picom provided defaults (dimming, round corners, etc.)


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
    
	vec4 c = (1.0 + 4.0*Sharpness)*center -Sharpness*(up + left + right + down);
	return c;
}


vec4 saturate(vec4 color)
{
	//0.2989 0.5870 0.1140 NTSC
	//0.2126 0.7152 0.0722 luminance signal EY
	//0.2627 0.6780 0.0593 UHDTV
	const vec3 percp = vec3(0.2125, 0.7154, 0.0721);
	vec3 intensity = vec3(dot(color.rgb, percp));
	//vec3 intensity = vec3((color.r + color.g + color.b) / 3); //brightness based
    	color.rgb = mix(intensity, color.rgb, Saturation);
	return color;
}


//CONVERSION

vec3 rgb2hsv(vec3 c)
{
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c)
{
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}


vec3 rgb2hsl( in vec3 c )
{
	float h = 0.0;
	float s = 0.0;
	float l = 0.0;
	float r = c.r;
	float g = c.g;
	float b = c.b;
	float cMin = min( r, min( g, b ) );
	float cMax = max( r, max( g, b ) );

	l = ( cMax + cMin ) / 2.0;
	if ( cMax > cMin ) {
		float cDelta = cMax - cMin;
        
        //s = l < .05 ? cDelta / ( cMax + cMin ) : cDelta / ( 2.0 - ( cMax + cMin ) ); Original
		s = l < .0 ? cDelta / ( cMax + cMin ) : cDelta / ( 2.0 - ( cMax + cMin ) );
        
		if ( r == cMax ) {
			h = ( g - b ) / cDelta;
		} else if ( g == cMax ) {
			h = 2.0 + ( b - r ) / cDelta;
		} else {
			h = 4.0 + ( r - g ) / cDelta;
		}

		if ( h < 0.0) {
			h += 6.0;
		}
		h = h / 6.0;
	}
	return vec3( h, s, l );
}


vec3 hsl2rgb( in vec3 c )
{
    vec3 rgb = clamp( abs(mod(c.x*6.0+vec3(0.0,4.0,2.0),6.0)-3.0)-1.0, 0.0, 1.0 );

    return c.z + c.y * (rgb-0.5)*(1.0-abs(2.0*c.z-1.0));
}


float remap(float value, float min1, float max1, float min2, float max2) 
{
  return min2 + (value - min1) * (max2 - min2) / (max1 - min1);
}



//CURVES for 0-1 values

float rampTop(float value, float power) //bulge near top right, bump with pow >1
{
	return 1-pow(1-value, power); 
}


float rampBottom(float value, float power) //bulge near bottom left, bump with pow <1
{
	return pow(value, power); 
}


float slopeTop(float value, float power) //bulge near bottom right, bump with pow <1
{
	return pow(1-value, power);
}


float slopeBottom(float value, float power) //bulge near top left, bump with pow >1 
{
	return 1-pow(value, power);
}


//shift: >0 = scaled shift times, anchored by 1; <0 = also inverted, anchored by 0
float powRampShifted(float value, float power, float shift) 
{
  if (shift==0)
    return 1-pow(1-value, power);
  else if (shift>1)
    return 1-pow(1-shift*value+shift-1, power);
  else //shift<1
    return 1-pow(1-shift*value-(1-shift), power);
}


vec4 dimWhites(vec4 color)
{
	//float whitenessdot = dot(normalize(color.rgb), vec3(0.57735, 0.57735, 0.57735));
	//float whiteness = remap(whitenessdot, 0.5, 1, 0, 1);
	//float whiteness = (whitenessdot-0.5)*2;
	//float whiteness = (color.r + color.g + color.b)/3; //brightness based
	const vec3 percp = vec3(0.2125, 0.7154, 0.0721);
	float whiteness = dot(color.rgb, percp); //luminance based
	
	if (whiteness > DimThreshold)
	{
	  whiteness = (whiteness-DimThreshold)/(1-DimThreshold); //normalize
	  float slopedwhiteness = pow(whiteness,DimSlope) *Dim;
	  //float slopedwhiteness = 1-pow(1-whiteness,0.125);
	  //slopedwhiteness *= (1-DimThreshold); //set maximum dim level
	  color.rgb = color.rgb *(1-slopedwhiteness);
	  //color.rgb = color.rgb * (pow(1-whiteness*Dim, DimSlope));
	  //color.rgb = color.rgb * (1-whiteness*Dim); //darken whites

	  //color.rgb = color.rgb + (1-whiteness)*Lum; //brighten blacks
	}

	if (DimCompensation > 0)
	{
	  color.rgb *= 1+Dim*(1-DimThreshold)*DimCompensation/DimSlope; //overall compensation of lost brightness
	}

	return color;
}


vec4 brightenBlacks(vec4 color)
{
	const vec3 percp = vec3(0.2125, 0.7154, 0.0721);
	float whiteness = dot(color.rgb, percp);
	//float whiteness = (color.r+color.g+color.b)/3; //brightness based, better results here

	if (whiteness>0 && whiteness<LumThreshold)
	{
	  color.xyz = rgb2hsl(color.rgb);
	  whiteness = whiteness/LumThreshold; //normalize
	  float slopedblackness = 1 - pow(whiteness, LumSlope);
	  //color.z = color.z + slopedblackness*Lum; //brighten blacks
	  //color.rgb = color.rgb*(1+pow(whiteness,0.1));
	  //color.z = color.z*(1+(1-pow(whiteness,0.5)));
	  //float slopedsat = pow(color.y, 2);
	  float slopedsatamt = (1-pow(1-color.y,4)) *pow(1-color.y, 1) *1.87; //if 4th power
	  //float slopedsatamt = (1-pow(1-2*color.y,4)) *( -1/(color.y+0.618)+1.618) *1.225; //if 4th power
	  //float slopedsatamt = (1-pow(color.y,color.y)) *3.25; //slow?
	  //float slopedsatamt = pow( abs(color.y-(1-whiteness)) , 1);
	  slopedsatamt = FixedSatRatio+slopedsatamt*(1-FixedSatRatio);

	  color.z += slopedblackness*Lum*(1-slopedsatamt*LumSat); //lighten
	  //color.y += slopednonsat*LumSat; //saturate
	  color.y += slopedblackness *LumSat *slopedsatamt; //saturate
	  //if (color.y>1) color.y = 1;
	  color.rgb = hsl2rgb(color.xyz);
	}
	/*
	if (LumCompensation>0)
	{
	  float totalComp = Lum*(1-LumThreshold)*LumCompensation;
	  //color.rgb = (color.rgb-totalComp)*(1/(1-Lum));
	  color.rgb = (color.rgb-Lum*LumCompensation)/Lum;
	}
	*/
	return color;
}


vec4 expandBlacks(vec4 color)
{
	const vec3 percp = vec3(0.2125, 0.7154, 0.0721);
	float whiteness = dot(color.rgb, percp); //luminance based
	//float whiteness = (color.r+color.g+color.b)/3; //brightness based, better results here?
	
	//if (whiteness > 0)
	//{
	  //const vec3 white = vec3(1,1,1);
	  //whiteness = (whiteness-DimThreshold)/(1-DimThreshold); //
	  //float slopedwhiteness = pow(whiteness,1);
	  float slopedblackness = 1-pow(whiteness,ExpandBlacksSlope);
	  //float slopedblackness = 1-pow(whiteness,0.1);
	  //float slopedblackness = pow(1-whiteness,128);
	  //slopedwhiteness *= (1-DimThreshold); //set maximum dim level

	  color.xyz = rgb2hsl(color.rgb);
	  //color.z = pow(color.z, 0.5);
	  float slopedsatamt = (1-pow(1-color.y,4)) *pow(1-color.y, 1) *1.87;
	  color.z = mix(color.z, pow(color.z, ExpandBlacksGamma), slopedblackness*ExpandBlacks * (1-slopedsatamt*ExpandBlacksSat)); //curve eval
		//color.z *= 1-log(pow(whiteness, ExpandBlacksSlope))*ExpandBlacks*(1-slopedsatamt*ExpandBlacksSat); //logarithmic
		
	  color.z = clamp(color.z, 0.001, 0.66); //NVIDIA QUICK FIX!!!

	  
	  if (ExpandBlacksSat>0)
	    color.y = mix(color.y, pow(color.z, ExpandBlacksGamma), slopedblackness*ExpandBlacks*slopedsatamt*ExpandBlacksSat);//curve eval
		//color.y *= 1-log(pow(whiteness, ExpandBlacksSlope))*ExpandBlacks*(slopedsatamt*ExpandBlacksSat); //logarithmic
		
	  color.y = clamp(color.y, 0.001, 0.8); //NVIDIA QUICK FIX!!!
	     
	  //color.rgb = mix(color.rgb, white, slopedblackness*0.33);
	  color.rgb = hsl2rgb(color.xyz);

	  //color.rgb = 1-(1-color.rgb)*(1-(1-pow(whiteness-1, 2)));
	  //color.r = mix(color.r, -pow(color.r-1, 2)+1, 1-slopedwhiteness);
	  //color.g = mix(color.g, -pow(color.g-1, 2)+1, 1-slopedwhiteness);
	  //color.b = mix(color.b, -pow(color.b-1, 2)+1, 1-slopedwhiteness);

	  //color.r = -1/(color.r+0.618)+1.618;
	  //color.g = -1/(color.g+0.618)+1.618;
	  //color.b = -1/(color.b+0.618)+1.618;

	  //color.r = mix(color.r, pow(color.r, 0.5), slopedblackness);
	  //color.g = mix(color.g, pow(color.g, 0.5), slopedblackness);
	  //color.b = mix(color.b, pow(color.b, 0.5), slopedblackness);

	  //color.rgb = color.rgb * (pow(1-whiteness*Dim, DimSlope));
	  //color.rgb = color.rgb * (1-whiteness*Dim); //darken whites

	  //color.rgb = color.rgb + (1-whiteness)*Lum; //brighten blacks
	//}

	return color;
}

//REPLACE=fullscreen.part1.glsl

float getLuma5x5(sampler2D tex) //average luma of 25 uniformly distributed points 
{
	const vec3 percp = vec3(0.2125, 0.7154, 0.0721);

	const vec2 p11 = vec2(0.1,0.1);
	const vec2 p12 = vec2(0.3,0.1);
	const vec2 p13 = vec2(0.5,0.1);
	const vec2 p14 = vec2(0.7,0.1);
	const vec2 p15 = vec2(0.9,0.1);

	const vec2 p21 = vec2(0.1,0.3);
	const vec2 p22 = vec2(0.3,0.3);
	const vec2 p23 = vec2(0.5,0.3);
	const vec2 p24 = vec2(0.7,0.3);
	const vec2 p25 = vec2(0.9,0.3);

	const vec2 p31 = vec2(0.1,0.5);
	const vec2 p32 = vec2(0.3,0.5);
	const vec2 p33 = vec2(0.5,0.5);
	const vec2 p34 = vec2(0.7,0.5);
	const vec2 p35 = vec2(0.9,0.5);

	const vec2 p41 = vec2(0.1,0.7);
	const vec2 p42 = vec2(0.3,0.7);
	const vec2 p43 = vec2(0.5,0.7);
	const vec2 p44 = vec2(0.7,0.7);
	const vec2 p45 = vec2(0.9,0.7);

	const vec2 p51 = vec2(0.1,0.9);
	const vec2 p52 = vec2(0.3,0.9);
	const vec2 p53 = vec2(0.5,0.9);
	const vec2 p54 = vec2(0.7,0.9);
	const vec2 p55 = vec2(0.9,0.9);

	float l = 0; //luminance accumulator

	l += dot(texture2D(tex, p11).rgb, percp);
	l += dot(texture2D(tex, p12).rgb, percp);
	l += dot(texture2D(tex, p13).rgb, percp);
	l += dot(texture2D(tex, p14).rgb, percp);
	l += dot(texture2D(tex, p15).rgb, percp);

	l += dot(texture2D(tex, p21).rgb, percp);
	l += dot(texture2D(tex, p22).rgb, percp);
	l += dot(texture2D(tex, p23).rgb, percp);
	l += dot(texture2D(tex, p24).rgb, percp);
	l += dot(texture2D(tex, p25).rgb, percp);

	l += dot(texture2D(tex, p31).rgb, percp);
	l += dot(texture2D(tex, p32).rgb, percp);
	l += dot(texture2D(tex, p33).rgb, percp);
	l += dot(texture2D(tex, p34).rgb, percp);
	l += dot(texture2D(tex, p35).rgb, percp);

	l += dot(texture2D(tex, p41).rgb, percp);
	l += dot(texture2D(tex, p42).rgb, percp);
	l += dot(texture2D(tex, p43).rgb, percp);
	l += dot(texture2D(tex, p44).rgb, percp);
	l += dot(texture2D(tex, p45).rgb, percp);

	l += dot(texture2D(tex, p51).rgb, percp);
	l += dot(texture2D(tex, p52).rgb, percp);
	l += dot(texture2D(tex, p53).rgb, percp);
	l += dot(texture2D(tex, p54).rgb, percp);
	l += dot(texture2D(tex, p55).rgb, percp);

	return l / 25; //luminance normalization
}


float getLuma8x4(sampler2D tex) //average luma of 32 uniformly distributed points 
{
	const vec3 percp = vec3(0.2125, 0.7154, 0.0721);

	const vec2 p11 = vec2(0.0625, 0.125);
	const vec2 p12 = vec2(0.1875, 0.125);
	const vec2 p13 = vec2(0.3125, 0.125);
	const vec2 p14 = vec2(0.4375, 0.125);
	const vec2 p15 = vec2(0.5625, 0.125);
	const vec2 p16 = vec2(0.6875, 0.125);
	const vec2 p17 = vec2(0.8125, 0.125);
	const vec2 p18 = vec2(0.9375, 0.125);

	const vec2 p21 = vec2(0.0625, 0.375);
	const vec2 p22 = vec2(0.1875, 0.375);
	const vec2 p23 = vec2(0.3125, 0.375);
	const vec2 p24 = vec2(0.4375, 0.375);
	const vec2 p25 = vec2(0.5625, 0.375);
	const vec2 p26 = vec2(0.6875, 0.375);
	const vec2 p27 = vec2(0.8125, 0.375);
	const vec2 p28 = vec2(0.9375, 0.375);

	const vec2 p31 = vec2(0.0625, 0.625);
	const vec2 p32 = vec2(0.1875, 0.625);
	const vec2 p33 = vec2(0.3125, 0.625);
	const vec2 p34 = vec2(0.4375, 0.625);
	const vec2 p35 = vec2(0.5625, 0.625);
	const vec2 p36 = vec2(0.6875, 0.625);
	const vec2 p37 = vec2(0.8125, 0.625);
	const vec2 p38 = vec2(0.9375, 0.625);

	const vec2 p41 = vec2(0.0625, 0.875);
	const vec2 p42 = vec2(0.1875, 0.875);
	const vec2 p43 = vec2(0.3125, 0.875);
	const vec2 p44 = vec2(0.4375, 0.875);
	const vec2 p45 = vec2(0.5625, 0.875);
	const vec2 p46 = vec2(0.6875, 0.875);
	const vec2 p47 = vec2(0.8125, 0.875);
	const vec2 p48 = vec2(0.9375, 0.875);

	float l = 0; //luminance accumulator

	l += dot(texture2D(tex, p11).rgb, percp);
	l += dot(texture2D(tex, p12).rgb, percp);
	l += dot(texture2D(tex, p13).rgb, percp);
	l += dot(texture2D(tex, p14).rgb, percp);
	l += dot(texture2D(tex, p15).rgb, percp);
	l += dot(texture2D(tex, p16).rgb, percp);
	l += dot(texture2D(tex, p17).rgb, percp);
	l += dot(texture2D(tex, p18).rgb, percp);

	l += dot(texture2D(tex, p21).rgb, percp);
	l += dot(texture2D(tex, p22).rgb, percp);
	l += dot(texture2D(tex, p23).rgb, percp);
	l += dot(texture2D(tex, p24).rgb, percp);
	l += dot(texture2D(tex, p25).rgb, percp);
	l += dot(texture2D(tex, p26).rgb, percp);
	l += dot(texture2D(tex, p27).rgb, percp);
	l += dot(texture2D(tex, p28).rgb, percp);

	l += dot(texture2D(tex, p31).rgb, percp);
	l += dot(texture2D(tex, p32).rgb, percp);
	l += dot(texture2D(tex, p33).rgb, percp);
	l += dot(texture2D(tex, p34).rgb, percp);
	l += dot(texture2D(tex, p35).rgb, percp);
	l += dot(texture2D(tex, p36).rgb, percp);
	l += dot(texture2D(tex, p37).rgb, percp);
	l += dot(texture2D(tex, p38).rgb, percp);

	l += dot(texture2D(tex, p41).rgb, percp);
	l += dot(texture2D(tex, p42).rgb, percp);
	l += dot(texture2D(tex, p43).rgb, percp);
	l += dot(texture2D(tex, p44).rgb, percp);
	l += dot(texture2D(tex, p45).rgb, percp);
	l += dot(texture2D(tex, p46).rgb, percp);
	l += dot(texture2D(tex, p47).rgb, percp);
	l += dot(texture2D(tex, p48).rgb, percp);

	return l / 32; //luminance normalization
}

vec4 dimExposure(vec4 color, sampler2D tex, vec2 texcoord)
{
	float l = getLuma8x4(tex);

	//if (l > ExposureSuppressionLimit)

	if (l > ExposureSuppressionThreshold && ExposureSuppression > 0) //suppress
	{
		l = (l-ExposureSuppressionThreshold)/(1-ExposureSuppressionThreshold); //normalize
		//l = remap(l, ExposureSuppressionThreshold, ExposureSuppressionLimit, 0, 1);
		color.rgb *= 1-rampBottom(l,ExposureSuppressionSlope)*ExposureSuppression;
		
	}

	if (l < ExposureExpansionThreshold && ExposureExpansion > 0) //expand
	{
		l = l/ExposureExpansionThreshold; //normalize
		//color.rgb *= 1+ rampBottom(1-l,ExposureExpansionSlope)*ExposureExpansion;
		//color.rgb *= 1/l*ExposureExpansion;
		//color.rgb *= 1+ (1-log(l)*ExposureExpansionSlope-1)*ExposureExpansion;
		const float maxmul = pow(1-log(ExposureExpansionIgnoreLevel)*ExposureExpansion, ExposureExpansionSlope);
		if (l > ExposureExpansionIgnoreLevel) color.rgb *= 1-log(pow(l, ExposureExpansionSlope))*ExposureExpansion;
		else color.rgb *= maxmul;
		
		/*
		if (l > 0)
		{
		color.r = pow(color.r, l*2); //dynamic gamma?
		color.g = pow(color.g, l*2);
		color.b = pow(color.b, l*2);
		}
		*/
	}

	return color;
}


vec4 dimExposureTest(vec4 color, sampler2D tex, vec2 texcoord)
{
	vec2 texsize = textureSize(tex, 0);
	const vec2 samplePoint = vec2(0.5,0.5);
	//vec4 c = textureLod(tex, texcoord/texsize, log2(texsize.x));
	//glGenerateTextureMipmap(tex);
	//numLevels = 1 + floor(log2(max(w, h, d))) //find lowest mipmap level
	//or ceil(log_2(max(width,height)))+1 //wrong
	vec4 c = textureLod(tex, samplePoint, 1+floor(log2(max(texsize.x, texsize.y))) ); //DONT WORK?

	//float luminance = (c.r+c.g+c.b)/3; //overall texture luminance?
	const vec3 percp = vec3(0.2125, 0.7154, 0.0721);
	//float luminance = dot(color.rgb, percp); //effect like dim???
	float luminance =  dot(c.rgb, percp);
	if (luminance > ExposureSuppressionThreshold) //lower threshold
	{
		luminance = (luminance-ExposureSuppressionThreshold)/(1-ExposureSuppressionThreshold); //lower threshold
		color.rgb *= (1-pow(luminance,ExposureSuppressionSlope) *ExposureSuppression); //max dim
	}

	return color;
}

vec4 UniformColor(vec4 color)
{
	const vec3 percp = vec3(0.2125, 0.7154, 0.0721);
	//const vec3 corr = normalize(vec3(4.706,1.3978,13.8696));
	const vec3 corr = normalize(vec3(0.7875,0.2846,0.9279));

	float luma = dot(color.rgb, percp);
	float darkness = dot(color.rgb, corr);
	vec3 hsl = rgb2hsl(color.rgb);
	float sat = hsl.y;
	//color.r = color.r *(4.706/20) *sat;
	//color.g = color.g *(1.3978/20) *sat;
	//color.b = color.b *(13.8696/20) *sat;
	//hsl.z = hsl.z*(1-sat) + (1-luma)*sat;
	hsl.z = darkness;
	//hsl.y = hsl.y*

	color.rgb = hsl2rgb(hsl);	
	return color;
}

vec4 fakeHDR(vec4 color)
{
    vec3 hsv = rgb2hsv(color.rgb);

    float intensity = hsv.z; // the third component holds the brightness

    float log_factor = log(intensity + 1.0);

    log_factor = exp(log_factor) - 1.0;

    hsv.z = log_factor;

    color.rgb = hsv2rgb(hsv);

    return color;
}

//vec4 luminance(sampler2D tex, vec2 texcoord)
//{
//	return textureLod(tex, texcoord, log2(1));
//}

//float l;

vec4 window_shader() 
{
	vec4 c;

	if (UseEffects<=0) //disabled
	{
		c = getColor(tex, texcoord);

		if (Saturation != 1 ) c = saturate(c);

		return c;
	}

	if (Sharpness > 0 ) c = getSharpenedColor(tex, texcoord);
	else c = getColor(tex, texcoord);
	
	//if (mod(time,100)==0) l = texture2D(tex, vec2(0.5,0.5)).r;
	//c = adjustExposure(c, sin(time/1000));

	if (Dim > 0 ) c = dimWhites(c);
	
	if (Lum > 0) c = brightenBlacks(c);
	
	if (ExpandBlacks > 0) c = expandBlacks(c);

	//c = fakeHDR(c);
	//c = UniformColor(c);

	if (Saturation != 1 ) c = saturate(c);

	//REPLACE=fullscreen.part2.glsl
	if (ExposureSuppression > 0 || ExposureExpansion > 0) c = dimExposure(c, tex, texcoord);

	//return default_post_processing(c); //picom default - if needed
	return c;
}
