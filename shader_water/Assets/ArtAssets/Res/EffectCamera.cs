using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;




public class EffectCamera : MonoBehaviour
{

    //cameras
    private Camera thisCamera;

    int preSceneID = 0;
    // Start is called before the first frame update
    void Start()
    {
        thisCamera = GetComponent<Camera>();
        AdaptQualityLevel();
    }

    public void AdaptQualityLevel()
    {
        ApplyHighQuality();
    }


    void ApplyHighQuality()
    {
        SetCommandBufferPipelineNormal();
    }

    void SetCommandBufferPipelineNormal()
    {

        ////////////////////////////通过commadBuffer 设置_PreSceneTex
        //申明
        CommandBuffer bufBackgroundFetch = new CommandBuffer();
        bufBackgroundFetch.name = "Normal Background Fetch";

        bufBackgroundFetch.GetTemporaryRT(preSceneID, -1, -1, 0, FilterMode.Bilinear);
        bufBackgroundFetch.Blit(BuiltinRenderTextureType.CurrentActive, preSceneID);

        bufBackgroundFetch.SetGlobalTexture("_PreSceneTex", preSceneID);
        bufBackgroundFetch.ReleaseTemporaryRT(preSceneID);

        thisCamera.AddCommandBuffer(CameraEvent.AfterForwardOpaque, bufBackgroundFetch);

    }

    // Update is called once per frame
    void Update()
    {
        
    }
}
