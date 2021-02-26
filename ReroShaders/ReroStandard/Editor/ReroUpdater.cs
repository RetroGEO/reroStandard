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
		if(DontAskAgain)
			return;

		EditorApplication.update -= DoSplashScreen;
		EditorApplication.update += DoSplashScreen;
	}
	private const string k_ProjectOpened = "ProjectOpened";
	private static bool done = false;

	private static readonly string prefFormat = $"ReroStandard.{Application.productName}-"; //ReroStandard.ProjectName-
	private static bool calledByUser = false;

	static bool DontAskAgain
	{
		get => EditorPrefs.GetBool(prefFormat + nameof(DontAskAgain), false);
		set => EditorPrefs.SetBool(prefFormat + nameof(DontAskAgain), value);
	}

	private static void DoSplashScreen()
	{
		EditorApplication.update -= DoSplashScreen;
		if(!EditorApplication.isPlayingOrWillChangePlaymode)
		{
			if(!SessionState.GetBool(k_ProjectOpened, false))
			{
				SessionState.SetBool(k_ProjectOpened, true);
				NewMenuOption();
			}
		}
	}

	[MenuItem("ReroUpdater/Allow Auto Update", true)]
	private static bool AllowAutoUpdateChecksValidate()
	{
		return DontAskAgain;
	}

	[MenuItem("ReroUpdater/Allow Auto Update")]
	private static void AllowAutoUpdateChecks()
	{
		DontAskAgain = false;
	}

	[MenuItem("ReroUpdater/Check for Updates", true)]
	private static bool NewMenuOptionValidate()
	{
		calledByUser = true;
		return true;
	}

	[MenuItem("ReroUpdater/Check for Updates", priority = 20)]
	private static void NewMenuOption()
	{
		if(!calledByUser && DontAskAgain)
			return;

		string currentVersion = System.IO.File.ReadAllText("Assets\\ReroShaders\\ReroStandard\\Version.txt");
		string newVersion = string.Empty;
		string newChanges = string.Empty;

		using(WebClient client = new WebClient())
		{
			ServicePointManager.ServerCertificateValidationCallback = new RemoteCertificateValidationCallback(delegate { return true; });
			newVersion = client.DownloadString("http://pastebin.com/raw/Pg2dWaEu");
			newChanges = client.DownloadString("http://pastebin.com/raw/SgLsPWpf");
		}

		if(currentVersion == newVersion)
		{
			if(calledByUser)
				EditorUtility.DisplayDialog("Update Shader?",
					"You are up to date.", "Okay");
		}
		else
		{
			int option = 0;
			string header = "Update Shader?";
			string text = $"There is a new update available\nCurrent: {currentVersion}\nNew: {newVersion}\nChanges: {newChanges}\n\nDo you want to update?";

			if(!calledByUser)
				option = EditorUtility.DisplayDialogComplex(header, text, "Yes", "No", "Don't ask again");
			else
				option = EditorUtility.DisplayDialog(header, text, "Yes", "No") ? 1 : 0;
			switch(option)
			{
				case 1:
					using(WebClient webClient = new WebClient())
					{
						AssetDatabase.DeleteAsset("Assets\\ReroShaders\\ReroStandard\\Shaders");
						webClient.DownloadFile("https://drive.google.com/uc?export=download&id=1DcQdubUM5M33BXyUI-ZccUby7Iaz_ti6", "Assets\\ReroShaders\\ReroStandard\\ReroStandard.unitypackage");
						done = true;
					}
					if(done)
					{
						AssetDatabase.Refresh();
						AssetDatabase.ImportPackage("Assets\\ReroShaders\\ReroStandard\\ReroStandard.unitypackage", true);
						AssetDatabase.DeleteAsset("Assets\\ReroShaders\\ReroStandard\\ReroStandard.unitypackage");
					}
					break;
				case 2:
					DontAskAgain = true;
					break;
				default:
					break;
			};
		}
	}
}
#endif