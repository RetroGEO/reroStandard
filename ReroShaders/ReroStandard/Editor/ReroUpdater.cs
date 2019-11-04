//Thanks, azami
#if UNITY_EDITOR
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System.Net;
using System.Net.Security;

[InitializeOnLoad]
public class ReroUpdater : MonoBehaviour
{
	
	static ReroUpdater()
	{
		EditorApplication.update -= DoSplashScreen;
		EditorApplication.update += DoSplashScreen;
	}
	private const string k_ProjectOpened = "ProjectOpened";
	private static bool done = false;
	private static void DoSplashScreen()
	{
		EditorApplication.update -= DoSplashScreen;
		if (!EditorApplication.isPlayingOrWillChangePlaymode)
		{
			if (!SessionState.GetBool(k_ProjectOpened, false))
			{
				SessionState.SetBool(k_ProjectOpened, true);
				NewMenuOption();
			}
		}
	}

    [MenuItem("ReroUpdater/Check for Updates")]
    private static void NewMenuOption()
    {
        string currentVersion = System.IO.File.ReadAllText("Assets\\ReroShaders\\ReroStandard\\Version.txt");
        string newVersion = string.Empty;
		string newChanges = string.Empty;

        using (WebClient client = new WebClient())
        {
            ServicePointManager.ServerCertificateValidationCallback = new RemoteCertificateValidationCallback(delegate { return true; });
            newVersion = client.DownloadString("http://pastebin.com/raw/Pg2dWaEu");
			newChanges = client.DownloadString("http://pastebin.com/raw/SgLsPWpf");
        }

        if (currentVersion == newVersion)
            EditorUtility.DisplayDialog("Update Shader?",
                "You are up to date.", "Okay");

        else if (EditorUtility.DisplayDialog("Update Shader?",
                "There is a new update available\nCurrent: " + currentVersion + "\nNew: " + newVersion + "\nChanges: " + newChanges + "\n\nDo you want to update?", "Yes", "No"))
        {
            using (WebClient webClient = new WebClient())
            {   
                AssetDatabase.DeleteAsset("Assets\\ReroShaders\\ReroStandard\\Shaders");
                webClient.DownloadFile("https://drive.google.com/uc?export=download&id=1DcQdubUM5M33BXyUI-ZccUby7Iaz_ti6", "Assets\\ReroShaders\\ReroStandard\\ReroStandard.unitypackage");
				done = true;
            }
			if(done)
			{
				AssetDatabase.Refresh();
				AssetDatabase.ImportPackage("Assets\\ReroShaders\\ReroStandard\\ReroStandard.unitypackage",true);
				AssetDatabase.DeleteAsset("Assets\\ReroShaders\\ReroStandard\\ReroStandard.unitypackage");
			}
        }
        else
            Debug.Log("Not actually downloading anything.");
    }
}
#endif