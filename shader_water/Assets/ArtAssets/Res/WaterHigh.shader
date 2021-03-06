﻿Shader "Unlit/WaterHigh"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}

		_MainColor("Base Color", Color) = (1,1,1,1)

		_BumpMap("Normalmap", 2D) = "bump" {}
		_BumpMap2ST("Normalmap 2 ST", Vector) = (0,0,0,0)


			//
			_WaveSpeed("Wave Speed", Vector) = (0,0,0,0)

			_Gloss("Gloss", range(0, 1)) = 0.9

			_Deep("Deep", range(0.1, 2)) = 0.3
			_Dirty("Dirty", range(0, 1)) = 1

		 _fresnelBase("fresnelBase", Range(0, 1)) = 0
		_fresnelScale("fresnelScale", Range(0, 1)) = 1
		_fresnelIndensity("fresnelIndensity", Range(0, 5)) = 5
	}
		SubShader
		{
			Tags { "Queue" = "Transparent" "RenderType" = "Water"  }
			LOD 100

			Pass
			{
				CGPROGRAM
				#pragma vertex vert
				#pragma fragment frag
				// make fog work
				#pragma multi_compile_fog

				#include "UnityCG.cginc"
				#include "UnityPBSLighting.cginc"
				//#include "UnityStandardBRDF.cginc"
				//#include "UnityStandardCoreForwardSimple.cginc"

				struct appdata
				{
					float4 vertex : POSITION;

					float2 texcoord: TEXCOORD0;

					float3 normal : NORMAL;
					float4 tangent : TANGENT;
				};

				struct v2f
				{
					//float2 uv : TEXCOORD0;

					float4 vertex : SV_POSITION;
					
					float4 uvbump : TEXCOORD0;

					float4 worldPosition : TEXCOORD1;
					float3 worldNormal : TEXCOORD2;
					float3 worldTangent : TEXCOORD3;
					float3 worldBiNormal : TEXCOORD4;

					float4 uvgrab : TEXCOORD5;

					UNITY_FOG_COORDS(6)
					float4 projPos : TEXCOORD7;
				};

				fixed4 _MainColor;

				sampler2D _MainTex;
				float4 _MainTex_ST;


				sampler2D _BumpMap;
				float4 _BumpMap_ST;
				float4 _BumpMap2ST;

				float3 _FakeLightDir;
				half4 _FakeLightColor;


				//
				float4 _WaveSpeed;

				half _Gloss;


				sampler2D _PreSceneTex;

				sampler2D_float _CameraDepthTexture;

				//////////////////
				float _Deep;
				half _Dirty;

				////
				float _fresnelBase;
				float _fresnelScale;
				float _fresnelIndensity;


				v2f vert(appdata v)
				{
					v2f o;
					o.vertex = UnityObjectToClipPos(v.vertex);
					//o.uv = TRANSFORM_TEX(v.uv, _MainTex);

					float4x4 modelMatrixInverse = unity_WorldToObject;
					float4x4 modelMatrix = unity_ObjectToWorld;

					float4 moveLength = _WaveSpeed * _Time.x;

					/// 法线贴图坐标

					o.uvbump.xy = TRANSFORM_TEX(v.texcoord, _BumpMap) + moveLength.xy;
					o.uvbump.zw = v.texcoord.xy * _BumpMap2ST.xy + _BumpMap2ST.zw + moveLength.zw;

					///计算切线空间  需要  两个转换矩阵
					o.worldPosition = mul(modelMatrix, v.vertex);
					o.worldNormal = normalize(mul(float4(v.normal, 0.0), modelMatrixInverse).xyz);
					o.worldTangent = normalize(mul(modelMatrix, float4(v.tangent.xyz, 0.0)).xyz);
					o.worldBiNormal = normalize(cross(o.worldNormal, o.worldTangent) * v.tangent.w); // tangent.w is specific to Unity
					///

					/// 折射
//#if UNITY_UV_STARTS_AT_TOP
//					float scale = -1.0;
//#else
//					float scale = 1.0;
//#endif
//					o.uvgrab.xy = (float2(o.vertex.x, o.vertex.y*scale) + o.vertex.w) * 0.5;
//					o.uvgrab.zw = o.vertex.zw;

					o.uvgrab = ComputeGrabScreenPos(o.vertex);

					o.projPos = ComputeScreenPos(o.vertex);

					UNITY_TRANSFER_FOG(o,o.vertex);
					return o;
				}

				fixed4 frag(v2f i) : SV_Target
				{

					///
					half4 waterColor = _MainColor;
					half gloss = _Gloss;
					float specPow = exp2(gloss * 10.0 + 1.0);

					/// 根据法线贴图计算法线    
					// 1 需要法线贴图坐标
					half3 bump = UnpackNormal(tex2D(_BumpMap, i.uvbump.xy)); // we could optimize this by just reading the x & y without reconstructing the Z
					half3 bump1 = UnpackNormal(tex2D(_BumpMap, i.uvbump.zw));
					float3 localNormal = (bump + bump1) * 0.5;

					//float3 localNormal = bump;

					///
					float3 localCoords = localNormal * 0.01;
					// * i.uvgrab.z
					//i.uvgrab.xy = localCoords.rg * i.uvgrab.z + i.uvgrab.xy;


					// 根据切线空间   计算世界法线
					float3x3 local2WorldTranspose = float3x3(i.worldTangent,
						i.worldBiNormal,
						i.worldNormal);
					float3 normalDirection = normalize(mul(localNormal, local2WorldTranspose));

					//计算视线  和 视线的反射线
					float3 viewDirection = normalize(_WorldSpaceCameraPos - i.worldPosition.xyz);
					float3 viewReflectDirection = reflect(-viewDirection, normalDirection);

					///计算光照  需要用到法线
					float3 lightDirection = _FakeLightDir;
					float3 lightColor = _FakeLightColor.rgb;
					float3 halfDirection = normalize(viewDirection + lightDirection);


					// brdf 中灯光信息
					UnityLight light;
					light.color = lightColor;
					light.dir = lightDirection;
					light.ndotl = LambertTerm(normalDirection, light.dir);

					//brdf 中的 全局照明信息
					UnityGIInput d;
					d.light = light;
					d.worldPos = i.worldPosition.xyz;
					d.worldViewDir = viewDirection;
					d.atten = 1;

					////
	//#if defined(LIGHTMAP_ON) || defined(DYNAMICLIGHTMAP_ON)
	//				d.ambient = 0;
	//				d.lightmapUV = i_ambientOrLightmapUV;
	//#else
	//				d.ambient = i_ambientOrLightmapUV.rgb;
	//				d.lightmapUV = 0;
	//#endif

					d.probeHDR[0] = unity_SpecCube0_HDR;
					d.probeHDR[1] = unity_SpecCube1_HDR;
	#if defined(UNITY_SPECCUBE_BLENDING) || defined(UNITY_SPECCUBE_BOX_PROJECTION)
					d.boxMin[0] = unity_SpecCube0_BoxMin; // .w holds lerp value for blending
	#endif
	#ifdef UNITY_SPECCUBE_BOX_PROJECTION
					d.boxMax[0] = unity_SpecCube0_BoxMax;
					d.probePosition[0] = unity_SpecCube0_ProbePosition;
					d.boxMax[1] = unity_SpecCube1_BoxMax;
					d.boxMin[1] = unity_SpecCube1_BoxMin;
					d.probePosition[1] = unity_SpecCube1_ProbePosition;
	#endif

					// brdf 中的粗糙度
					Unity_GlossyEnvironmentData ugls_en_data;
					ugls_en_data.roughness = 1.0 - gloss;
					ugls_en_data.reflUVW = viewReflectDirection;

					//brdf 中的全局光照
					UnityGI gi = UnityGlobalIllumination(d, 1, normalDirection, ugls_en_data);

					lightDirection = gi.light.dir;
					lightColor = gi.light.color;

					float3 directSpecular = lightColor * pow(max(0, dot(halfDirection, normalDirection))*1.001, specPow);


					///计算菲涅尔
				/*	float _distance = distance(i.worldPosition.xyz, _WorldSpaceCameraPos);
					float fresnelMax = min(pow(_distance / 40, 1.3), 0.7);
					float fresnel = clamp(pow(1 - dot(viewDirection, normalDirection), 0.5), 0.2, fresnelMax);*/


					///折射
					half4 refractionColor = tex2Dproj(_PreSceneTex, i.uvgrab); //tex2Dproj(_PreSceneTex, UNITY_PROJ_COORD(i.uvgrab));
					//refractionColor.a = 1.0;

					////compute depth
					//float sceneZ = max(0, LinearEyeDepth(UNITY_SAMPLE_DEPTH(tex2Dproj(_CameraDepthTexture, UNITY_PROJ_COORD(i.projPos)))) - _ProjectionParams.g);
					//float partZ = max(0, i.projPos.z - _ProjectionParams.g);
					////half depthBlend1 = saturate((sceneZ - partZ) / (_ProjectionParams.b - _ProjectionParams.g) * 300);
					//half depthBlend1 = saturate((sceneZ - partZ) * _Deep);
					//half multi1 = pow(depthBlend1, 0.5);// depthBlend1 * depthBlend1;

					half4 sceneColor = refractionColor;// lerp(refractionColor, lerp(waterColor * refractionColor, waterColor, _Dirty), multi1);

					// sample the texture
					//fixed4 col = tex2D(_MainTex, i.uv);
					half4 c = half4(0, 0, 0, 1.0);


					//菲尼尔公式  normalDirection  viewDirection
					//float fresnel = _fresnelBase + _fresnelScale * pow(1 - dot(N, V), _fresnelIndensity);
					float _distance = distance(i.worldPosition.xyz, _WorldSpaceCameraPos);
					float fresnelMax = min(pow(_distance / 40, 1.3), 0.7);
					// clamp(fresnel_vew, 0.2, fresnelMax);

					float fresnel_vew = _fresnelBase + _fresnelScale * pow(1 - dot(normalDirection, viewDirection), _fresnelIndensity);
					
					float fresnel = clamp(fresnel_vew, 0.2, fresnelMax);

					//c.rgb = waterColor.rgb * (gi.indirect.specular.rgb + directSpecular) * 1;
					c.rgb = sceneColor.rgb * fresnel +(gi.indirect.specular.rgb + directSpecular) * (1 - fresnel);

					//c.a = 0.4;
					// apply fog
					//UNITY_APPLY_FOG(i.fogCoord, col);
					return c;
				}
				ENDCG
			}
		}
}
