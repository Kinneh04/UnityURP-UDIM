Shader "Kinn/URP/UDIMM"
{
    Properties
    {
        _BaseColor("Base Color", Color) = (1,1,1,1)

        [NoScaleOffset]
        _UDIMArray("UDIM Texture Array", 2DArray) = "" {}

        _TileCount("UDIM Tile Count", Float) = 4

        _GlobalTiling("Global Tiling", Vector) = (1,1,0,0)
        _GlobalOffset("Global Offset", Vector) = (0,0,0,0)
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
            "RenderType"="Opaque"
            "Queue"="Geometry"
        }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile_fragment _ _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 normalWS   : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float2 uv         : TEXCOORD2;
                float4 shadowCoord : TEXCOORD3;
            };

            TEXTURE2D_ARRAY(_UDIMArray);
            SAMPLER(sampler_UDIMArray);

            CBUFFER_START(UnityPerMaterial)

                float4 _BaseColor;

                float _TileCount;

                float4 _GlobalTiling;
                float4 _GlobalOffset;

            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                VertexPositionInputs pos =
                    GetVertexPositionInputs(IN.positionOS.xyz);

                VertexNormalInputs norm =
                    GetVertexNormalInputs(IN.normalOS);

                OUT.positionCS = pos.positionCS;
                OUT.positionWS = pos.positionWS;
                OUT.normalWS   = norm.normalWS;
                OUT.uv         = IN.uv;

                OUT.shadowCoord = GetShadowCoord(pos);

                return OUT;
            }

            float2 GetLocalUDIMUV(float2 uv)
            {
                float2 localUV;

                localUV.x = frac(uv.x);
                localUV.y = uv.y;

                localUV *= _GlobalTiling.xy;
                localUV += _GlobalOffset.xy;

                return localUV;
            }

            half4 SampleUDIM(float2 uv)
            {
                float layer = floor(uv.x);

                layer = clamp(layer, 0, _TileCount - 1);

                float2 localUV = GetLocalUDIMUV(uv);

                return SAMPLE_TEXTURE2D_ARRAY(
                    _UDIMArray,
                    sampler_UDIMArray,
                    localUV,
                    layer
                );
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 albedo =
                    SampleUDIM(IN.uv) * _BaseColor;

                float3 normalWS =
                    normalize(IN.normalWS);

                Light mainLight =
                    GetMainLight(IN.shadowCoord);

                float NdotL =
                    saturate(dot(normalWS,
                                 mainLight.direction));

                float3 diffuse =
                    albedo.rgb *
                    mainLight.color *
                    NdotL *
                    mainLight.shadowAttenuation;

                float3 ambient =
                    albedo.rgb * 0.2;

                return half4(
                    diffuse + ambient,
                    albedo.a);
            }

            ENDHLSL
        }
    }

    FallBack Off
}