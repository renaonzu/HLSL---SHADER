Shader "Custom/URP/AnimatedOcean_Enhanced"
{
    Properties
    {
        [Header(Water And Animation)] 
        _Color ("Albedo Color (RGB) and Opacity (A)", Color) = (0.1, 0.3, 0.5, 0.7) 
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _WaveSpeed ("Wave Speed", Float) = 1.0
        _WavePower ("Wave Power", Float) = 0.05
        
        [Header(Surface And Lighting)]
        _NormalMap ("Normal Map", 2D) = "bump" {}
        _NormalScrollSpeed ("Normal Scroll Speed", Vector) = (0.01, 0.02, 0, 0)
        _NormalScale ("Normal Intensity", Range(0, 2)) = 1.0
        _Shininess ("Specular Power (Gloss)", Range (0.03, 1)) = 0.8
        _FresnelPower ("Fresnel Power", Range(1, 10)) = 5.0
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "RenderPipeline"="UniversalPipeline" "Queue"="Transparent" }
        LOD 200

        Pass
        {
            Tags { "LightMode" = "UniversalForward" } 
            
            Blend SrcAlpha OneMinusSrcAlpha 
            ZWrite Off 

            HLSLPROGRAM

            #pragma target 3.5
            #pragma vertex vert
            #pragma fragment frag
            
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _SHADOWS_SOFT
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl" 

            struct Attributes
            {
                float4 positionOS      : POSITION;
                float3 normalOS        : NORMAL;
                float4 tangentOS       : TANGENT;
                float2 uv              : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS      : SV_POSITION;
                float2 uv              : TEXCOORD0;
                
                float3 TtoW0 : TEXCOORD1; 
                float3 TtoW1 : TEXCOORD2;
                float3 TtoW2 : TEXCOORD3;
                float3 positionWS      : TEXCOORD4; 
                
                float4 waveColor : COLOR; 
                
                UNITY_VERTEX_OUTPUT_STEREO
            };

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            TEXTURE2D(_NormalMap); SAMPLER(sampler_NormalMap);
            float4 _MainTex_ST;
            float4 _NormalMap_ST;
            float4 _Color;
            float _NormalScale;
            float _Shininess;
            float _WaveSpeed;
            float _WavePower;
            float4 _NormalScrollSpeed;
            float _FresnelPower;
            
            Varyings vert (Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                
                float waveValX = cos(_Time.y * _WaveSpeed + input.positionOS.z);
                float waveValZ = cos(_Time.y * _WaveSpeed + input.positionOS.x);
                
                float4 animatedPosOS = input.positionOS;
                animatedPosOS.y += (waveValX + waveValZ) * _WavePower;
                
                output.waveColor = float4(waveValX, waveValZ, 0, 0); 
                
                output.positionCS = TransformObjectToHClip(animatedPosOS.xyz); 
                output.positionWS = TransformObjectToWorld(animatedPosOS.xyz);
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                
                float3 worldNormal = normalize(TransformObjectToWorldNormal(input.normalOS));
                float3 worldTangent = normalize(TransformObjectToWorldDir(input.tangentOS.xyz));
                float3 worldBinormal = cross(worldNormal, worldTangent) * input.tangentOS.w;
                
                output.TtoW0 = float3(worldTangent.x, worldBinormal.x, worldNormal.x);
                output.TtoW1 = float3(worldTangent.y, worldBinormal.y, worldNormal.y);
                output.TtoW2 = float3(worldTangent.z, worldBinormal.z, worldNormal.z);
                
                return output;
            }

            float4 frag (Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                float4 albedoMix1 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv); 
                float4 albedoMix2 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv); 
                float4 albedoColor = lerp(albedoMix1, albedoMix2, 0.02) * _Color;
                
                float2 normalUV = TRANSFORM_TEX(input.uv, _NormalMap);
                normalUV.xy += _Time.y * _NormalScrollSpeed.xy;
                
                float4 normalSample = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, normalUV);
                float3 tangentNormal = UnpackNormal(normalSample); 
                tangentNormal.xy *= _NormalScale;
                
                float3x3 TBN = float3x3(input.TtoW0.xyz, input.TtoW1.xyz, input.TtoW2.xyz);
                float3 worldNormal = normalize(mul(TBN, tangentNormal));
                
                Light mainLight = GetMainLight(TransformWorldToShadowCoord(input.positionWS));

                float3 lightDir = mainLight.direction;
                
                float3 lightColor = mainLight.color * mainLight.shadowAttenuation; 
                
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - input.positionWS);
                
                float NdotV = 1.0 - max(0.0, dot(worldNormal, viewDir));
                float fresnel = pow(NdotV, _FresnelPower);
                
                float diffTerm = max(0, dot(worldNormal, lightDir));
                float3 diffuse = diffTerm * lightColor * albedoColor.rgb;
                
                float3 halfwayDir = SafeNormalize(lightDir + viewDir);
                float specPower = _Shininess * 128; 
                float specTerm = pow(max(0, dot(worldNormal, halfwayDir)), specPower); 
                
                float3 specular = specTerm * lightColor * (1.0 + fresnel * 0.5); 
                
                float3 ambient = SampleSH(worldNormal) * albedoColor.rgb;
                
                float3 finalColor = ambient + diffuse + specular;

                finalColor -= input.waveColor.y * 0.01 + input.waveColor.x * 0.07;
                
                float finalAlpha = albedoColor.a + (fresnel * 0.01); 
                
                return float4(finalColor, finalAlpha); 
            }
            ENDHLSL
        }
    }
}