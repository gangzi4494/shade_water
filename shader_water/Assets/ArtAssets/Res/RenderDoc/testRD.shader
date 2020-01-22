Shader "Unlit/testRD"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}

		_fresnelBase("fresnelBase", Range(0, 1)) = 0
		_fresnelScale("fresnelScale", Range(0, 1)) = 1
		_fresnelIndensity("fresnelIndensity", Range(0, 5)) = 5

    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
			#pragma enable_d3d11_debug_symbols
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
				float4 worldPosition : TEXCOORD2;

				float3 N : TEXCOORD3;
				float3 V : TEXCOORD4;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

			float _fresnelBase;
			float _fresnelScale;
			float _fresnelIndensity;


            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);

				o.worldPosition = mul(unity_ObjectToWorld, v.vertex);
				//
				//将法线转到世界坐标
				o.N = mul(v.normal, (float3x3)unity_WorldToObject);
				//获取世界坐标的光向量
				//o.L = WorldSpaceLightDir(v.vertex);
				//获取世界坐标的视角向量
				o.V = WorldSpaceViewDir(v.vertex);
				//
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);

			///计算菲涅尔
			/*float _distance = distance(i.worldPosition.xyz, _WorldSpaceCameraPos);
			float fresnelMax = min(pow(_distance / 40, 1.3), 0.7);*/
			//float fresnel = clamp(pow(1 - dot(viewDirection, normalDirection), 0.5), 0.2, fresnelMax);

			float3 N = normalize(i.N);
			//float3 L = normalize(i.L);
			float3 V = normalize(i.V);
			//菲尼尔公式
			float fresnel = _fresnelBase + _fresnelScale * pow(1 - dot(N, V), _fresnelIndensity);


			float fenl = fresnel;// fresnelMax;
				
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col * fenl;
            }
            ENDCG
        }
    }
}
