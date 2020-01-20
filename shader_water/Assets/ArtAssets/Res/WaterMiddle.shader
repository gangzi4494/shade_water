Shader "Unlit/WaterMiddle"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}

	    _MainColor("Base Color", Color) = (1,1,1,1)

	    _BumpMap("Normalmap", 2D) = "bump" {}
		_BumpMap2ST("Normalmap 2 ST", Vector) = (0,0,0,0)


		//
		_WaveSpeed("Wave Speed", Vector) = (0,0,0,0)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
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
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
				float4 uvbump : TEXCOORD0;

				float4 worldPosition : TEXCOORD1;
				float3 worldNormal : TEXCOORD2;
				float3 worldTangent : TEXCOORD3;
				float3 worldBiNormal : TEXCOORD4;
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


            v2f vert (appdata v)
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
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {

				///
				half4 waterColor = _MainColor;


				/// 根据法线贴图计算法线    
				// 1 需要法线贴图坐标
				half3 bump = UnpackNormal(tex2D(_BumpMap, i.uvbump.xy)); // we could optimize this by just reading the x & y without reconstructing the Z
				half3 bump1 = UnpackNormal(tex2D(_BumpMap, i.uvbump.zw));
				float3 localNormal = (bump + bump1) * 0.5;

				// 根据切线空间   
				float3x3 local2WorldTranspose = float3x3(i.worldTangent,
					i.worldBiNormal,
					i.worldNormal);
				float3 normalDirection = normalize(mul(localNormal, local2WorldTranspose));

				///计算光照  需要用到法线
				float3 lightDirection = _FakeLightDir;
				float3 lightColor = _FakeLightColor.rgb;


				UnityLight light;
				light.color = lightColor;
				light.dir = lightDirection;
				//light.ndotl = LambertTerm(normalDirection, light.dir);


                // sample the texture
                //fixed4 col = tex2D(_MainTex, i.uv);
				half4 c = half4(0, 0, 0, 1.0);

				c.rgb = waterColor.rgb;
                // apply fog
                //UNITY_APPLY_FOG(i.fogCoord, col);
                return c;
            }
            ENDCG
        }
    }
}
