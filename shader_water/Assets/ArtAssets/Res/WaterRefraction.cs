using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class WaterRefraction : MonoBehaviour
{


    MeshRenderer mr;

    public Transform fakeLight;


    public Color lightColor;
    public float intensity;

    // Start is called before the first frame update
    void Start()
    {
        mr = gameObject.GetComponent<MeshRenderer>();

        gameObject.layer = LayerMask.NameToLayer("Water");
    }

    private void OnWillRenderObject()
    {
        if (mr != null)
        {

            Vector3 lightDir = Vector3.forward;
            if (fakeLight != null)
            {
                lightDir = fakeLight.forward;
            }

            mr.material.SetVector("_FakeLightDir", lightDir);
            mr.material.SetColor("_FakeLightColor", lightColor * intensity);
        }
    }
}
