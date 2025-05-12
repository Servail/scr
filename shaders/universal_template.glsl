#version 330

//precision highp float;
//precision highp int;

#if __VERSION__ < 130
#define Tex2D texture2D
#else
#define Tex2D texture
#endif

//#define FULLSCREEN //ifdef then it's picom shader for fullscreen apps

#define Saturation SATURATION_VALUE
#define Sharpness SHARPNESS_VALUE
#define Roughness ROUGHNESS_VALUE

#define GammaCorrection 1 //use if system gamma doesn't work or in some special cases

#define UseEffects USEEFFECTS_VALUE

#define Dim DIM_VALUE //dims only light pixels (close to white)
#define DimSlope DIMSLOPE_VALUE //the less value the more colours affected def:1.0
#define DimThreshold 0.33 //luminance more than that will be dimmed def:0.33
#define DimCompensation 1 //1.0=contrast raises proportional to dim, 0=no effect

//DEPRECATED by ExpandBlacks?
#define Lum LUM_VALUE //brighten blacks, float 0-1 where 1 is full whitescreen (danger!)
#define LumSlope 0.25
#define LumThreshold 0.5 //only pixel with brightness less than that are affected
//#define LumCompensation 1 //lower black point after luming
#define LumSat 1
#define FixedSatRatio 0

#define FakeHdr FAKEHDR_VALUE //remaps colors to make lights and darks more saturated and correct overall saturation falloff

//Makes colors and shades perceptually even (~fake hdr)
//Notice you need to lower overall display gamma to ~0.65
#define ExpandBlacks EXPAND_BLACKS_VALUE //boosts blacks not touching whites
#define ExpandBlacksSlope EXPAND_BLACKS_SLOPE_VALUE //more = how much whites affected def:0.25
#define ExpandBlacksGamma EXPAND_BLACKS_GAMMA_VALUE //curve factor for blacks expansion def:0.25
#define ExpandBlacksSat EXPAND_BLACKS_SAT_VALUE //expands also saturation
#define ExpandBlacksSatSlope EXPAND_BLACKS_SAT_SLOPE_VALUE //unused

#define BlackLightness BLACK_LIGHTNESS_VALUE //classic additive brightness but applied only to darks

//Dynamic exposure (contrast) - someway good in fullscreen, anti-flash, eye protection etc.

//darken bright scenes DEPRECATED
#define ExposureSuppression 0.0 //factor (0+) def:0.5
//#define ExposureSuppressionLimit 1 //upper limit unused
#define ExposureSuppressionThreshold 0.1 //exposure higher than that will be decreased def:0.1
#define ExposureSuppressionSlope 0.5 //curve sloppiness, less - affects very bright only def:1

//lighten dark scenes
#define ExposureExpansion EXPOSURE_EXPANSION_VALUE // 0.5 //factor (0+)
#define ExposureExpansionThreshold EXPOSURE_EXPANSION_THRESHOLD_VALUE //exposure lower than that will be increased
#define ExposureExpansionSlope EXPOSURE_EXPANSION_SLOPE_VALUE //curve sloppiness
#define ExposureExpansionIgnoreLevel  EXPOSURE_EXPANSION_IGNORE_LEVEL_VALUE //stop boosting if too dark

#define LumaResX 8
#define LumaResY 4

#define Debug 0
float debugValue;

uniform sampler2D tex; //picom: window texture
in vec2 texcoord; //picom: current absolute pixel coord (by texsize)
//uniform float time; //picom: time in msec from some point
vec4 default_post_processing(vec4 c); //picom: default compositor effects (dimming, round corners, transparency, etc.)

/*
vec2 pts[LumaResX*LumaResY] = CalculatePoints();

const vec2[LumaResX*LumaResY] CalculatePoints()
{
  vec2[LumaResX*LumaResY] points;// = vec2[10];

  return points;
}
*/


vec4 GetColor(sampler2D tex, vec2 texcoord)
{
	vec2 texsize = textureSize(tex, 0);
    vec4 c = texture2D(tex, texcoord/texsize, 0);
	return c;
}


vec4 GetSharpenedColor(sampler2D tex, vec2 uv, vec2 texelSize, float sharpness)
{
	vec4 up = texture2D(tex, uv+vec2(0,1)*texelSize, 0);
    vec4 left = texture2D(tex, uv+vec2(-1,0)*texelSize, 0);
    vec4 center = texture2D(tex, uv, 0);
    vec4 right = texture2D(tex, uv+vec2(1,0)*texelSize, 0);
    vec4 down = texture2D(tex, uv+vec2(0,-1)*texelSize, 0);

	vec4 c = (1.0 + 4.0*sharpness)*center - sharpness*(up + left + right + down);
	return c;
}


vec4 SharpenEdges(sampler2D tex, vec2 uv, vec2 texelSize, float amount, int kernelRadius)
{

    // Sample original color
    vec4 color = texture2D(tex, uv, 0);
    vec3 original = color.rgb;
    float a = color.a;

    // Calculate blurred color using box blur
    vec3 blurred = vec3(0.0);
    float samples = 0.0;

    for (int x = -kernelRadius; x <= kernelRadius; x++)
    {
        for (int y = -kernelRadius; y <= kernelRadius; y++)
        {
            vec2 offset = vec2(x, y) * texelSize;
            blurred += texture(tex, uv + offset).rgb;
            samples += 1.0;
        }
    }

    blurred /= samples;

    // Apply unsharp masking and return
    color.rgb = original + (original - blurred) * amount;
    color.a = a;

    return color;
}


float GaussianBlur(vec2 offset, float sigma)
{
	return exp(-(offset.x*offset.x + offset.y*offset.y) / (2.0*sigma*sigma));
}

// ---- Gaussian Blur Functions ----
vec3 GaussianBlur1D(sampler2D t, vec2 uv, vec2 texelSize, vec2 dir, int radius)
{
    // Maximum supported radii (can be increased if needed)
    const int MAX_LARGE_RADIUS = 5;
    //const int MAX_SMALL_RADIUS = 3;

    float sigma = float(radius) * 0.5;
    vec3 acc = vec3(0.0);
    float total = 0.0;


    for(int i = -MAX_LARGE_RADIUS; i <= MAX_LARGE_RADIUS; i++)
    {
        //if (abs(i) > radius) continue;

        float weight = exp(-(i*i)/(2.0*sigma*sigma));
        vec2 offset = dir * float(i) * texelSize;
        acc += texture2D(t, uv + offset, 0).rgb * weight;
        total += weight;
    }


    return acc / total;
}


vec3 GaussianBlur2D(sampler2D t, vec2 uv, vec2 texelSize, int radius)
{
    // Maximum supported radii (can be increased if needed)
    const int MAX_RADIUS = 5;
    //const int MAX_SMALL_RADIUS = 3;


    float sigma = float(radius) * 0.5;
    vec3 acc = vec3(0.0);
    float total = 0.0;


    for(int x = -MAX_RADIUS; x <= MAX_RADIUS; x++)
    {
	    for(int y = -MAX_RADIUS; y <= MAX_RADIUS; y++)
	    {
	        if (abs(x) > radius || abs(y) > radius) continue;

	        float weight = GaussianBlur(vec2(x, y), sigma);
	        vec2 offset = vec2(x, y) * texelSize;
	        acc += texture2D(t, uv + offset, 0).rgb * weight;
	        total += weight;
		}
    }


    return acc / total;
}


//Note that uv is in [0,1] so it's texcoord/texsize
vec4 DualSharpening(sampler2D tex, vec2 uv, vec2 texelSize, int largeRadius, float largeAmount, int smallRadius, float smallAmount)
{
	vec4 color = texture2D(tex, uv, 0);

    vec3 original = color.rgb;

    // ---- Large Kernel Processing ----
    //vec3 largeBlur = GaussianBlur1D(tex, uv, texelSize, vec2(1,0), largeRadius);
    //largeBlur = GaussianBlur1D(tex, uv, texelSize, vec2(0,1), largeRadius);
    vec3 largeBlur = GaussianBlur2D(tex, uv, texelSize, largeRadius);
	vec3 smallBlur = GaussianBlur2D(tex, uv, texelSize, smallRadius);

    // ---- Small Kernel Processing ----
    //vec3 smallBlur = GaussianBlur1D(tex, uv, texelSize, vec2(1,0), smallRadius);
    //smallBlur = GaussianBlur1D(tex, uv, texelSize, vec2(0,1), smallRadius);
    vec3 largeHP = original - largeBlur;
    vec3 smallHP = original - smallBlur;

    // ---- Energy-Preserved Combination ----
    vec3 combined = original + largeHP*largeAmount + smallHP*smallAmount;

    // Luma preservation (prevents brightness shift)
    float centerLum = dot(original, vec3(0.2126, 0.7152, 0.0722));
    float resultLum = dot(combined, vec3(0.2126, 0.7152, 0.0722));
    //combined *= centerLum / (resultLum + 1e-6);

    // Chroma preservation (prevent oversaturation)
    vec3 chroma = original / (original + 1e-6);
    color.rgb = combined;// * chroma;

    return color;
}


vec3 DualSharpeningSinglePass
(
    sampler2D tex,
    vec2 uv,
    vec2 texelSize,
    int largeRadius,
    float largeAmount,
    int smallRadius,
    float smallAmount
)
{
    const int MAX_RADIUS = 5;
    vec3 original = texture(tex, uv).rgb;
    float origLuma = dot(original, vec3(0.2126, 0.7152, 0.0722));

    // Initialize accumulators
    vec3 largeBlur = vec3(0.0);
    vec3 smallBlur = vec3(0.0);
    float largeWeightSum = 0.0;
    float smallWeightSum = 0.0;

    // Combined sampling loop
    for(int x = -largeRadius; x <= largeRadius; x++)
    {
        for(int y = -largeRadius; y <= largeRadius; y++)
        {
            float dist = length(vec2(x, y));
            vec2 offset = vec2(x, y) * texelSize;
            vec3 sample = texture(tex, uv + offset).rgb;

            // Large kernel processing
            //if (true) //dist <= largeRadius)
            //{
                float w = 1;//exp(-dist*dist/(2.0*float(largeRadius*largeRadius)));
                largeBlur += sample * w;
                largeWeightSum += w;
            //}

            // Small kernel processing
            if (abs(x) > smallRadius || abs(y)> smallRadius) continue;
            //if (x< -smallRadius && x>smallRadius && y< -smallRadius && y > smallRadius) //dist <= smallRadius)
            //{
                w = 1;//exp(-dist*dist/(2.0*float(smallRadius*smallRadius)));
                smallBlur += sample * w;
                smallWeightSum += w;
            //}
        }
    }

    // Normalize blurs
    largeBlur /= largeWeightSum;
    smallBlur /= smallWeightSum;

    // Frequency-separated sharpening
    vec3 largeHP = original - largeBlur;
    vec3 smallHP = original - smallBlur;
    vec3 result = original + largeHP*largeAmount + smallHP*smallAmount;

    // Perceptual energy conservation
    float resultLuma = dot(result, vec3(0.2126, 0.7152, 0.0722));
    //result = result * (origLuma / (resultLuma + 1e-6));

	return result;
}


vec3 DualSharpeningOptimized
(
    sampler2D tex,
    vec2 uv,
    vec2 texelSize,
    int largeRadius,
    float largeAmount,
    int smallRadius,
    float smallAmount
)
{
    //const int MAX_RADIUS = 5;
    vec3 original = texture(tex, uv).rgb;
    float origLuma = dot(original, vec3(0.2126, 0.7152, 0.0722));

	////const vec2 p11 = vec2(-3, -3);
	const vec2 p12 = vec2(-2, -3);
	const vec2 p13 = vec2(-1, -3);
	const vec2 p14 = vec2(+0, -3);
	const vec2 p15 = vec2(+1, -3);
	const vec2 p16 = vec2(+2, -3);
	////const vec2 p17 = vec2(+3, -3);

	const vec2 p21 = vec2(-3, -2);
	const vec2 p22 = vec2(-2, -2);
	const vec2 p23 = vec2(-1, -2);
	const vec2 p24 = vec2(+0, -2);
	const vec2 p25 = vec2(+1, -2);
	const vec2 p26 = vec2(+2, -2);
	const vec2 p27 = vec2(+3, -2);

	const vec2 p31 = vec2(-3, -1);
	const vec2 p32 = vec2(-2, -1);
	const vec2 p33 = vec2(-1, -1);
	const vec2 p34 = vec2(+0, -1);
	const vec2 p35 = vec2(+1, -1);
	const vec2 p36 = vec2(+2, -1);
	const vec2 p37 = vec2(+3, -1);

	const vec2 p41 = vec2(-3, +0);
	const vec2 p42 = vec2(-2, +0);
	const vec2 p43 = vec2(-1, +0);
	//const vec2 p44 = vec2(+0, +0);
	const vec2 p45 = vec2(+1, +0);
	const vec2 p46 = vec2(+2, +0);
	const vec2 p47 = vec2(+3, +0);

	/* //can just subtract above vectors
	const vec2 p51 = vec2(-3, +1);
	const vec2 p52 = vec2(-2, +1);
	const vec2 p53 = vec2(-1, +1);
	const vec2 p54 = vec2(+0, +1);
	const vec2 p55 = vec2(+1, +1);
	const vec2 p56 = vec2(+2, +1);
	const vec2 p57 = vec2(+3, +1);

	//const vec2 p61 = vec2(-3, +2);
	const vec2 p62 = vec2(-2, +2);
	const vec2 p63 = vec2(-1, +2);
	const vec2 p64 = vec2(+0, +2);
	const vec2 p65 = vec2(+1, +2);
	const vec2 p66 = vec2(+2, +2);
	//const vec2 p67 = vec2(+3, +2);

	////const vec2 p71 = vec2(-3, +3);
	//const vec2 p72 = vec2(-2, +3);
	const vec2 p73 = vec2(-1, +3);
	const vec2 p74 = vec2(+0, +3);
	const vec2 p75 = vec2(+1, +3);
	//const vec2 p76 = vec2(+2, +3);
	////const vec2 p77 = vec2(+3, +3);
	*/

	vec3 largeBlur = vec3(0.0);
	vec3 smallBlur = vec3(0.0);

    ////largeBlur += texture(tex, uv + p11 * texelSize).rgb;
    largeBlur += texture(tex, uv + p12 * texelSize).rgb;
    largeBlur += texture(tex, uv + p13 * texelSize).rgb;
    largeBlur += texture(tex, uv + p14 * texelSize).rgb;
    largeBlur += texture(tex, uv + p15 * texelSize).rgb;
    largeBlur += texture(tex, uv + p16 * texelSize).rgb;
    ////largeBlur += texture(tex, uv + p17 * texelSize).rgb;

    largeBlur += texture(tex, uv + p21 * texelSize).rgb;
    largeBlur += texture(tex, uv + p22 * texelSize).rgb;
    largeBlur += texture(tex, uv + p23 * texelSize).rgb;
    largeBlur += texture(tex, uv + p24 * texelSize).rgb;
    largeBlur += texture(tex, uv + p25 * texelSize).rgb;
    largeBlur += texture(tex, uv + p26 * texelSize).rgb;
    largeBlur += texture(tex, uv + p27 * texelSize).rgb;

    largeBlur += texture(tex, uv + p31 * texelSize).rgb;
    largeBlur += texture(tex, uv + p32 * texelSize).rgb;
    vec3 s33 = texture(tex, uv + p33 * texelSize).rgb; largeBlur += s33;//smallBlur += s33;
    vec3 s34 = texture(tex, uv + p34 * texelSize).rgb; largeBlur += s34;smallBlur += s34;
    vec3 s35 = texture(tex, uv + p35 * texelSize).rgb; largeBlur += s35;//smallBlur += s35;
    largeBlur += texture(tex, uv + p36 * texelSize).rgb;
    largeBlur += texture(tex, uv + p37 * texelSize).rgb;

    largeBlur += texture(tex, uv + p41 * texelSize).rgb;
    largeBlur += texture(tex, uv + p42 * texelSize).rgb;
    vec3 s43 = texture(tex, uv + p43 * texelSize).rgb; largeBlur += s43;smallBlur += s43;
	largeBlur += original; smallBlur += original; //largeBlur += texture(tex, uv + p44 * texelSize).rgb;
    vec3 s45 = texture(tex, uv + p45 * texelSize).rgb; largeBlur += s45;smallBlur += s45;
    largeBlur += texture(tex, uv + p46 * texelSize).rgb;
    largeBlur += texture(tex, uv + p47 * texelSize).rgb;

	//largeBlur +
    largeBlur += texture(tex, uv - p31 * texelSize).rgb;
    largeBlur += texture(tex, uv - p32 * texelSize).rgb;
    vec3 s53 = texture(tex, uv - p33 * texelSize).rgb; largeBlur += s53;//smallBlur += s53;
    vec3 s54 = texture(tex, uv - p34 * texelSize).rgb; largeBlur += s54;smallBlur += s54;
    vec3 s55 = texture(tex, uv - p35 * texelSize).rgb; largeBlur += s55;//smallBlur += s55;
    largeBlur += texture(tex, uv - p36 * texelSize).rgb;
    largeBlur += texture(tex, uv - p37 * texelSize).rgb;

    largeBlur += texture(tex, uv - p21 * texelSize).rgb;
    largeBlur += texture(tex, uv - p22 * texelSize).rgb;
    largeBlur += texture(tex, uv - p23 * texelSize).rgb;
    largeBlur += texture(tex, uv - p24 * texelSize).rgb;
    largeBlur += texture(tex, uv - p25 * texelSize).rgb;
    largeBlur += texture(tex, uv - p26 * texelSize).rgb;
    largeBlur += texture(tex, uv - p27 * texelSize).rgb;

    ////largeBlur += texture(tex, uv - p11 * texelSize).rgb;
	largeBlur += texture(tex, uv - p12 * texelSize).rgb;
	largeBlur += texture(tex, uv - p13 * texelSize).rgb;
	largeBlur += texture(tex, uv - p14 * texelSize).rgb;
	largeBlur += texture(tex, uv - p15 * texelSize).rgb;
	largeBlur += texture(tex, uv - p16 * texelSize).rgb;
	////largeBlur += texture(tex, uv - p17 * texelSize).rgb;

    // Normalize blurs
    largeBlur /= 45;//37;//45;//49;
    smallBlur /= 5;//5;//9;

    // Frequency-separated sharpening
    vec3 largeHP = original - largeBlur;
    vec3 smallHP = original - smallBlur;
    vec3 result = original + largeHP*largeAmount + smallHP*smallAmount;

    // Perceptual energy conservation
    //float resultLuma = dot(result, vec3(0.2126, 0.7152, 0.0722));
    //result = result * (origLuma / (resultLuma + 1e-6));

	return result;
}


// 2xSai-style pixel art upscaling
vec4 Get2xSai(sampler2D tex, vec2 uv, vec2 texelSize) {
    // Sample 4x4 grid (original resolution)
    vec3 c00 = texture(tex, uv + texelSize * vec2(-1,-1)).rgb;
    vec3 c10 = texture(tex, uv + texelSize * vec2( 0,-1)).rgb;
    vec3 c20 = texture(tex, uv + texelSize * vec2( 1,-1)).rgb;
    vec3 c01 = texture(tex, uv + texelSize * vec2(-1, 0)).rgb;
    vec3 c11 = texture(tex, uv).rgb; // Center
    vec3 c21 = texture(tex, uv + texelSize * vec2( 1, 0)).rgb;
    vec3 c02 = texture(tex, uv + texelSize * vec2(-1, 1)).rgb;
    vec3 c12 = texture(tex, uv + texelSize * vec2( 0, 1)).rgb;
    vec3 c22 = texture(tex, uv + texelSize * vec2( 1, 1)).rgb;

    // Determine sub-pixel position [0-1]
    vec2 subCoord = fract(uv * textureSize(tex, 0));

    // Edge pattern detection
    bool patternA = (c01 == c10) && (c10 != c21) && (c01 != c12);
    bool patternB = (c10 == c21) && (c21 != c01) && (c10 != c12);
    bool patternC = (c01 == c12) && (c12 != c10) && (c01 != c21);

    // Diagonal edge detection
    bool diagEdge = (c11 == c00) && (c11 == c22) && (c11 != c02) && (c11 != c20);
    bool antiDiagEdge = (c11 == c20) && (c11 == c02) && (c11 != c00) && (c11 != c22);

    // Color blending rules
    vec3 result;
    if(subCoord.x < 0.5 && subCoord.y < 0.5) { // Top-left quadrant
        if(diagEdge) result = mix(c11, c00, 0.75);
        else if(patternA) result = c01;
        else if(patternB) result = c10;
        else result = mix(mix(c01, c10, 0.5), c11, 0.5);
    }
    else if(subCoord.x >= 0.5 && subCoord.y < 0.5) { // Top-right
        if(antiDiagEdge) result = mix(c11, c20, 0.75);
        else if(patternB) result = c21;
        else if(patternC) result = c10;
        else result = mix(mix(c21, c10, 0.5), c11, 0.5);
    }
    else if(subCoord.x < 0.5) { // Bottom-left
        if(antiDiagEdge) result = mix(c11, c02, 0.75);
        else if(patternA) result = c01;
        else if(patternC) result = c12;
        else result = mix(mix(c01, c12, 0.5), c11, 0.5);
    }
    else { // Bottom-right
        if(diagEdge) result = mix(c11, c22, 0.75);
        else if(patternC) result = c21;
        else if(patternB) result = c12;
        else result = mix(mix(c21, c12, 0.5), c11, 0.5);
    }

    return vec4(result, 1.0);
}


vec3 Saturate(vec3 rgb, float saturation)
{
	//0.2989 0.5870 0.1140 NTSC
	//0.2126 0.7152 0.0722 luminance signal EY
	//0.2627 0.6780 0.0593 UHDTV
	const vec3 percp = vec3(0.2125, 0.7154, 0.0721);
	vec3 intensity = vec3(dot(rgb, percp));
	//vec3 intensity = vec3((color.r + color.g + color.b) / 3); //brightness based
    rgb = mix(intensity, rgb, saturation);
	return rgb;
}


//DEBUG PRINT
float DigitBin( const int x )
{
    return x==0?480599.0:x==1?139810.0:x==2?476951.0:x==3?476999.0:x==4?350020.0:x==5?464711.0:x==6?464727.0:x==7?476228.0:x==8?481111.0:x==9?481095.0:0.0;
}

float PrintValue( vec2 vStringCoords, float fValue, float fMaxDigits, float fDecimalPlaces )
{
    if ((vStringCoords.y < 0.0) || (vStringCoords.y >= 1.0)) return 0.0;

    bool bNeg = ( fValue < 0.0 );
	fValue = abs(fValue);

	float fLog10Value = log2(abs(fValue)) / log2(10.0);
	float fBiggestIndex = max(floor(fLog10Value), 0.0);
	float fDigitIndex = fMaxDigits - floor(vStringCoords.x);
	float fCharBin = 0.0;
	if(fDigitIndex > (-fDecimalPlaces - 1.01)) {
		if(fDigitIndex > fBiggestIndex) {
			if((bNeg) && (fDigitIndex < (fBiggestIndex+1.5))) fCharBin = 1792.0;
		} else {
			if(fDigitIndex == -1.0) {
				if(fDecimalPlaces > 0.0) fCharBin = 2.0;
			} else {
                float fReducedRangeValue = fValue;
                if(fDigitIndex < 0.0) { fReducedRangeValue = fract( fValue ); fDigitIndex += 1.0; }
				float fDigitValue = (abs(fReducedRangeValue / (pow(10.0, fDigitIndex))));
                fCharBin = DigitBin(int(floor(mod(fDigitValue, 10.0))));
			}
        }
	}
    return floor(mod((fCharBin / pow(2.0, floor(fract(vStringCoords.x) * 4.0) + (floor(vStringCoords.y * 5.0) * 4.0))), 2.0));
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


#ifndef HCV_EPSILON
#define HCV_EPSILON 1e-10
#endif

vec3 rgb2hcv(const in vec3 rgb) {
    vec4 P = (rgb.g < rgb.b) ? vec4(rgb.bg, -1.0, 2.0/3.0) : vec4(rgb.gb, 0.0, -1.0/3.0);
    vec4 Q = (rgb.r < P.x) ? vec4(P.xyw, rgb.r) : vec4(rgb.r, P.yzx);
    float C = Q.x - min(Q.w, Q.y);
    float H = abs((Q.w - Q.y) / (6.0 * C + HCV_EPSILON) + Q.z);
    return vec3(H, C, Q.x);
}


#ifndef HSL_EPSILON
#define HSL_EPSILON 1e-10
#endif

vec3 rgb2hsl2(in vec3 rgb)
{//BROKEN?? FIX:
	//ignore white, crop above
	//if (rgb.r+rgb.g+rgb.b>=3.0f) return vec3(1);
	//ignore black, crop below
	//if (rgb.r+rgb.g+rgb.b<=0.0f) return vec3(0);

    vec3 HCV = rgb2hcv(rgb);
    float L = HCV.z - HCV.y * 0.5;
    float S = HCV.y / (1.0 - abs(L * 2.0 - 1.0) + HSL_EPSILON);

    return vec3(HCV.x, S, L);
}


vec3 rgb2hsl1( in vec3 c ) //BROKEN! LOSES SATURATION ON LOWS
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


vec3 hue2rgb(const in float hue) {
    float R = abs(hue * 6.0 - 3.0) - 1.0;
    float G = 2.0 - abs(hue * 6.0 - 2.0);
    float B = 2.0 - abs(hue * 6.0 - 4.0);
    return clamp(vec3(R,G,B),0.0,1.0);
}


vec3 hsl2rgb2(const in vec3 hsl)
{ //BROKEN?? FIXED in rgb2hsl
    vec3 rgb = hue2rgb(hsl.x);
    float C = (1.0 - abs(2.0 * hsl.z - 1.0)) * hsl.y;
    return (rgb - 0.5) * C + hsl.z;
}


vec3 hsl2rgb1( in vec3 c ) //BROKEN! LOSES SATURATION ON LOWS
{
    vec3 rgb = clamp( abs(mod(c.x*6.0+vec3(0.0,4.0,2.0),6.0)-3.0)-1.0, 0.0, 1.0 );

    return c.z + c.y * (rgb-0.5)*(1.0-abs(2.0*c.z-1.0));
}


// RGB to HSL conversion DeepSeek
vec3 rgb2hsl3(vec3 rgb) {
    float r = rgb.r;
    float g = rgb.g;
    float b = rgb.b;

    float maxRGB = max(r, max(g, b));
    float minRGB = min(r, min(g, b));
    float delta = maxRGB - minRGB;

    float L = (maxRGB + minRGB) * 0.5;
    float H = 0.0;
    float S = 0.0;

    if (delta > 1e-6) {
        S = delta / (1.0 - abs(2.0 * L - 1.0));

        if (r >= g && r >= b) {
            H = (g - b) / delta;
        } else if (g >= b) {
            H = 2.0 + (b - r) / delta;
        } else {
            H = 4.0 + (r - g) / delta;
        }

        H = mod(H, 6.0); // Wrap negative values
        H /= 6.0; // Normalize to [0,1)
    }

    return vec3(H, S, L);
}

// HSL to RGB conversion DeepSeek
vec3 hsl2rgb3(vec3 hsl) {
    float H = hsl.x;
    float S = hsl.y;
    float L = hsl.z;

    if (S < 1e-6) {
        return vec3(L);
    }

    float C = (1.0 - abs(2.0 * L - 1.0)) * S;
    float m = L - C * 0.5;
    float huePrime = H * 6.0;
    float X = C * (1.0 - abs(mod(huePrime, 2.0) - 1.0));

    vec3 rgb;

    if (huePrime < 1.0) {
        rgb = vec3(C, X, 0.0);
    } else if (huePrime < 2.0) {
        rgb = vec3(X, C, 0.0);
    } else if (huePrime < 3.0) {
        rgb = vec3(0.0, C, X);
    } else if (huePrime < 4.0) {
        rgb = vec3(0.0, X, C);
    } else if (huePrime < 5.0) {
        rgb = vec3(X, 0.0, C);
    } else {
        rgb = vec3(C, 0.0, X);
    }

    rgb += m;
    return clamp(rgb, 0.0, 1.0); // Ensure valid color range
}

//wrappers to switch between rgb2hsl/hsl2rgb implementations
vec3 rgb2hsl( in vec3 c )
{
	return rgb2hsl3(c);
}


vec3 hsl2rgb( in vec3 c )
{
	return hsl2rgb3(c);
}


const float TAU = 6.28318530717;
// lch = (lightness, chromaticity, hue)
vec3 oklch2oklab(const in vec3 lch)
{
  return vec3(lch.x, lch.y * cos(lch.z * TAU), lch.y * sin(lch.z * TAU));
}

vec3 oklab2rgb(const in vec3 oklab)
{
	const mat3 OKLAB2RGB_A = mat3(
    1.0,           1.0,           1.0,
    0.3963377774, -0.1055613458, -0.0894841775,
    0.2158037573, -0.0638541728, -1.2914855480);

	const mat3 OKLAB2RGB_B = mat3(
    4.0767416621, -1.2684380046, -0.0041960863,
    -3.3077115913, 2.6097574011, -0.7034186147,
    0.2309699292, -0.3413193965, 1.7076147010);

    vec3 lms = OKLAB2RGB_A * oklab;
    return OKLAB2RGB_B * (lms * lms * lms);
}

const mat3 RGB2XYZ = mat3(
    0.4124564, 0.2126729, 0.0193339,
    0.3575761, 0.7151522, 0.1191920,
    0.1804375, 0.0721750, 0.9503041);

vec3 rgb2xyz(const in vec3 rgb) { return RGB2XYZ * rgb;}

vec3 xyz2lab(const in vec3 c) {
    vec3 n = c / vec3(95.047, 100.0, 108.883);
    vec3 c0 = pow(n, vec3(1.0 / 3.0));
    vec3 c1 = (7.787 * n) + (16.0 / 116.0);
    vec3 v = mix(c0, c1, step(n, vec3(0.008856)));
    return vec3((116.0 * v.y) - 16.0,
                500.0 * (v.x - v.y),
                200.0 * (v.y - v.z));
}

vec3 rgb2lab(const in vec3 c) { return xyz2lab( rgb2xyz( c ) ); }

vec3 lab2lch(const in vec3 lab) {
    return vec3(
        lab.x,
        sqrt(dot(lab.yz, lab.yz)),
        atan(lab.z, lab.y) * 57.2957795131
    );
}


vec3 rgb2lch(const in vec3 rgb) { return lab2lch(rgb2lab(rgb)); }



//OKLAB

#define M_PI 3.1415926535897932384626433832795

float cbrt( float x )
{
    return sign(x)*pow(abs(x),1.0f/3.0f);
}

float srgb_transfer_function(float a)
{
	return .0031308f >= a ? 12.92f * a : 1.055f * pow(a, .4166666666666667f) - .055f;
}

float srgb_transfer_function_inv(float a)
{
	return .04045f < a ? pow((a + .055f) / 1.055f, 2.4f) : a / 12.92f;
}

vec3 linear_srgb_to_oklab(vec3 c)
{
	float l = 0.4122214708f * c.r + 0.5363325363f * c.g + 0.0514459929f * c.b;
	float m = 0.2119034982f * c.r + 0.6806995451f * c.g + 0.1073969566f * c.b;
	float s = 0.0883024619f * c.r + 0.2817188376f * c.g + 0.6299787005f * c.b;

	float l_ = cbrt(l);
	float m_ = cbrt(m);
	float s_ = cbrt(s);

	return vec3(
		0.2104542553f * l_ + 0.7936177850f * m_ - 0.0040720468f * s_,
		1.9779984951f * l_ - 2.4285922050f * m_ + 0.4505937099f * s_,
		0.0259040371f * l_ + 0.7827717662f * m_ - 0.8086757660f * s_
	);
}

vec3 oklab_to_linear_srgb(vec3 c)
{
	float l_ = c.x + 0.3963377774f * c.y + 0.2158037573f * c.z;
	float m_ = c.x - 0.1055613458f * c.y - 0.0638541728f * c.z;
	float s_ = c.x - 0.0894841775f * c.y - 1.2914855480f * c.z;

	float l = l_ * l_ * l_;
	float m = m_ * m_ * m_;
	float s = s_ * s_ * s_;

	return vec3(
		+4.0767416621f * l - 3.3077115913f * m + 0.2309699292f * s,
		-1.2684380046f * l + 2.6097574011f * m - 0.3413193965f * s,
		-0.0041960863f * l - 0.7034186147f * m + 1.7076147010f * s
	);
}

// Finds the maximum saturation possible for a given hue that fits in sRGB
// Saturation here is defined as S = C/L
// a and b must be normalized so a^2 + b^2 == 1
float compute_max_saturation(float a, float b)
{
	// Max saturation will be when one of r, g or b goes below zero.

	// Select different coefficients depending on which component goes below zero first
	float k0, k1, k2, k3, k4, wl, wm, ws;

	if (-1.88170328f * a - 0.80936493f * b > 1.f)
	{
		// Red component
		k0 = +1.19086277f; k1 = +1.76576728f; k2 = +0.59662641f; k3 = +0.75515197f; k4 = +0.56771245f;
		wl = +4.0767416621f; wm = -3.3077115913f; ws = +0.2309699292f;
	}
	else if (1.81444104f * a - 1.19445276f * b > 1.f)
	{
		// Green component
		k0 = +0.73956515f; k1 = -0.45954404f; k2 = +0.08285427f; k3 = +0.12541070f; k4 = +0.14503204f;
		wl = -1.2684380046f; wm = +2.6097574011f; ws = -0.3413193965f;
	}
	else
	{
		// Blue component
		k0 = +1.35733652f; k1 = -0.00915799f; k2 = -1.15130210f; k3 = -0.50559606f; k4 = +0.00692167f;
		wl = -0.0041960863f; wm = -0.7034186147f; ws = +1.7076147010f;
	}

	// Approximate max saturation using a polynomial:
	float S = k0 + k1 * a + k2 * b + k3 * a * a + k4 * a * b;

	// Do one step Halley's method to get closer
	// this gives an error less than 10e6, except for some blue hues where the dS/dh is close to infinite
	// this should be sufficient for most applications, otherwise do two/three steps

	float k_l = +0.3963377774f * a + 0.2158037573f * b;
	float k_m = -0.1055613458f * a - 0.0638541728f * b;
	float k_s = -0.0894841775f * a - 1.2914855480f * b;

	{
		float l_ = 1.f + S * k_l;
		float m_ = 1.f + S * k_m;
		float s_ = 1.f + S * k_s;

		float l = l_ * l_ * l_;
		float m = m_ * m_ * m_;
		float s = s_ * s_ * s_;

		float l_dS = 3.f * k_l * l_ * l_;
		float m_dS = 3.f * k_m * m_ * m_;
		float s_dS = 3.f * k_s * s_ * s_;

		float l_dS2 = 6.f * k_l * k_l * l_;
		float m_dS2 = 6.f * k_m * k_m * m_;
		float s_dS2 = 6.f * k_s * k_s * s_;

		float f = wl * l + wm * m + ws * s;
		float f1 = wl * l_dS + wm * m_dS + ws * s_dS;
		float f2 = wl * l_dS2 + wm * m_dS2 + ws * s_dS2;

		S = S - f * f1 / (f1 * f1 - 0.5f * f * f2);
	}

	return S;
}

// finds L_cusp and C_cusp for a given hue
// a and b must be normalized so a^2 + b^2 == 1
vec2 find_cusp(float a, float b)
{
	// First, find the maximum saturation (saturation S = C/L)
	float S_cusp = compute_max_saturation(a, b);

	// Convert to linear sRGB to find the first point where at least one of r,g or b >= 1:
	vec3 rgb_at_max = oklab_to_linear_srgb(vec3( 1, S_cusp * a, S_cusp * b ));
	float L_cusp = cbrt(1.f / max(max(rgb_at_max.r, rgb_at_max.g), rgb_at_max.b));
	float C_cusp = L_cusp * S_cusp;

	return vec2( L_cusp , C_cusp );
}

// Finds intersection of the line defined by
// L = L0 * (1 - t) + t * L1;
// C = t * C1;
// a and b must be normalized so a^2 + b^2 == 1
float find_gamut_intersection(float a, float b, float L1, float C1, float L0, vec2 cusp)
{
	// Find the intersection for upper and lower half seprately
	float t;
	if (((L1 - L0) * cusp.y - (cusp.x - L0) * C1) <= 0.f)
	{
		// Lower half

		t = cusp.y * L0 / (C1 * cusp.x + cusp.y * (L0 - L1));
	}
	else
	{
		// Upper half

		// First intersect with triangle
		t = cusp.y * (L0 - 1.f) / (C1 * (cusp.x - 1.f) + cusp.y * (L0 - L1));

		// Then one step Halley's method
		{
			float dL = L1 - L0;
			float dC = C1;

			float k_l = +0.3963377774f * a + 0.2158037573f * b;
			float k_m = -0.1055613458f * a - 0.0638541728f * b;
			float k_s = -0.0894841775f * a - 1.2914855480f * b;

			float l_dt = dL + dC * k_l;
			float m_dt = dL + dC * k_m;
			float s_dt = dL + dC * k_s;


			// If higher accuracy is required, 2 or 3 iterations of the following block can be used:
			{
				float L = L0 * (1.f - t) + t * L1;
				float C = t * C1;

				float l_ = L + C * k_l;
				float m_ = L + C * k_m;
				float s_ = L + C * k_s;

				float l = l_ * l_ * l_;
				float m = m_ * m_ * m_;
				float s = s_ * s_ * s_;

				float ldt = 3.f * l_dt * l_ * l_;
				float mdt = 3.f * m_dt * m_ * m_;
				float sdt = 3.f * s_dt * s_ * s_;

				float ldt2 = 6.f * l_dt * l_dt * l_;
				float mdt2 = 6.f * m_dt * m_dt * m_;
				float sdt2 = 6.f * s_dt * s_dt * s_;

				float r = 4.0767416621f * l - 3.3077115913f * m + 0.2309699292f * s - 1.f;
				float r1 = 4.0767416621f * ldt - 3.3077115913f * mdt + 0.2309699292f * sdt;
				float r2 = 4.0767416621f * ldt2 - 3.3077115913f * mdt2 + 0.2309699292f * sdt2;

				float u_r = r1 / (r1 * r1 - 0.5f * r * r2);
				float t_r = -r * u_r;

				float g = -1.2684380046f * l + 2.6097574011f * m - 0.3413193965f * s - 1.f;
				float g1 = -1.2684380046f * ldt + 2.6097574011f * mdt - 0.3413193965f * sdt;
				float g2 = -1.2684380046f * ldt2 + 2.6097574011f * mdt2 - 0.3413193965f * sdt2;

				float u_g = g1 / (g1 * g1 - 0.5f * g * g2);
				float t_g = -g * u_g;

				float b = -0.0041960863f * l - 0.7034186147f * m + 1.7076147010f * s - 1.f;
				float b1 = -0.0041960863f * ldt - 0.7034186147f * mdt + 1.7076147010f * sdt;
				float b2 = -0.0041960863f * ldt2 - 0.7034186147f * mdt2 + 1.7076147010f * sdt2;

				float u_b = b1 / (b1 * b1 - 0.5f * b * b2);
				float t_b = -b * u_b;

				t_r = u_r >= 0.f ? t_r : 10000.f;
				t_g = u_g >= 0.f ? t_g : 10000.f;
				t_b = u_b >= 0.f ? t_b : 10000.f;

				t += min(t_r, min(t_g, t_b));
			}
		}
	}

	return t;
}

float find_gamut_intersection(float a, float b, float L1, float C1, float L0)
{
	// Find the cusp of the gamut triangle
	vec2 cusp = find_cusp(a, b);

	return find_gamut_intersection(a, b, L1, C1, L0, cusp);
}

vec3 gamut_clip_preserve_chroma(vec3 rgb)
{
	if (rgb.r < 1.f && rgb.g < 1.f && rgb.b < 1.f && rgb.r > 0.f && rgb.g > 0.f && rgb.b > 0.f)
		return rgb;

	vec3 lab = linear_srgb_to_oklab(rgb);

	float L = lab.x;
	float eps = 0.00001f;
	float C = max(eps, sqrt(lab.y * lab.y + lab.z * lab.z));
	float a_ = lab.y / C;
	float b_ = lab.z / C;

	float L0 = clamp(L, 0.f, 1.f);

	float t = find_gamut_intersection(a_, b_, L, C, L0);
	float L_clipped = L0 * (1.f - t) + t * L;
	float C_clipped = t * C;

	return oklab_to_linear_srgb(vec3( L_clipped, C_clipped * a_, C_clipped * b_ ));
}

vec3 gamut_clip_project_to_0_5(vec3 rgb)
{
	if (rgb.r < 1.f && rgb.g < 1.f && rgb.b < 1.f && rgb.r > 0.f && rgb.g > 0.f && rgb.b > 0.f)
		return rgb;

	vec3 lab = linear_srgb_to_oklab(rgb);

	float L = lab.x;
	float eps = 0.00001f;
	float C = max(eps, sqrt(lab.y * lab.y + lab.z * lab.z));
	float a_ = lab.y / C;
	float b_ = lab.z / C;

	float L0 = 0.5;

	float t = find_gamut_intersection(a_, b_, L, C, L0);
	float L_clipped = L0 * (1.f - t) + t * L;
	float C_clipped = t * C;

	return oklab_to_linear_srgb(vec3( L_clipped, C_clipped * a_, C_clipped * b_ ));
}

vec3 gamut_clip_project_to_L_cusp(vec3 rgb)
{
	if (rgb.r < 1.f && rgb.g < 1.f && rgb.b < 1.f && rgb.r > 0.f && rgb.g > 0.f && rgb.b > 0.f)
		return rgb;

	vec3 lab = linear_srgb_to_oklab(rgb);

	float L = lab.x;
	float eps = 0.00001f;
	float C = max(eps, sqrt(lab.y * lab.y + lab.z * lab.z));
	float a_ = lab.y / C;
	float b_ = lab.z / C;

	// The cusp is computed here and in find_gamut_intersection, an optimized solution would only compute it once.
	vec2 cusp = find_cusp(a_, b_);

	float L0 = cusp.x;

	float t = find_gamut_intersection(a_, b_, L, C, L0);

	float L_clipped = L0 * (1.f - t) + t * L;
	float C_clipped = t * C;

	return oklab_to_linear_srgb(vec3( L_clipped, C_clipped * a_, C_clipped * b_ ));
}

vec3 gamut_clip_adaptive_L0_0_5(vec3 rgb, float alpha)
{
	if (rgb.r < 1.f && rgb.g < 1.f && rgb.b < 1.f && rgb.r > 0.f && rgb.g > 0.f && rgb.b > 0.f)
		return rgb;

	vec3 lab = linear_srgb_to_oklab(rgb);

	float L = lab.x;
	float eps = 0.00001f;
	float C = max(eps, sqrt(lab.y * lab.y + lab.z * lab.z));
	float a_ = lab.y / C;
	float b_ = lab.z / C;

	float Ld = L - 0.5f;
	float e1 = 0.5f + abs(Ld) + alpha * C;
	float L0 = 0.5f * (1.f + sign(Ld) * (e1 - sqrt(e1 * e1 - 2.f * abs(Ld))));

	float t = find_gamut_intersection(a_, b_, L, C, L0);
	float L_clipped = L0 * (1.f - t) + t * L;
	float C_clipped = t * C;

	return oklab_to_linear_srgb(vec3( L_clipped, C_clipped * a_, C_clipped * b_ ));
}

vec3 gamut_clip_adaptive_L0_L_cusp(vec3 rgb, float alpha)
{
	if (rgb.r < 1.f && rgb.g < 1.f && rgb.b < 1.f && rgb.r > 0.f && rgb.g > 0.f && rgb.b > 0.f)
		return rgb;

	vec3 lab = linear_srgb_to_oklab(rgb);

	float L = lab.x;
	float eps = 0.00001f;
	float C = max(eps, sqrt(lab.y * lab.y + lab.z * lab.z));
	float a_ = lab.y / C;
	float b_ = lab.z / C;

	// The cusp is computed here and in find_gamut_intersection, an optimized solution would only compute it once.
	vec2 cusp = find_cusp(a_, b_);

	float Ld = L - cusp.x;
	float k = 2.f * (Ld > 0.f ? 1.f - cusp.x : cusp.x);

	float e1 = 0.5f * k + abs(Ld) + alpha * C / k;
	float L0 = cusp.x + 0.5f * (sign(Ld) * (e1 - sqrt(e1 * e1 - 2.f * k * abs(Ld))));

	float t = find_gamut_intersection(a_, b_, L, C, L0);
	float L_clipped = L0 * (1.f - t) + t * L;
	float C_clipped = t * C;

	return oklab_to_linear_srgb(vec3( L_clipped, C_clipped * a_, C_clipped * b_ ));
}

float toe(float x)
{
	float k_1 = 0.206f;
	float k_2 = 0.03f;
	float k_3 = (1.f + k_1) / (1.f + k_2);
	return 0.5f * (k_3 * x - k_1 + sqrt((k_3 * x - k_1) * (k_3 * x - k_1) + 4.f * k_2 * k_3 * x));
}

float toe_inv(float x)
{
	float k_1 = 0.206f;
	float k_2 = 0.03f;
	float k_3 = (1.f + k_1) / (1.f + k_2);
	return (x * x + k_1 * x) / (k_3 * (x + k_2));
}

vec2 to_ST(vec2 cusp)
{
	float L = cusp.x;
	float C = cusp.y;
	return vec2( C / L, C / (1.f - L) );
}

// Returns a smooth approximation of the location of the cusp
// This polynomial was created by an optimization process
// It has been designed so that S_mid < S_max and T_mid < T_max
vec2 get_ST_mid(float a_, float b_)
{
	float S = 0.11516993f + 1.f / (
		+7.44778970f + 4.15901240f * b_
		+ a_ * (-2.19557347f + 1.75198401f * b_
			+ a_ * (-2.13704948f - 10.02301043f * b_
				+ a_ * (-4.24894561f + 5.38770819f * b_ + 4.69891013f * a_
					)))
		);

	float T = 0.11239642f + 1.f / (
		+1.61320320f - 0.68124379f * b_
		+ a_ * (+0.40370612f + 0.90148123f * b_
			+ a_ * (-0.27087943f + 0.61223990f * b_
				+ a_ * (+0.00299215f - 0.45399568f * b_ - 0.14661872f * a_
					)))
		);

	return vec2( S, T );
}

vec3 get_Cs(float L, float a_, float b_)
{
	vec2 cusp = find_cusp(a_, b_);

	float C_max = find_gamut_intersection(a_, b_, L, 1.f, L, cusp);
	vec2 ST_max = to_ST(cusp);

	// Scale factor to compensate for the curved part of gamut shape:
	float k = C_max / min((L * ST_max.x), (1.f - L) * ST_max.y);

	float C_mid;
	{
		vec2 ST_mid = get_ST_mid(a_, b_);

		// Use a soft minimum function, instead of a sharp triangle shape to get a smooth value for chroma.
		float C_a = L * ST_mid.x;
		float C_b = (1.f - L) * ST_mid.y;
		C_mid = 0.9f * k * sqrt(sqrt(1.f / (1.f / (C_a * C_a * C_a * C_a) + 1.f / (C_b * C_b * C_b * C_b))));
	}

	float C_0;
	{
		// for C_0, the shape is independent of hue, so vec2 are constant. Values picked to roughly be the average values of vec2.
		float C_a = L * 0.4f;
		float C_b = (1.f - L) * 0.8f;

		// Use a soft minimum function, instead of a sharp triangle shape to get a smooth value for chroma.
		C_0 = sqrt(1.f / (1.f / (C_a * C_a) + 1.f / (C_b * C_b)));
	}

	return vec3( C_0, C_mid, C_max );
}

vec3 okhsl_to_srgb(vec3 hsl)
{
	float h = hsl.x;
	float s = hsl.y;
	float l = hsl.z;

	if (l == 1.0f)
	{
		return vec3( 1.f, 1.f, 1.f );
	}

	else if (l == 0.f)
	{
		return vec3( 0.f, 0.f, 0.f );
	}

	float a_ = cos(2.f * M_PI * h);
	float b_ = sin(2.f * M_PI * h);
	float L = toe_inv(l);

	vec3 cs = get_Cs(L, a_, b_);
	float C_0 = cs.x;
	float C_mid = cs.y;
	float C_max = cs.z;

	float mid = 0.8f;
	float mid_inv = 1.25f;

	float C, t, k_0, k_1, k_2;

	if (s < mid)
	{
		t = mid_inv * s;

		k_1 = mid * C_0;
		k_2 = (1.f - k_1 / C_mid);

		C = t * k_1 / (1.f - k_2 * t);
	}
	else
	{
		t = (s - mid)/ (1.f - mid);

		k_0 = C_mid;
		k_1 = (1.f - mid) * C_mid * C_mid * mid_inv * mid_inv / C_0;
		k_2 = (1.f - (k_1) / (C_max - C_mid));

		C = k_0 + t * k_1 / (1.f - k_2 * t);
	}

	vec3 rgb = oklab_to_linear_srgb(vec3( L, C * a_, C * b_ ));
	return vec3(
		srgb_transfer_function(rgb.r),
		srgb_transfer_function(rgb.g),
		srgb_transfer_function(rgb.b)
	);
}

vec3 srgb_to_okhsl(vec3 rgb)
{
	vec3 lab = linear_srgb_to_oklab(vec3(
		srgb_transfer_function_inv(rgb.r),
		srgb_transfer_function_inv(rgb.g),
		srgb_transfer_function_inv(rgb.b)
		));

	float C = sqrt(lab.y * lab.y + lab.z * lab.z);
	float a_ = lab.y / C;
	float b_ = lab.z / C;

	float L = lab.x;
	float h = 0.5f + 0.5f * atan(-lab.z, -lab.y) / M_PI;

	vec3 cs = get_Cs(L, a_, b_);
	float C_0 = cs.x;
	float C_mid = cs.y;
	float C_max = cs.z;

	// Inverse of the interpolation in okhsl_to_srgb:

	float mid = 0.8f;
	float mid_inv = 1.25f;

	float s;
	if (C < C_mid)
	{
		float k_1 = mid * C_0;
		float k_2 = (1.f - k_1 / C_mid);

		float t = C / (k_1 + k_2 * C);
		s = t * mid;
	}
	else
	{
		float k_0 = C_mid;
		float k_1 = (1.f - mid) * C_mid * C_mid * mid_inv * mid_inv / C_0;
		float k_2 = (1.f - (k_1) / (C_max - C_mid));

		float t = (C - k_0) / (k_1 + k_2 * (C - k_0));
		s = mid + (1.f - mid) * t;
	}

	float l = toe(L);
	return vec3( h, s, l );
}


vec3 okhsv_to_srgb(vec3 hsv)
{
	float h = hsv.x;
	float s = hsv.y;
	float v = hsv.z;

	float a_ = cos(2.f * M_PI * h);
	float b_ = sin(2.f * M_PI * h);

	vec2 cusp = find_cusp(a_, b_);
	vec2 ST_max = to_ST(cusp);
	float S_max = ST_max.x;
	float T_max = ST_max.y;
	float S_0 = 0.5f;
	float k = 1.f- S_0 / S_max;

	// first we compute L and V as if the gamut is a perfect triangle:

	// L, C when v==1:
	float L_v = 1.f   - s * S_0 / (S_0 + T_max - T_max * k * s);
	float C_v = s * T_max * S_0 / (S_0 + T_max - T_max * k * s);

	float L = v * L_v;
	float C = v * C_v;

	// then we compensate for both toe and the curved top part of the triangle:
	float L_vt = toe_inv(L_v);
	float C_vt = C_v * L_vt / L_v;

	float L_new = toe_inv(L);
	C = C * L_new / L;
	L = L_new;

	vec3 rgb_scale = oklab_to_linear_srgb(vec3( L_vt, a_ * C_vt, b_ * C_vt ));
	float scale_L = cbrt(1.f / max(max(rgb_scale.r, rgb_scale.g), max(rgb_scale.b, 0.f)));

	L = L * scale_L;
	C = C * scale_L;

	vec3 rgb = oklab_to_linear_srgb(vec3( L, C * a_, C * b_ ));
	return vec3(
		srgb_transfer_function(rgb.r),
		srgb_transfer_function(rgb.g),
		srgb_transfer_function(rgb.b)
	);
}

vec3 srgb_to_okhsv(vec3 rgb)
{
	vec3 lab = linear_srgb_to_oklab(vec3(
		srgb_transfer_function_inv(rgb.r),
		srgb_transfer_function_inv(rgb.g),
		srgb_transfer_function_inv(rgb.b)
		));

	float C = sqrt(lab.y * lab.y + lab.z * lab.z);
	float a_ = lab.y / C;
	float b_ = lab.z / C;

	float L = lab.x;
	float h = 0.5f + 0.5f * atan(-lab.z, -lab.y) / M_PI;

	vec2 cusp = find_cusp(a_, b_);
	vec2 ST_max = to_ST(cusp);
	float S_max = ST_max.x;
	float T_max = ST_max.y;
	float S_0 = 0.5f;
	float k = 1.f - S_0 / S_max;

	// first we find L_v, C_v, L_vt and C_vt

	float t = T_max / (C + L * T_max);
	float L_v = t * L;
	float C_v = t * C;

	float L_vt = toe_inv(L_v);
	float C_vt = C_v * L_vt / L_v;

	// we can then use these to invert the step that compensates for the toe and the curved top part of the triangle:
	vec3 rgb_scale = oklab_to_linear_srgb(vec3( L_vt, a_ * C_vt, b_ * C_vt ));
	float scale_L = cbrt(1.f / max(max(rgb_scale.r, rgb_scale.g), max(rgb_scale.b, 0.f)));

	L = L / scale_L;
	C = C / scale_L;

	C = C * toe(L) / L;
	L = toe(L);

	// we can now compute v and s:

	float v = L / L_v;
	float s = (S_0 + T_max) * C_v / ((T_max * S_0) + T_max * k * C_v);

	return vec3 (h, s, v );
}

//OKLAB


float remap(float value, float min1, float max1, float min2, float max2)
{
  return min2 + (value - min1) * (max2 - min2) / (max1 - min1);
}




//CURVES for 0-1 values

float rampTop(float value, float power) //bulge near top right, bump with pow >1
{
	if (value <= 0) return 0.0;
	if (value >= 1) return 1.0;
	if (power == 1) return value;
	return 1-pow(1-value, power);
}

//not working right?
vec3 rampTop(vec3 value, float power) //bulge near top right, bump with pow >1
{
	value.x = rampTop(value.x, power);
	value.y = rampTop(value.y, power);
	value.z = rampTop(value.z, power);
	return value;
}


float rampBot(float value, float power) //bulge near bottom left, bump with pow <1
{
	if (value <= 0) return 0.0;
	if (value >= 1) return 1.0;
	if (power == 1) return value;
	return pow(value, power);
}


vec3 rampBot(vec3 value, float power) //bulge near top right, bump with pow >1
{
	value.x = rampBot(value.x, power);
	value.y = rampBot(value.y, power);
	value.z = rampBot(value.z, power);
	return value;
}


float rampMid(float value, float power) //bulge near top right, bump with pow >1
{
	return (rampTop(value, power)+rampBot(value,1/power))/2;
}


vec3 rampMid(vec3 value, float power) //bulge near top right, bump with pow >1
{
	value.x = rampMid(value.x, power);
	value.y = rampMid(value.y, power);
	value.z = rampMid(value.z, power);
	return value;
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


float saw(float value, float freq)
{
	return abs(mod(freq*2*value,2)-1);
}


//float saw(float value, float period)
//{
//	return abs(mod(freq*2*value,2)-1);
//}



//FANCY POSTPROCESSING

vec3 DimWhites(vec3 rgb, float dim, float dimThreshold, float dimSlope, float dimCompensation, float lumaRatio)
{
	//float whitenessdot = dot(normalize(color.rgb), vec3(0.57735, 0.57735, 0.57735));
	//float whiteness = remap(whitenessdot, 0.5, 1, 0, 1);
	//float whiteness = (whitenessdot-0.5)*2;
	//float whiteness = (color.r + color.g + color.b)/3; //brightness based
	const vec3 percp = vec3(0.2125, 0.7154, 0.0721);
	float whiteness = mix(rgb2hsl(rgb).z, dot(rgb, percp), lumaRatio); //brightness based

	if (whiteness > dimThreshold)
	{
	  whiteness = (whiteness-dimThreshold)/(1-dimThreshold); //normalize
	  float slopedwhiteness = pow(whiteness,dimSlope) *dim;
	  //float slopedwhiteness = 1-pow(1-whiteness,0.125);
	  //slopedwhiteness *= (1-DimThreshold); //set maximum dim level
	  rgb = rgb *(1-slopedwhiteness);
	  //color.rgb = color.rgb * (pow(1-whiteness*Dim, DimSlope));
	  //color.rgb = color.rgb * (1-whiteness*Dim); //darken whites

	  //color.rgb = color.rgb + (1-whiteness)*Lum; //brighten blacks
	}

	if (dimCompensation > 0)
	{
	  rgb *= 1+dim*(1-dimThreshold)*dimCompensation/dimSlope; //overall compensation of lost brightness
	}

	rgb = clamp(rgb,0,1);
	return rgb;
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
	  color.rgb = rgb2hsl(color.xyz);
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


vec3 expandBlacks1(vec3 rgb, float lumaRatio)
{
	const vec3 percp = vec3(0.2125, 0.7154, 0.0721);
	vec3 hsl = rgb2hsl(rgb);
	float whiteness = mix(hsl.z, dot(rgb, percp), //luminance based
	  lumaRatio); //brightness based, better results here?

	//if (whiteness > 0)
	//{
	  //const vec3 white = vec3(1,1,1);
	  //whiteness = (whiteness-DimThreshold)/(1-DimThreshold); //
	  //float slopedwhiteness = pow(whiteness,1);
	  float slopedblackness = 1-pow(whiteness,ExpandBlacksSlope);
	  //float slopedblackness = 1-pow(whiteness,0.1);
	  //float slopedblackness = pow(1-whiteness,128);
	  //slopedwhiteness *= (1-DimThreshold); //set maximum dim level

	  //color.z = pow(color.z, 0.5);
	  float slopedsatamt = (1-pow(1-hsl.y,4)) *pow(1-hsl.y, 1) *1.87;

	  slopedsatamt = clamp(slopedsatamt, 0.0, 0.1);

	  hsl.z = mix(hsl.z, pow(hsl.z, ExpandBlacksGamma), slopedblackness*ExpandBlacks * (1-slopedsatamt*ExpandBlacksSat)); //curve eval
		//color.z *= 1-log(pow(whiteness, ExpandBlacksSlope))*ExpandBlacks*(1-slopedsatamt*ExpandBlacksSat); //logarithmic

	  if (ExpandBlacksSat>0)
	    hsl.y = mix(hsl.y, pow(hsl.z, ExpandBlacksGamma), slopedblackness*ExpandBlacks*slopedsatamt*ExpandBlacksSat);//curve eval
		//color.y *= 1-log(pow(whiteness, ExpandBlacksSlope))*ExpandBlacks*(slopedsatamt*ExpandBlacksSat); //logarithmic

	  //color.rgb = mix(color.rgb, white, slopedblackness*0.33);
	  rgb = rgb2hsl(hsl);

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

	return rgb;
}


vec3 expandBlacks(vec3 rgb, float lumaRatio)
{
	const vec3 percp = vec3(0.2125, 0.7154, 0.0721);

	vec3 hsl = rgb2hsl(rgb);
	float l = mix(hsl.z, dot(rgb, percp), lumaRatio);
	float v = rgb2hsv(rgb).z;

	//hsl.z = mix(hsl.z, pow(hsl.z, 0.25), rampBot(1-hsl.z,32));// 1*rampBot(1-v,16));
	//hsl.z = mix(hsl.z, hsl.z*10, rampBot(1-hsl.z,16));// 1*rampBot(1-v,16));
	hsl.z = mix(hsl.z, hsl.z*16, 1 * rampBot(1-l,32) );

	rgb = rgb2hsl(hsl);
	return rgb;
}

//REPLACE=fullscreen.part1.glsl

float getLuma5x5(sampler2D tex) //average luma of 25 uniformly distributed points for 4x3 displays
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


float getLuma8x4(sampler2D tex) //average luma of 32 uniformly distributed points for 16x9 displays
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


float getLuma8x4Optimized(sampler2D tex) //average luma of 32 uniformly distributed points for 16x9 displays
{
	const vec3 percp = vec3(0.2125, 0.7154, 0.0721);
	//const vec3 percp = vec3(0.3333);

	const vec2 c = vec2(0.5, 0.5);

	const vec2 p11 = vec2(-0.4375, -0.125);
	const vec2 p12 = vec2(-0.3125, -0.125);
	const vec2 p13 = vec2(-0.1875, -0.125);
	const vec2 p14 = vec2(-0.0625, -0.125);
	const vec2 p15 = vec2(0.0625, -0.125);
	const vec2 p16 = vec2(0.1875, -0.125);
	const vec2 p17 = vec2(0.3125, -0.125);
	const vec2 p18 = vec2(0.4375, -0.125);

	const vec2 p21 = vec2(-0.4375, -0.375);
	const vec2 p22 = vec2(-0.3125, -0.375);
	const vec2 p23 = vec2(-0.1875, -0.375);
	const vec2 p24 = vec2(-0.0625, -0.375);
	const vec2 p25 = vec2(0.0625, -0.375);
	const vec2 p26 = vec2(0.1875, -0.375);
	const vec2 p27 = vec2(0.3125, -0.375);
	const vec2 p28 = vec2(0.4375, -0.375);

	/*
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
	*/

	float l = 0; //luminance accumulator

	l += dot(texture2D(tex, c+p11).rgb, percp);
	l += dot(texture2D(tex, c+p12).rgb, percp);
	l += dot(texture2D(tex, c+p13).rgb, percp);
	l += dot(texture2D(tex, c+p14).rgb, percp);
	l += dot(texture2D(tex, c+p15).rgb, percp);
	l += dot(texture2D(tex, c+p16).rgb, percp);
	l += dot(texture2D(tex, c+p17).rgb, percp);
	l += dot(texture2D(tex, c+p18).rgb, percp);

	l += dot(texture2D(tex, c+p21).rgb, percp);
	l += dot(texture2D(tex, c+p22).rgb, percp);
	l += dot(texture2D(tex, c+p23).rgb, percp);
	l += dot(texture2D(tex, c+p24).rgb, percp);
	l += dot(texture2D(tex, c+p25).rgb, percp);
	l += dot(texture2D(tex, c+p26).rgb, percp);
	l += dot(texture2D(tex, c+p27).rgb, percp);
	l += dot(texture2D(tex, c+p28).rgb, percp);

	l += dot(texture2D(tex, c-p21).rgb, percp);
	l += dot(texture2D(tex, c-p22).rgb, percp);
	l += dot(texture2D(tex, c-p23).rgb, percp);
	l += dot(texture2D(tex, c-p24).rgb, percp);
	l += dot(texture2D(tex, c-p25).rgb, percp);
	l += dot(texture2D(tex, c-p26).rgb, percp);
	l += dot(texture2D(tex, c-p27).rgb, percp);
	l += dot(texture2D(tex, c-p28).rgb, percp);

	l += dot(texture2D(tex, c-p11).rgb, percp);
	l += dot(texture2D(tex, c-p12).rgb, percp);
	l += dot(texture2D(tex, c-p13).rgb, percp);
	l += dot(texture2D(tex, c-p14).rgb, percp);
	l += dot(texture2D(tex, c-p15).rgb, percp);
	l += dot(texture2D(tex, c-p16).rgb, percp);
	l += dot(texture2D(tex, c-p17).rgb, percp);
	l += dot(texture2D(tex, c-p18).rgb, percp);

	return l / 32; //luminance normalization
}


vec3 ExpandExposure(vec3 rgb, sampler2D tex, vec2 texcoord, float exposureExpansion, float ignoreLevel)
{
	float e = getLuma8x4Optimized(tex);
	//e = min(0.7,e)/0.7;
	debugValue = e;

	if (e < ExposureExpansionThreshold && exposureExpansion > 0) //expand
	{
		e = e/ExposureExpansionThreshold; //normalize?

		//color.rgb *= 1+ rampBot(1-l,ExposureExpansionSlope)*ExposureExpansion;
		//color.rgb *= 1/l*ExposureExpansion;
		//color.rgb *= 1+ (1-log(l)*ExposureExpansionSlope-1)*ExposureExpansion;



		//soft clipped boost

		//if (e > ExposureExpansionIgnoreLevel)
		//{
			e = max(e,ignoreLevel); //better/faster limit?
			//e = min(l,0.8);
			e = e / exposureExpansion;
			e = rampBot(e,ExposureExpansionSlope);
			//e *= slopeBottom(e,0.125    );
			//debugValue = l;
			float f = 1/e;
			float slope = 4;

			float l = dot(rgb, vec3(0.3333));
			l=clamp(l,0,1);
			//l=1;

			vec3 hsl = rgb2hsl(rgb);
			// if (hsl.z<1) hsl.z = rampTop(hsl.z, f) ;
			//if (hsl.z<1) hsl.z = hsl.z*f;
			//float dark = 1-rampBot(l, 4);
			//dark = clamp(dark, 0.1, 0.9);
			//if (hsl.z<1) hsl.z = mix(hsl.z, rampTop(hsl.z, f), dark );
			//hsl.z = clamp(hsl.z, 0, 1);

			// if (hsl.y<1) hsl.y = hsl.y*f; //works well with rgb2hsl but not with rgb2hsl?
			//hsl.y = clamp(hsl.y, 0, 1);



			//rgb = rgb2hsl(hsl);

			//dynamic gamma
			//if (rgb.r>0 && rgb.r<1) rgb.r = rampBot(rgb.r, 1/(1+f/1));
			//if (rgb.g>0 && rgb.g<1) rgb.g = rampBot(rgb.g, 1/(1+f/1));
			//if (rgb.b>0 && rgb.b<1) rgb.b = rampBot(rgb.b, 1/(1+f/1));

			//vec3 percp = vec3(0.2126, 0.7152, 0.0722);
			//dynamic contrast
			//if (rgb.r>0 && rgb.r<1) rgb.r = rampTop(rgb.r, f);
		    //if (rgb.g>0 && rgb.g<1) rgb.g = rampTop(rgb.g, f);
			//if (rgb.b>0 && rgb.b<1) rgb.b = rampTop(rgb.b, f);

			//dynamic contrast+gamma averaged
			//rgb = rampMid(rgb,f);

			//dynamic fine tuned contrast vs gamma
			rgb = mix(rampTop(rgb,f), rampBot(rgb,e), 0.25);

			rgb = clamp(rgb, 0, 1);

			//if (rgb.r<1) rgb.r = mix(rgb.r, rampTop(rgb.r, f), rampBot(1-l, slope) );
			//if (rgb.g<1) rgb.g = mix(rgb.g, rampTop(rgb.g, f), rampBot(1-l, slope) );
			//if (rgb.b<1) rgb.b = mix(rgb.b, rampTop(rgb.b, f), rampBot(1-l, slope) );

			//if (rgb.r<1) rgb.r = mix(rgb.r, rgb.r*f, rampBot(l, slope) );
			//if (rgb.g<1) rgb.g = mix(rgb.g, rgb.g*f, rampBot(l, slope) );
			//if (rgb.b<1) rgb.b = mix(rgb.b, rgb.b*f, rampBot(l, slope) );
		//}
		/*else //limit
		{
			float lmax = rampBot(ExposureExpansionIgnoreLevel,ExposureExpansionSlope);
			float pmax = (1/lmax) * ExposureExpansion;
			float rmax = rampTop(color.r, pmax);
			float gmax = rampTop(color.g, pmax);
			float bmax = rampTop(color.b, pmax);
			if (color.r<1) color.r = rmax;
			if (color.g<1) color.g = gmax;
			if (color.b<1) color.b = bmax;
		}*/

	}

	return rgb;
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

vec3 GammaCorrect(vec3 rgb, float gcor)
{
	//float p = 1/GammaCorrection;
	rgb.r = rgb.r<=0?0:pow(rgb.r, gcor);
	rgb.g = rgb.g<=0?0:pow(rgb.g, gcor);
	rgb.b = rgb.b<=0?0:pow(rgb.b, gcor);

	return rgb;
}

//vec4 luminance(sampler2D tex, vec2 texcoord)
//{
//	return textureLod(tex, texcoord, log2(1));
//}

//float l;

vec3 SaturateLows1(vec3 color)
{
	const vec3 percp = vec3(0.2125, 0.7154, 0.0721);
	float luma = dot(color.rgb, percp);
	vec3 hsl = rgb2hsl(color);
	if (hsl.y == 0) return color;
	//float add = hsl.z<0.25? (0.25-hsl.z)/0.25 * 1 : 0;
	float add = rampBot(1-luma, 4);
	hsl.y = hsl.y*0.4 + add*0.6;
	hsl.y = clamp(hsl.y, 0, 1);
	return rgb2hsl(hsl);
}

vec3 SaturateLows2(vec3 rgb, float baseSat, float lowSat, float lumaRatio) //by hsl
{
	//lumaRatio=0;
	const vec3 percp = vec3(0.2125, 0.7154, 0.0721);
	vec3 hsl = rgb2hsl(rgb);
	if (hsl.y == 0) return rgb;
	float luma = mix(dot(rgb, percp), hsl.z, lumaRatio);
	//float add = hsl.z<0.25? (0.25-hsl.z)/0.25 * 1 : 0;
	//float add = rampBot(1-luma, 4);
	//hsl.y = hsl.y*0.5 + 0.7*rampBot(1-luma, 4);
	//hsl.y = hsl.y*0.4 + add*0.6;
	hsl.y = hsl.y*baseSat +  32*rampBot(1-luma, 8)* rampTop(hsl.y,1) //filter desaturated
	//* rampBot(hsl.y,0.125) //filter highs?
	;
	hsl.y = clamp(hsl.y, 0, 1);
	return rgb2hsl(hsl);
}

vec3 BoostLows(vec3 rgb, float coAmt, float lumaRatio, float slope)
{
	const vec3 percp = vec3(0.2125, 0.7154, 0.0721);
	const vec3 linp = vec3(0.3333);
	float luma = dot(rgb, percp);
	float lin = dot(rgb, linp);
	float l = mix(lin, luma, lumaRatio);

	l = clamp(l, 0, 1);

	//rgb = mix(rgb, rgb*amount, f);
	//float slope = 2;
	//rgb.r = mix(rgb.r, rampBot(rgb.r, slope)*amount, f);
	//rgb.g = mix(rgb.g, rampBot(rgb.g, slope)*amount, f);
	//rgb.b = mix(rgb.b, rampBot(rgb.b, slope)*amount, f);
	//rgb = clamp(rgb, 0, 1);

	float mixSlope = rampBot(1-l, slope);

	//contrast
	float coSlope = coAmt; //normal=1
	float coMult = 1; //normal=1
	rgb = mix(rgb, rampTop(rgb, coSlope)*coMult, mixSlope);

	/*
	//saturation
	float satSlope = 1;
	float satMult = 1; //32
	vec3 hsl = rgb2hsl(rgb);
	hsl.y = mix(hsl.y, rampTop(hsl.y, satSlope)*satMult, mixSlope);
	//hsl.z = clamp(hsl.z, 0, 1);
	hsl.y = clamp(hsl.y, 0, 1);
	rgb = rgb2hsl(hsl);
	rgb = clamp(rgb, 0, 1);
	*/

	return rgb;
}


vec3 BrightenLows(vec3 rgb, float amount, float lumaRatio, float slope)
{
	const vec3 percp = vec3(0.2125, 0.7154, 0.0721);
	const vec3 linp = vec3(0.3333);
	float luma = dot(rgb, percp);
	float lin = dot(rgb, linp);
	float l = mix(lin, luma, lumaRatio);

	l = clamp(l, 0, 1);

	float mixSlope = rampBot(1-l, slope);
	rgb.r = mix(rgb.r, rgb.r+amount, mixSlope);
	rgb.g = mix(rgb.g, rgb.g+amount, mixSlope);
	rgb.b = mix(rgb.b, rgb.b+amount, mixSlope);

	return rgb;
}


vec3 SaturateLows(vec3 rgb, float baseSat, float lowSat, float lumaRatio) //by hsv
{
	const vec3 percp = vec3(0.2125, 0.7154, 0.0721);
	//const vec3 percp = vec3(0.8, 0.3, 0.9);
	const vec3 linp = vec3(0.5774);
	float luma = dot(rgb, percp);

	//float f = rampBot(1-dot(rgb,linp),8);
	//rgb = mix(rgb, rgb*4, f);
	//rgb = clamp(rgb, 0, 1);

	vec3 hsl = rgb2hsl(rgb);
	vec3 hsv = rgb2hsv(rgb);
	//if (hsv.y == 0) return rgb;

	float l = mix(hsl.z, luma, 0); //linear to percp ratio
	float v = hsv.z;
	//float s = hsv.y;
	float s = hsl.y;

	//todo: fix cmy
	float darkness = rampBot(1-l,8);
	//s = s*Saturation + 8*rampBot(1-l,8) * rampBot(s,1);
	//s = s*rampBot(1-l,2)*16;

	//s = mix(s, rampTop(s, 2)*16, rampBot(1-l,2)); //WTF? not working as in BoostLows
	//hsl.y = mix(hsl.y, rampTop(hsl.y, 2)*16, rampBot(1-l,2)); //WTF? not working as in BoostLows

	s = s*Saturation + 4 * darkness * rampBot(s,0.33);
	//s = 1*rampBot(s*Saturation + 0.4*(1-l) * rampBot(s,1),1);
	s = clamp(s, 0, 1);
	hsl.y = s;
	//hsv.y = s;
	//hsl.z = l + 0.1*rampBot(1-v,4) * rampBot(s,1);
	//hsl.z = mix(hsl.z, hsl.z*16, 1 * rampBot(1-l,32) );


	//normalize?
	//hsl.z = hsl.z*0.75 + 0.25* (1 - luma);
	//hsl.z = (hsl.z - 0.2) * 1.4;

	//rgb = hsv2rgb(hsv);

	//float f = rampBot(1-l,8);
	//hsl.z = mix(hsl.z, l*4, f);
	//hsl.z = mix(hsl.z, pow(l, 0.5), f);
	//hsl.z = clamp(hsl.z, 0, 1);

	rgb = rgb2hsl(hsl);
	//rgb.r = mix(rgb.r, pow(rgb.r, 0.5), f);
	//rgb.g = mix(rgb.g, pow(rgb.g, 0.5), f);
	//rgb.b = mix(rgb.b, pow(rgb.b, 0.5), f);
	return rgb;
}


vec3 UniformColor(vec3 rgb)
{
	vec3 hsl = rgb2hsl(rgb);

	float r = dot(rgb,vec3(1,0,0));
	float g = dot(rgb,vec3(0,1,0));
	float b = dot(rgb,vec3(0,0,1));

	float c = dot(rgb,vec3(0,0.7,0.7));
	float m = dot(rgb,vec3(0.7,0,0.7));
	float y = dot(rgb,vec3(0.7,0.7,0));

	const vec3 percp = vec3(0.2125, 0.7154, 0.0721);
	float luma = dot(rgb,percp);

	//float luma = r*0.2 + g*0.7 + b*0.07;
	//luma *= 4;


	//float lumafix = r*0.05 + g*0.7 + b*0.05
	//  + c*-0.3 + m*0.3 + y*-0.3;
	//lumafix *= 21;

	//float lfix = r*0.8 + g*0.3 + b*0.9
	//  + c*-0.1 + m*-0.6 + y*-0.1;
	//float lfix = c*1.2 + m*1.7 + y*1.1;
	//float lfix = m*1 + y*1.1 + c*1.2
	//float lfix =  + r*5 + g*1 + b*14;
	float h = hsl.x*360;
	float rd = 1-abs(clamp(h<300?0-h:360-h,-60,60))/60;
	float yd = 1-abs(clamp(60-h,-60,60))/60;
	float gd = 1-abs(clamp(120-h,-60,60))/60;
	float cd = 1-abs(clamp(180-h,-60,60))/60;
	float bd = 1-abs(clamp(240-h,-60,60))/60;
	float md = 1-abs(clamp(300-h,-60,60))/60;
	float wd = rgb.r*rgb.g*rgb.b;

	//lfix = (1/luma)*2;
	//float lfix = r*0.8 + g*0.3 + b*0.9;
	//lfix /= 4;
	//float lfix = (rgb.r*10 + rgb.g*0.1 + rgb.b*10);
	//lfix /= 30;
	//lfix = hssl.z*0.5;

	/*
	float lfix = rampBot(hsl.z * ( //try with only r g b
		rd*0.6
	  + yd*0.2
	  + gd*0.5
	  + cd*0.3
	  + bd*0.7
	  + md*0.4
	),0.5);
	lfix *= 1.2;
	*/


	rd = 1-abs(clamp(h<240?0-h:360-h,-120,120))/120;
	gd = 1-abs(clamp(120-h,-120,120))/120;
	bd = 1-abs(clamp(240-h,-120,120))/120;

	float lfix = hsl.z * ( //try with only r g b
		rd*0.8
	  //- yd*0.1
	  + gd*0.5
	  //- cd*0.1
	  + bd*0.9
	  //- md*0.2
	);
	lfix *= 1.3;


	//float s = rampBot(hsl.y+(1-lfix/20),0.125);
	//float s = (1-pow(2*hsl.y-1,8)) * (0.4 + 0.6*rampBot(1-lfix,4));
	//float s = rampBot(1-wd,1) * (0.4 + 0.6*rampBot(1-lfix,4));

	float msat = 0.4*rampBot(hsl.y,0.5); //VHS-like
	float s = (msat + 4*rampTop(1-lfix,0.1)); //VHS-like
	s = s*rampBot(hsl.y,0.125);
	//s = 1;

	//float s = mix(hsl.y,0.4,rampTop(hsl.z,0.25)) + 0.6*rampBot(1-lfix,4);

	//float s = rd*0.2+0.8*(1-luma)*rd
	//  + gd*0.7
	//  + bd*0.07+0.9*(1-luma)*bd;

	//s =1;

	//filter cmy (60 180 300)
	float d = 1-abs(clamp(60-mod(h,120),-60,60))/60;
	//lfix = lfix * (1-0.25*rampBot(d,1));

	hsl.y = clamp(hsl.y,0,1);
	hsl.y = hsl.y==0? 0 : s;

	//hsl.z = mix(hsl.z,lfix,0.1);
	hsl.z = lfix;
	//hsl.z -= 0.075;
	//hsl.z *= 1.5;
	rgb = rgb2hsl(hsl);
	//rgb = rgb * (1-0.33*rampBot(d,1));;
	return rgb;
}


vec3 Oklabify(vec3 rgb, float amount) //do with corr vector
{
	//const vec3 corr = normalize(vec3(0.7875,0.2846,0.9279));
	//float comp = dot(color.rgb, corr);

	vec3 hsl = rgb2hsl(rgb);
	//vec3 lsh = vec3(hsl.z, hsl.y*0.25, hsl.x+0.1);
	//vec3 lch = rgb2lch(color);
	//vec3 lchfix = vec3(mix(lch.x*0.125,0.5,0), lch.y*0.1, lch.z/360);

	//c.rgb = mix(c.rgb,oklab2rgb(oklch2oklab(lsh)),0.5);
	//return oklab2rgb(oklch2oklab(lchfix));
	//hsl = vec3(hsl.x+0.085,clamp(hsl.y*(0-hsl.z*0+1), 0, 1),hsl.z);
	//const vec3 percp = vec3(0.2125, 0.7154, 0.0721);
	//float luma = dot(color.rgb, percp);

	hsl.x += 0.0805555;

	//float s = 0.4 + 0.6*rampTop(1-luma, 0.25);

	//float s = hsl.y*0.5 + 0.7*rampBot(1-luma, 4);
	//float s = 0.2 + 0.8*(luma<0.25? (0.25-luma)/0.25 : 0);
	//hsl.y = hsl.y*(0-hsl.z*0+1);
	//hsl.y = hsl.y>0?clamp(s, 0, 1):0;
	//const vec3 percp = vec3(0.2125, 0.7154, 0.0721);
	//hsl.z = dot(color.rgb, percp);
	vec3 okrgb = okhsl_to_srgb(hsl);
	return mix(rgb, okrgb, amount);
}


vec3 debug(vec3 rgb, float debugValue)
{
		vec3 vColour = vec3(0.0);
		vec2 vFontSize = vec2(16.0, 30.0); // Multiples of 4x5 work best
		vec2 vPixelCoord1 = vec2(5.0, 5.0);
		float customValueToPrint = debugValue;

		vec2 fixcoord = vec2(texcoord.x,1060-texcoord.y);
		float customDigit = PrintValue( (fixcoord - vPixelCoord1) / vFontSize, customValueToPrint, 1.0, 5.0);
		rgb = mix(rgb, vec3(0.0, 1.0, 1.0), customDigit);
		return rgb;
}


float GetSat(vec3 rgb) //from HSL? (or HLS, or HSI?)
{
	return 1-(3/(rgb.r+rgb.g+rgb.b))*min(rgb.r, min(rgb.g, rgb.b));
}


float GetSat2(vec3 rgb) //from HSV (generic?)
{
	float v = max(rgb.r, max(rgb.g, rgb.b));
	float s = (v - min(rgb.r, min(rgb.g, rgb.b)))/v;
	return s;
}


float GetSat3(vec3 rgb) //just chroma
{
	return max(rgb.r, max(rgb.g, rgb.b)) - min(rgb.r, min(rgb.g, rgb.b));
}


float GetSat4(vec3 rgb) //just chroma
{
	float mean = (rgb.r+rgb.g+rgb.b) /3.0;
	vec3 diff = rgb-vec3(mean);
	float variance = dot(diff,diff/3.0);
	float stddev = sqrt(variance);
	const float maxstddev = sqrt(2.0/3.0);

	return stddev/maxstddev;
}


vec3 FixSat(vec3 rgb)
{
	//ignore white, crop above
	if (rgb.r+rgb.g+rgb.b>=3.0f) return vec3(1);

	//ignore black, crop below
	if (rgb.r+rgb.g+rgb.b<=0.0f) return vec3(0);

	vec3 hsl = rgb2hsl(rgb);
	vec3 hsv = rgb2hsv(rgb);

	float oldsat = hsl.y; //not used, rewritten
	//float oldsat = hsv.y;
	//float oldsat = GetSat2(rgb);

	float resat = hsl.y;
	//float resat = hsv.y;
	//float resat = GetSat2(rgb);

	//float lig = hsl.z;
	//float lig = dot(rgb,vec3(0.2125, 0.7154, 0.0721));
	float lig = mix(hsl.z, dot(rgb,vec3(0.2125, 0.7154, 0.0721)), 0.333);
	//float lig = dot(rgb,vec3(0.3, 0.1, 0.6));
	//float lig = dot(rgb,vec3(0.3333));
	//float lig = (rgb.r+rgb.g+rgb.b)/3.0;
	//float lig = mix(hsl.z, dot(rgb,vec3(0.3333)), 0.5);

	//lig = rampTop(lig, 0.5); ///interesting...

	float resatlig = hsl.z;
	//float resatlig = dot(rgb,vec3(0.2125, 0.7154, 0.0721));
	//float resatlig = dot(rgb,vec3(0.3333));

	float dk = 1-lig;

	////!!REFILL, Y COORD (NEWSAT BY LIGHTNESS)

	//linear desaturate to top
	//hsl.y = hsl.y*0 + mix(Saturation,2,rampBot(1-lig,4));//

	//desaturate to centre, may be better
	//hsl.y = hsl.y*0 + mix(Saturation, 1, pow(2*lig-1,2) );
	//float fillmix = hsl.y*0 + mix(Saturation, 1, rampTop(1-saw(lig,2), 0.5) );
	//float fillmix = lig>0.5? rampBot(2*lig-1, 0.5) : rampBot(1-2*lig, 0.5); //needlie tip, =rampBot(saw,0.5)
	float fillmix = rampBot(saw(lig, 1), 1); //needle/parabola
	//float fillmix = lig>0.5? 1-rampBot(2-2*lig,0.25) : 1-rampBot(2*lig,0.25); //triangle tip, =rampTop(saw,0.5)?
	//float fillmix = rampTop(saw(lig, 1), 0.25); //spade/lance?

	//!!REFILL
	hsl.y = mix(Saturation, 2-Saturation, fillmix);
	//hsl.y = mix(Saturation, 1, fillmix);
	//hsl.y = mix(Saturation, Saturation*4, fillmix);
	//hsl.y = mix(Saturation, Saturation*2, fillmix);

	//full formula?
	//lig = rampBot(lig, 0.75);
	//hsl.y = mix(hsl.y*0.8, rampBot(hsl.y, 0.5) * (1+(1-saw(lig,2))), rampBot(saw(lig, 1),2));

	//if (lig <= 0.5) hsl.y = hsl.y + 0.5*(1-pow(4*lig-1,2));
	//float curve = 	0.5*(1-pow(1*lig-0.0,2));
	//float curve = 0.5*(1-pow(4*mod(lig,0.5)-1.0,2));
	//float curve = lig>0.5? 0 : rampBot(saw(lig, 1), 4)*8;
	//float curve = lig>0.5? 0 : rampBot(1-saw(lig, 2), 2)*2;
	float curve = lig>0.5? 0 : rampTop(1-saw(lig, 2), 0.5)*1;
	float deluma = 0.5;// 1-dot(rgb, vec3(0.1, 0.89, 0.01));
	//if (curve > 0) hsl.y = hsl.y + curve*deluma*4*Saturation;

	//////FIX ARTIFACTS? (SIMPLE)
	//hsl.y = hsl.y * rampBot(oldsat,0.25);
	//hsl.y = hsl.y * rampBot(hsv.z,1);
	//hsl.y = hsl.y * rampTop(hsv.z,0.5);
	//hsl.y = hsl.y * (1-rampBot(1-hsv.z,2)); //TEST
	//hsl.y = hsl.y * (1-rampTop(1-hsv.z,0.5)); //THESE

	//////FIX ARTIFACTS? (ADVANCED)
	//float satfac = 1-lig;
	//float satfac = pow(2*lig-1,2); //parabolic
	float satfac = lig<0.5? rampBot(2*lig-1, 0.5) : rampBot(1-2*lig, 0.5); //rootramp (triangle tip)
	//float satfac = lig<0.5? 1-rampBot(2*lig,8) : 1-rampBot(2-2*lig,8); //powerramp (needle tip)
	//float satfac = saw(lig,1); // sawtooth 1-0 T1 (2nx)
	//satfac = rampBot(satfac,0.5);
	//satfac = rampTop(satfac,2);

	//hsl.y = mix(hsl.y*rampBot(oldsat,0.25), hsl.y*rampBot(oldsat,0.001), satfac); //fix artifacts a bit
	//hsl.y = mix(hsl.y*rampBot(oldsat,1), hsl.y*rampBot(oldsat,0.001), satfac);

	//fine control above/below centre
	//float satformula = lig<0.5?pow(1-2*lig,2) :pow(2*lig-1,2);

	//float highformula = rampTop(2*lig-1,1/1.9) * 2;
	//float lowformula = rampTop(1-2*lig,1/1.9) * 2;

	float highsatformula = rampBot(2*lig-1,2) * 2;
	float lowsatformula = rampBot(1-2*lig,2) * 2;

	//float satformula = lig>0.5? highsatformula : lowsatformula; // * 0.5 ?
	float satformula = lig<0.5? (1-rampBot(2*lig,0.125))*4 : (1-rampBot(2-2*lig,0.125))*4;
	//float satformula = lig<0.5? ((1-rampBot(2*lig,0.25)) + rampBot(1-2*lig,4)) * 2 : 0; //(1-rampBot(2-2*lig,0.125))*4;

	//satformula = clamp(satformula, 0, 1);

	//hsl.y = hsl.y*0 + Saturation*1 + satformula*1;//mix(Saturation,2,satformula);
	//hsl.y = Saturation + (lig<0.5? (1-rampBot(2*lig,0.5))*2 : 0 );
	//hsl.y = mix(Saturation, satformula, satformula); //good?
	//hsl.y = Saturation + satformula;

	//hsl.x = clamp(hsl.x, 0.01, 0.99);
	//hsl.y = clamp(hsl.y, 0.01, 0.99);
	//hsl.z = clamp(hsl.z, 0.01, 0.99);

	//hsl.y = rampBot(hsl.y, 0.5);
	//hsl.z = rampBot(hsl.z, 0.5);
	vec3 oldrgb = rgb;
	rgb = hsl2rgb(hsl);



	//!!RESAT, X COORD (NEWSAT BY ORIGSAT):

	//no artifacts with oldrgb/lig!!!
	//float luma = dot(oldrgb, vec3(0.2126, 0.7152, 0.0722)); //percp, more artifacts but most realistic?
	//float luma = dot(oldrgb, vec3(0.333)); //linear, less artifacts
	//float luma = hsl.z; //no artifacts but dull?
	//float luma = hsv.z; //no artifacts and good?
	float luma = resatlig;
	oldsat = resat;
	luma = clamp(luma, 0, 1);

	//strenghten from top to bottom
	float power = clamp(rampTop(lig, 1)*1,0,1); //full oldsat when = 0
	//float power = clamp(rampBot(lig, 1/2)*0.5,0,44); //less artifacts
	//float power = 1-clamp(rampBot(dk, 1/2)*0.5,0,44); //same?
	//rgb = mix(vec3(luma), rgb, rampBot(oldsat, power) ); //good
	//rgb = mix(vec3(luma), rgb, rampBot(oldsat, rampTop(lig, 2)*0.5  )); //good

	//lig = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	//lig = dot(rgb, vec3(0.333));

	//float satmix = lig>0.5? rampBot(2*lig-1,2)*1 : rampBot(1-2*lig,2)*1;
	//float satmix = lig>0.5? 1-rampBot(2-2*lig,0.1) : 1-rampBot(2*lig,0.1); //triangle tip, =rampTop(saw,0.5)?
	//float satmix = 1-saw(lig,2);
	float satmix = rampBot(saw(lig,1),4);
	//satmix = rampBot(satmix,2); //rampTop?

	//!!SETTING NEW SAT FALLOFF
	rgb = mix(vec3(luma), rgb, mix(rampBot(oldsat,0.5), rampBot(oldsat,0.02), satmix ) );
	//rgb = mix(vec3(luma),rgb,oldsat);

	//strenghten from center to top and bottom
	//rgb = mix(vec3(luma), rgb, rampBot(oldsat, 1-(lig<0.5? 1*pow(1-2*lig,1) : pow(2*lig-1,1))));

	//strenghten from center to top and bottom, fine control
	float highformula = 1*rampBot(2*lig-1,1);
	float lowformula = 1*rampBot(1-2*lig,1);
	float formula = 1 - (lig>0.5? highformula : lowformula);
	formula = clamp(formula, 0, 1);
	//rgb = mix(vec3(luma), rgb, rampBot(oldsat, rampTop(formula,1 ))); //0.5?


	//float formula = 1-(lig<0.5? 1*pow(1-2*lig,2) : pow(2*lig-1,2));
	//rgb = mix(vec3(luma), rgb, mix(oldsat, 1, 1-rampBot(formula,0.5 )));

	return rgb;
}


vec4 window_shader() //picom function
{
	vec4 c = vec4(0.4, 0.4, 0.6, 1.0);

	if (UseEffects <= 0) //if disabled then only saturate and return
	{
		c = GetColor(tex, texcoord);

		if (Saturation != 1 ) c.rgb = Saturate(c.rgb, Saturation);

		return c;
	}


	if (Sharpness != 0 || Roughness != 0) //negative means blur
	{
		vec2 texelSize = 1.0 / textureSize(tex, 0);
		vec2 uv = texcoord * texelSize;

		c.rgb = DualSharpeningOptimized(tex, uv, texelSize, 3, Roughness, 1, Sharpness);

		//c = 0.5*(GetSharpenedColor(tex, uv, texelSize, Sharpness*2)+SharpenEdges(tex, uv, texelSize, Roughness*2, 3)); //simple 50/50 blend

		//c = mix(GetSharpenedColor(tex, uv, texelSize, Sharpness*2), SharpenEdges(tex, uv, texelSize, Roughness*2, 3), dot(c.rgb, vec3(0.2126, 0.7152, 0.0722))); //special mix

		//c = Get2xSai(tex, uv, texelSize*2);

		//float roughmix = 0.5;
		//vec4 sharp = roughmix<1.0? GetSharpenedColor(tex, uv, texelSize, Sharpness + Sharpness*roughmix*2) : c;
		//vec4 rough = roughmix>0.0? SharpenEdges(tex, uv, texelSize, Roughness+Roughness*(1-roughmix)*2, 3) : c;
		//c = mix (sharp, rough, roughmix);
	}
	else c = GetColor(tex, texcoord);


	if (Lum == 1) //dynamic exposure
    {
		c.rgb = ExpandExposure(c.rgb, tex, texcoord, ExposureExpansion, ExposureExpansionIgnoreLevel); //brighten scene based on average luminance
		if (ExpandBlacks > 0) c.rgb = BoostLows(c.rgb, ExpandBlacks+1, 1, ExpandBlacksSlope); //boost shadows, fixed multiplier
		//if (ExpandBlacks > 0) c.rgb = BrightenLows(c.rgb, ExpandBlacks, 1, 2);
		//c.rgb = BrightenLows(c.rgb, 0.2, 1, 2);
	}
	else if (Lum == 2) c.rgb = rampBot(c.rgb, 0.454545); //static compensation with gamma


	if (Dim > 0 ) c.rgb = DimWhites(c.rgb, Dim, DimThreshold, DimSlope, DimCompensation, 0); //suppress whites

	if (FakeHdr != 0) c.rgb = FixSat(c.rgb); else if (Saturation != 1 ) c.rgb = Saturate(c.rgb, Saturation);

	//if (true) c.rgb = SaturateLows(c.rgb,Saturation,64,0);

	//c.rgb = Oklabify(c.rgb, 1);

	//if (GammaCorrection != 1) c.rgb = GammaCorrect(c.rgb, 1/GammaCorrection); //if hardware not supported


	if (BlackLightness>0) c.rgb = BrightenLows(c.rgb, BlackLightness, 1, 2); //boost blacks/shadows, additive


	//black background replacer (useful for pure black themes?)
	//if (c.rgb == vec3(0)) c.rgb = vec3(0.2);

	if (Debug > 0) c.rgb = debug(c.rgb, debugValue);
	//---

	//REPLACE=fullscreen.part2.glsl

	//c.a = 1; //disable transparency
	//return default_post_processing(c); //picom default - if needed
	return c;
}
