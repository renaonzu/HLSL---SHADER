Shader "lit/Ocean"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Normal ("Normal Map", 2D) = "bump" {}
        _WaveSpeed ("Wave Speed", Float) = 1.0
        _WavePower ("Wave Power", Float) = 1.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float4 uv2 : TEXCOORD1;
                fixed4 color : COLOR;
                float4 normal : NORMAL;  
                
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                float3 normal : NORMAL;
                fixed4 color : COLOR;
            };

            sampler2D _MainTex;
            sampler2D _Normal;
            float4 _MainTex_ST;
            float4 _Normal_ST;

            float _WaveSpeed;
            float _WavePower;

            v2f vert (appdata v)
            {
                v2f o;
                float4 wave = float4(cos(_Time.y * _WaveSpeed+v.vertex.z),cos(_Time.y * _WaveSpeed+v.vertex.x),0,0);
                o.vertex = UnityObjectToClipPos(v.vertex)+wave * _WavePower ;
                o.color = wave;
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float4 lightDirection = _WorldSpaceLightPos0;

                float bright = dot(normalize(i.normal), normalize(lightDirection.xyz));

                float4 ambient = UNITY_LIGHTMODEL_AMBIENT;
                
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv + i.color.xy * 0.1);
                fixed4 col2 = tex2D(_MainTex, i.uv - i.color.xy * 0.1);

                fixed4 mix = lerp(col, col2, 0.6);

                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, mix);

               
                return (mix + ambient) * bright - i.color.y * 0.05 - i.color.x * 0.05;
            }
            ENDHLSL
        }
    }
    fallback "Diffuse"
}
