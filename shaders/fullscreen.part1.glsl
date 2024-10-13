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

vec4 dimExposureTest(vec4 color, sampler2D tex, vec2 texcoord)
{
	float l = getLuma8x4(tex);

	if (l > ExposureSuppressionThreshold && ExposureSuppression > 0) //suppress
	{
		l = (l-ExposureSuppressionThreshold)/(1-ExposureSuppressionThreshold); //normalize
		color.rgb *= 1- rampTop(l,ExposureSupperessionSlope)*ExposureSuppression;
	}

	if (l < ExposureExpansionThreshold && ExposureExpansion > 0) //expand
	{
		l = l/ExposureSuppressionThreshold; //normalize
		color.rgb *= 1+ rampBottom(1-l,ExposureExpansionSlope)*ExposureExpansion;
	}

	return color;
}